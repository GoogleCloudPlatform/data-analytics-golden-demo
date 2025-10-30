import logging
import httpx # Import httpx for async HTTP requests
import asyncio # Import asyncio for async operations
import google.auth.transport.requests
import google.auth

logger = logging.getLogger(__name__)

# Create a global AsyncClient or manage it within a context manager.
# For simplicity in this example, we'll create it inside the function,
# but for performance in a high-traffic app, a single client instance
# managed globally or via dependency injection is often better.

async def rest_api_helper(url: str, http_verb: str, request_body: dict = None) -> dict: # Changed request_body to dict type hint
  """
  Asynchronously calls the Google Cloud REST API passing in the current user's credentials.
  """
  # Get an access token based upon the current user
  # google.auth.default() and creds.refresh() are synchronous operations
  # We use asyncio.to_thread to run them in a separate thread,
  # preventing them from blocking the main asyncio event loop.
  try:
    # Run the blocking credential retrieval in a separate thread
    creds, project = await asyncio.to_thread(google.auth.default)

    # Run the blocking token refresh in a separate thread
    auth_req = google.auth.transport.requests.Request()
    await asyncio.to_thread(creds.refresh, auth_req)
    
    access_token = creds.token
  except Exception as e:
      logger.error(f"Error obtaining or refreshing Google Cloud credentials: {e}")
      raise RuntimeError(f"Authentication error: {e}")


  headers = {
    "Content-Type" : "application/json",
    "Authorization" : f"Bearer {access_token}" # Using f-string for cleaner formatting
  }

  # Use httpx.AsyncClient for asynchronous HTTP requests
  async with httpx.AsyncClient(timeout=60.0) as client: # Increased timeout for potential long API calls
    try:
      response = None
      http_verb = http_verb.upper()
      if http_verb == "GET":
        response = await client.get(url, headers=headers)
      elif http_verb == "POST":
        response = await client.post(url, json=request_body, headers=headers)
      elif http_verb == "PUT":
        response = await client.put(url, json=request_body, headers=headers)
      elif http_verb == "PATCH":
        response = await client.patch(url, json=request_body, headers=headers)
      elif http_verb == "DELETE":
        response = await client.delete(url, headers=headers)
      else:
        raise ValueError(f"Unknown HTTP verb: {http_verb}") # Use ValueError for bad input

      response.raise_for_status() # This will raise an httpx.HTTPStatusError for 4xx/5xx responses
      return response.json() # httpx response.json() is also async if content is not yet read, but usually sync after response.read()

    except httpx.HTTPStatusError as e:
      error_message = f"Error rest_api_helper -> HTTP Status: {e.response.status_code}, Text: {e.response.text}, Request URL: {e.request.url}"
      logger.error(error_message)
      raise RuntimeError(error_message) # Re-raise as RuntimeError or a custom exception
    except httpx.RequestError as e:
      error_message = f"Error rest_api_helper -> Request Error: {e}, Request URL: {e.request.url}"
      logger.error(error_message)
      raise RuntimeError(error_message)
    except Exception as e:
      error_message = f"An unexpected error occurred in rest_api_helper: {e}"
      logger.error(error_message)
      raise RuntimeError(error_message)