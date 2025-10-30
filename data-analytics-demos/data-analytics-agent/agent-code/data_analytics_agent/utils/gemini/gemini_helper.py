import os
import json
import logging
import httpx  
import asyncio 
import google.auth
import google.auth.transport.requests
from tenacity import retry, wait_exponential, stop_after_attempt, before_sleep_log, retry_if_exception
from typing import Tuple

logger = logging.getLogger(__name__)

# The retry_condition function itself is synchronous and inspects an error object,
# so it does not need to be async. It's called by tenacity's decorator.
def retry_condition(error):
  error_string = str(error)
  logger.debug(error_string)

  retry_errors = [
      "RESOURCE_EXHAUSTED",
      "No content in candidate",
      "500 Internal Server Error", # Often transient, worth retrying
      "503 Service Unavailable",   # Often transient, worth retrying
      "Timeout", # Add timeout related errors if not caught by httpx.TimeoutException
      # Add more error messages here as needed
  ]

  for retry_error in retry_errors:
    if retry_error in error_string:
      logger.info(f"Detected retryable error: '{retry_error}'. Retrying...") # Changed to info for better visibility
      return True
  return False


@retry(wait=wait_exponential(multiplier=1, min=1, max=60), stop=stop_after_attempt(10), retry=retry_if_exception(retry_condition), before_sleep=before_sleep_log(logging.getLogger(), logging.INFO))
async def gemini_llm(prompt, model="gemini-2.5-flash", response_schema=None, temperature=1, topP=1, topK=32): # Changed to async def
    """
    Calls the Gemini LLM with a given prompt and handles the response asynchronously.
    """
    llm_response = None
    if temperature < 0:
        temperature = 0

    project_id = os.getenv("AGENT_ENV_PROJECT_ID")
    location = os.getenv("AGENT_ENV_VERTEX_AI_REGION")

    url = f"https://{location}-aiplatform.googleapis.com/v1/projects/{project_id}/locations/{location}/publishers/google/models/{model}:generateContent"

    generation_config = {
        "temperature": temperature,
        "topP": topP,
        "maxOutputTokens": 65536,
        "candidateCount": 1,
        "responseMimeType": "application/json",
    }

    if response_schema is not None:
        generation_config["responseSchema"] = response_schema
    if "flash" in model: # topK is supported by flash models
        generation_config["topK"] = topK

    request_body = {
        "contents": {"role": "user", "parts": {"text": prompt}},
        "generation_config": {**generation_config},
        "safety_settings": {
            "category": "HARM_CATEGORY_SEXUALLY_EXPLICIT",
            "threshold": "BLOCK_LOW_AND_ABOVE"
        }
    }

    # Run blocking google.auth calls in a separate thread to not block the event loop
    try:
        creds, _ = await asyncio.to_thread(google.auth.default)
        auth_req = google.auth.transport.requests.Request()
        await asyncio.to_thread(creds.refresh, auth_req)
    except Exception as e:
        logger.error(f"Authentication failed in gemini_llm: {e}", exc_info=True)
        raise RuntimeError(f"Authentication error: {e}")

    headers = {
        "Content-Type": "application/json",
        "Authorization": f"Bearer {creds.token}" # Using f-string
    }

    async with httpx.AsyncClient(timeout=300.0) as client: # Use httpx.AsyncClient with a generous timeout
        try:
            response = await client.post(url, json=request_body, headers=headers) # Use await client.post
            response.raise_for_status()  # Raises httpx.HTTPStatusError for bad responses (4XX or 5XX)
            json_response = response.json() # .json() is usually synchronous after response is received

            llm_response = json_response["candidates"][0]["content"]["parts"][0]["text"]
            # Clean up common markdown formatting if present
            return llm_response.strip().lstrip("```json").rstrip("```")
        except httpx.TimeoutException as e: # Catch httpx-specific Timeout
            logger.error(f"Request to LLM API timed out: {e}", exc_info=True)
            raise RuntimeError(f"LLM API request timed out: {e}")
        except httpx.HTTPStatusError as http_err: # Catch httpx-specific HTTP errors
            logger.error(f"HTTP error from LLM API: {http_err} (Status code: {http_err.response.status_code}), Response Text: {http_err.response.text}", exc_info=True)
            raise RuntimeError(f"Error with prompt: '{prompt}' Status: '{http_err.response.status_code}' Text: '{http_err.response.text}'")
        except (KeyError, IndexError, json.JSONDecodeError) as e:
            logger.error(f"Error parsing LLM response: {e}. Full response: {response.text if response else 'No response object.'}", exc_info=True)
            raise RuntimeError(f"Error parsing LLM response: {e}. Full response: {response.text if response else 'No response object.'}")
        except httpx.RequestError as req_err: # Catch other httpx request errors (e.g., network issues)
            logger.error(f"Network request error to LLM API: {req_err}", exc_info=True)
            raise RuntimeError(f"LLM API network request error: {req_err}")
        except Exception as e: # Catch any other unexpected error
            logger.error(f"An unexpected error occurred in gemini_llm: {str(e)}", exc_info=True)
            raise RuntimeError(f"An unexpected error occurred in gemini_llm: {str(e)}")
    

async def llm_as_a_judge(additional_judge_prompt_instructions: str, original_prompt: str, response_from_processing: str) -> Tuple[bool, str]: # Changed to async def
    """
    Determines if the prompt has run correctly by calling the Gemini LLM as a judge.
    """
    response_schema = {
        "type": "object",
        "properties": {
            "processing_status": {
                "type": "boolean",
                "description": "True if the processing was successful, False otherwise."
            },
            "explanation": {
                "type": "string",
                "description": "A brief explanation for the decision."
            }
        },
        "required": ["processing_status", "explanation"]
    }
    prompt = f"""You are evaluating if a LLM has completed it task.
    Respond back with True if you think the below process request executed successfully or False if it looks like it failed.
    Explain your reasoning.

    Additional Instructions:
    {additional_judge_prompt_instructions}

    <original-prompt>
    {original_prompt}
    </original-prompt>

    <response-from-llm>
    {response_from_processing}
    </response-from-llm>
    """
    # Await the async gemini_llm call
    gemini_response = await gemini_llm(prompt, response_schema=response_schema)
    try:
        gemini_response_json = json.loads(gemini_response)
        # Ensure that 'processing_status' is actually a boolean from the JSON parsing
        processing_status = gemini_response_json.get("processing_status")
        if not isinstance(processing_status, bool):
            # If the LLM returned something not exactly a boolean, coerce it
            processing_status = str(processing_status).lower() == 'true'

        return processing_status, gemini_response_json["explanation"]
    except json.JSONDecodeError as e:
        logger.error(f"Failed to parse LLM judge response JSON: {e}. Raw response: {gemini_response}", exc_info=True)
        return False, f"Error parsing judge's response: {e}. Raw response: {gemini_response}"
    except KeyError as e:
        logger.error(f"Missing expected key in LLM judge response: {e}. Raw response: {gemini_response}", exc_info=True)
        return False, f"Unexpected format from judge's response: missing key '{e}'."
    except Exception as e:
        logger.error(f"An unexpected error occurred in llm_as_a_judge: {e}", exc_info=True)
        return False, f"An unexpected error occurred during judgment: {e}"