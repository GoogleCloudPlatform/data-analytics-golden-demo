#!/usr/bin/env bash

#
# A Bash script to interact with the Google Gemini API.
#
# Usage:
#   gemini "your prompt here"
#
# Example:
#   gemini "list 3 benefits of using bash scripting"
#   gemini "translate 'hello world' to Spanish"
#   gemini 'parse this json to get the id element: {"id": 123, "name": "test"}'
#   source gemini.sh "Parse this json and get me the menu name for menu id of 3: $(cat temp.json)"
#
# Dependencies:
#   - gcloud CLI (authenticated with 'gcloud auth application-default login')
#   - curl
#

# --- Configuration ---
# You can override these variables if needed.
# The script attempts to get the PROJECT_ID automatically from your gcloud config.
# For available models and locations, see:
# https://cloud.google.com/vertex-ai/generative-ai/docs/model-reference/inference

LOCATION="us-central1"
MODEL_ID="gemini-2.5-flash" # or "gemini-1.5-flash-001", etc.
PROJECT_ID=$(gcloud config get-value project 2>/dev/null)


# --- Script Logic ---

# Function to display usage information and exit
usage() {
  echo "Usage: gemini \"<prompt>\"" >&2
  echo "Example: gemini \"What is the capital of France?\"" >&2
  exit 1
}

# Check for dependencies
if ! command -v gcloud &> /dev/null; then
  echo "Error: 'gcloud' command not found." >&2; exit 1;
fi

if ! command -v curl &> /dev/null; then
  echo "Error: 'curl' command not found." >&2; exit 1;
fi

# JQ is required for this version of the script
if ! command -v jq &> /dev/null; then
  echo "Error: 'jq' command not found. Please install it (e.g., 'brew install jq')." >&2
  exit 1
fi

# Check for Project ID
if [[ -z "$PROJECT_ID" ]]; then
  echo "Error: Google Cloud project ID not found." >&2
  echo "Please set your project using 'gcloud config set project YOUR_PROJECT_ID'" >&2
  exit 1
fi

# Check for prompt argument
if [[ $# -eq 0 || -z "$1" ]]; then
  usage
fi

PROMPT="$1"

# Function to escape strings for JSON
# Handles backslashes, quotes, and newlines.
json_escape() {
  # Pipe the input through sed to perform replacements:
  # 1. Escape backslashes
  # 2. Escape double quotes
  # 3. Replace newline characters with \n
  # 4. Replace carriage returns with \r
  # 5. Replace tabs with \t
  sed -e 's/\\/\\\\/g' -e 's/"/\\"/g' -e 's/\n/\\n/g' -e 's/\r/\\r/g' -e 's/\t/\\t/g'
}

# Escape the user prompt
ESCAPED_PROMPT=$(echo -n "$PROMPT" | json_escape)

# Fetch the access token
ACCESS_TOKEN=$(gcloud auth print-access-token)
if [[ -z "$ACCESS_TOKEN" ]]; then
    echo "Error: Failed to get access token from gcloud." >&2
    exit 1
fi

# The API enforces a JSON structure in the response, which simplifies parsing.
# This schema tells Gemini to return a single string field named "gemini-result".
# We use a 'here document' (<<EOF) to build the JSON payload.
read -r -d '' JSON_PAYLOAD <<EOF
{
  "contents": {
    "role": "user",
    "parts": {
      "text": "${ESCAPED_PROMPT}"
    }
  },
  "generationConfig": {
    "response_mime_type": "application/json",
    "response_schema": {
      "type": "object",
      "properties": {
        "gemini-result": {
          "type": "string"
        }
      },
      "required": ["gemini-result"]
    }
  },
  "safety_settings": {
      "category": "HARM_CATEGORY_SEXUALLY_EXPLICIT",
      "threshold": "BLOCK_LOW_AND_ABOVE"
  }
}
EOF

# Define the API endpoint URL
API_URL="https://${LOCATION}-aiplatform.googleapis.com/v1/projects/${PROJECT_ID}/locations/${LOCATION}/publishers/google/models/${MODEL_ID}:generateContent"

# Make the API call with curl
# -s: silent mode (no progress meter)
# -f: fail silently (exit with error code on HTTP error)
# -H: headers
# -d: data payload
API_RESPONSE=$(curl -s -f \
  -X POST \
  -H "Authorization: Bearer ${ACCESS_TOKEN}" \
  -H "Content-Type: application/json" \
  -d "${JSON_PAYLOAD}" \
  "${API_URL}")

# Check if curl command failed
if [[ $? -ne 0 ]]; then
  echo "Error: API call failed. The server responded with an error." >&2
  # If API_RESPONSE has content, it's the error message from the server
  if [[ -n "$API_RESPONSE" ]]; then
    echo "Response: ${API_RESPONSE}" >&2
  fi
  exit 1
fi

#####
#echo "Response: ${API_RESPONSE}"
PARSED_RESULT=$(echo "${API_RESPONSE}" | jq -r '.candidates[0].content.parts[0].text | fromjson | .["gemini-result"]')
echo "$PARSED_RESULT"
