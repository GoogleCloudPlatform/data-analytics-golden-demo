####################################################################################
# Copyright 2025 Google LLC
#
# Licensed under the Apache License, Version 2.0 (the "License");
# you may not use this file except in compliance with the License.
# You may obtain a copy of the License at
#
#     https://www.apache.org/licenses/LICENSE-2.0
#
# Unless required by applicable law or agreed to in writing, software
# distributed under the License is distributed on an "AS IS" BASIS,
# WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
# See the License for the specific language governing permissions and
# limitations under the License.
####################################################################################
import json
import requests
from requests.exceptions import HTTPError, Timeout
import logging

logger = logging.getLogger(__name__)


search_agent_instruction = """You are a **Knowledge Augmentation Agent**. Your purpose is to connect to the live internet via the Google Search tool to find information that is not available in your internal knowledge base. You act as a real-time researcher to provide up-to-date, factual information and to find documentation that can help answer complex questions.

**Your Primary Directive: When to Use Search**

You do not have access to real-time information. Your internal knowledge has a cutoff date. You **MUST** use the `google_search` tool when a user's request falls into one of these categories:

1.  **Current Events & Real-Time Information:**
    *   News, stock prices, sports scores, election results, product releases.
    *   Weather forecasts.
    *   Any question that implies "what is happening now" or "what is the latest."
    *   *Example:* "Who won the Best Picture Oscar this year?" or "What is the weather in London today?"

2.  **Information Beyond Your Training Data:**
    *   Details about very recent or niche topics, companies, or people that are unlikely to be in your training set.
    *   Facts and figures that are subject to frequent change (e.g., "What is the current population of Japan?").

3.  **Technical Documentation and "How-To" Guides:**
    *   When asked for specific syntax, error code explanations, or step-by-step instructions for a technology or process. The internet often has the most up-to-date official documentation.
    *   *Example:* "What are the command-line flags for the `gcloud compute instances create` command?" or "How do I fix a '502 Bad Gateway' error in Nginx?"

**Your Operational Playbook:**

1.  **Formulate an Effective Search Query:**
    *   Do not simply pass the user's entire question to the search tool. Distill the question into a concise and effective search query.
    *   Use keywords. Remove conversational filler.
    *   If a user asks, "Hey, can you tell me what the latest version of the Python programming language is and what some of the new features are?", a good search query would be `"latest python version features"`.

2.  **Execute the Search:**
    *   Call the `google_search(search_query: str)` tool with your formulated query.

3.  **Synthesize the Results:**
    *   **CRITICAL:** Do not just dump the raw search results (titles and snippets) back to the user. This is lazy and unhelpful.
    *   Read through the `title` and `snippet` of each result returned by the tool.
    *   Synthesize the information from the most relevant snippets to form a coherent, well-written answer to the user's original question.
    *   If the results are contradictory or insufficient, state that you could not find a definitive answer.
    *   It is good practice to cite your sources by mentioning the titles of the web pages from which you drew the information.

**Safety and Best Practices:**

*   **Fact-Checking:** Be aware that search results are not always accurate. If results from different sources conflict, point this out. Prioritize information from reputable sources (e.g., official documentation, major news outlets, academic institutions).
*   **Objectivity:** Present information factually and neutrally. Avoid expressing opinions or biases found in the search results.
*   **Acknowledge Your Actions:** Be transparent with the user. Start your response by saying, "I've searched the web and here's what I found..." This manages expectations and explains where the information is coming from.
"""



def google_search(search_query: str) -> dict:
    """
    Calls Google Search to search the internet.
    Use this for up to date information on news, weather, etc.
    You can also use this to supplement your knowledge and query help documents on subjects.

    Args:
        search_query (str): The search string

    Returns:
        dict:
        {
            "status": "success",
            "tool_name": "search_query",
            "query": "The google search query used",
            "messages": ["List of messages during processing"]
            "results": [ {"title": "N/A", "snippet": "N/A"} ] 
        }
    """
    import os

    # To get your API keys
    # 1. Go to: https://console.cloud.google.com/apis/credentials
    # 2. Click "Create Credentials" | "API Key"
    # 3. Copy the key
    # 4. Click "Edit API Key" (3 dots on the API Key itself)
    # 5. Click "Restrict Key" and check off "Custom Search API" and "Generative Language API" [NOT NEEDED]
    # 6. Click Save
    #
    # 1. Make sure the API  https://console.cloud.google.com/apis/api/customsearch.googleapis.com is enabled
    # 2. Make sure the API  https://console.cloud.google.com/apis/api/generativelanguage.googleapis.com is enable [NOT NEEDED]
    #
    # 1. Go here: https://programmablesearchengine.google.com/controlpanel/create
    # 2. Enter a name and select "Search Entire Web"
    # 3. Copy the CSE Id (you can edit it and copy the "Search engine ID" which is the GOOGLE_CSE_ID)

    GOOGLE_API_KEY = os.getenv("AGENT_ENV_GOOGLE_API_KEY")
    GOOGLE_CSE_ID = os.getenv("AGENT_ENV_GOOGLE_CSE_ID")
    messages = []

    # https://developers.google.com/custom-search/v1/reference/rest/v1/cse/list
    url = f"https://www.googleapis.com/customsearch/v1?key={GOOGLE_API_KEY}&cx={GOOGLE_CSE_ID}&q={search_query}&num=10"

    return_value = None

    try:
        response = requests.get(url, timeout=10)
        response.raise_for_status()  # Raises HTTPError for bad responses (4XX or 5XX)
        response_dict = response.json()

        results = []
        if "items" in response_dict:
            for item in response_dict.get("items", []): # Ensure items is a list
                results.append({
                    "title": item.get("title", "N/A"),
                    "snippet": item.get("snippet", "N/A")
                })

        messages.append(f"Call the url: {url}")
        return_value = { "status": "success", "tool_name": "google_search", "query": search_query, "messages": messages, "results": results }

    except Timeout:
        messages.append("Request to Google Search API timed out.")
        return_value = { "status": "failed", "tool_name": "google_search", "query": search_query, "messages": messages, "results": None }
    except HTTPError as http_err:
        messages.append(f"HTTP error occurred: {http_err} (Status code: {http_err.response.status_code})")
        try:
            details = str(http_err.response.text)
        except Exception:
            details = "Could not retrieve error details from response."
        return_value = { "status": "failed", "tool_name": "google_search", "query": search_query, "messages": messages, "results": None }
    except requests.exceptions.RequestException as req_err:
        messages.append(f"Request error occurred: {req_err}")
        return_value = { "status": "failed", "tool_name": "google_search", "query": search_query, "messages": messages, "results": None }
    except Exception as e: # Catch any other unexpected error
        messages.append(f"An unexpected error occurred in google_search: {str(e)}")
        return_value = { "status": "failed", "tool_name": "google_search", "query": search_query, "messages": messages, "results": None }

    return return_value