## First time
1. Open a Terminal
```
cd agent-code
python -m venv .venv
Mac:      source .venv/bin/activate
Windows: .venv\Scripts\activate.ps1
pip install -r requirements.txt
adk web -v

To use the custom UI:
Open a new terminal
cd agent-code-ui
python -m http.server 5555
adk web --allow_origins 'http://localhost:5555' -v

Open: http://localhost:5555
```

```
Complete clean of pycache: find . -name "__pycache__" -type d -exec rm -rv {} +
```

## Running
1. Open a Terminal
```
cd agent-code
Mac:      source .venv/bin/activate
Windows: .venv\Scripts\activate.ps1
adk web -v

To use the custom UI:
Open a new terminal
cd agent-code-ui
python -m http.server 5555
adk web --allow_origins 'http://localhost:5555' -v

Open: http://localhost:5555
```


## Test (new terminal)
```
cd agent-code
source .venv/bin/activate

export APP_URL="http://localhost:8000"
export TOKEN=$(gcloud auth print-identity-token)
export AGENT_NAME="data_analytics_agent"
export USER_ID="user-01"
export SESSION_ID="test-session-01"

# Get a list of the agents -> returns ["data-analytics-agent"]
curl -X GET -H "Authorization: Bearer $TOKEN" $APP_URL/list-apps


# Create a session
curl -X POST -H "Authorization: Bearer $TOKEN" \
    "$APP_URL/apps/${AGENT_NAME}/users/${USER_ID}/sessions/${SESSION_ID}" \
    -H "Content-Type: application/json" \
    -d '{"state": {"preferred_language": "English" }}'


# Call the agent
curl -X POST -H "Authorization: Bearer $TOKEN" \
    $APP_URL/run_sse \
    -H "Content-Type: application/json" \
    -d @- <<EOF
{
    "app_name": "${AGENT_NAME}",
    "user_id": "${USER_ID}",
    "session_id": "${SESSION_ID}",
    "new_message": {
        "role": "user",
        "parts": [{
        "text": "What is your name?"
        }]
    },
    "streaming": true
}
EOF
```


## Test (Deployed to Cloud Run)
```
# Use the REST API Cloud Run
export APP_URL="https://data-analytics-agent-001-517693961302.us-central1.run.app"
export TOKEN=$(gcloud auth print-identity-token)
export TOKEN=$(gcloud auth print-identity-token --audiences="https://data-analytics-agent-001-517693961302.us-central1.run.app")
export AGENT_NAME="data_analytics_agent"
export USER_ID="user-01"
export SESSION_ID="test-session-01"


# Get a list of the agents -> returns ["data-analytics-agent"]
curl -X GET -H "Authorization: Bearer $TOKEN" $APP_URL/list-apps


# Create a session
curl -X POST -H "Authorization: Bearer $TOKEN" \
    "$APP_URL/apps/${AGENT_NAME}/users/${USER_ID}/sessions/${SESSION_ID}" \
    -H "Content-Type: application/json" \
    -d '{"state": {"preferred_language": "English" }}'


# Call the agent
curl -X POST -H "Authorization: Bearer $TOKEN" \
    $APP_URL/run_sse \
    -H "Content-Type: application/json" \
    -d @- <<EOF
{
    "app_name": "${AGENT_NAME}",
    "user_id": "${USER_ID}",
    "session_id": "${SESSION_ID}",
    "new_message": {
        "role": "user",
        "parts": [{
        "text": "What tables do you have access to?"
        }]
    },
    "streaming": true
}
EOF

```

