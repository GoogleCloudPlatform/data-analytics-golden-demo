### Initial setup 
1. ```python -m venv .venv```
2. activate your virtual environment
    - Mac:      ```source .venv/bin/activate```
    - Windows: ```.venv\Scripts\activate.ps1```
3. ```pip install -r ./agent-code/requirements.txt```
4. ```cd agent-code ```
5. ```adk web -v```

# To generate requirements.txt
```pip install pip-tools```
```pip-compile --generate-hashes requirements.in```

### To run (via terminal)
1. ```python -m venv .venv```
2. ```source .venv/bin/activate```
3. ```cd agent-code ```
4. ```adk web -v```


### To run in Debug mode in VS Code
1. create a .vscode folder at the root of the project.
2. create a launch.json in the folder
3. add this text:
```
{
    "version": "0.2.0",
    "configurations": [
        {
            "name": "Python: ADK Web",
            "type": "debugpy",
            "request": "launch",
            "cwd" : "${workspaceFolder}/agent-code",
            "program": "${workspaceFolder}/.venv/bin/adk",
            "args": [
                "web",
                "-v"
            ],
            "console": "integratedTerminal"
        }
    ]
}
```
4. In VS code "Run" | "Start Debugging"
5. Wait.... It might popup an alert, you can click "Cancel" on "Timed out waiting for launcher to connect"


### To use the custom UI
1. ```python -m venv .venv```
2. ```source .venv/bin/activate```
3. ```cd agent-code-ui```
4. ```python -m http.server 5555```

1. ```python -m venv .venv```
2. ```source .venv/bin/activate```
3. ```cd agent-code```
4. ```adk web --allow_origins 'http://localhost:5555' -v```

- ```Open: http://localhost:5555```


### To clean all python caches
- Complete clean of pycache: 
    - ```find . -name "__pycache__" -type d -exec rm -rv {} +```
------------------------------------------------------------------------------------------------


### Test via REST API
```
source .venv/bin/activate
cd agent-code

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


# Delete a session
curl -X DELETE -H "Authorization: Bearer $TOKEN" \
    "$APP_URL/apps/${AGENT_NAME}/users/${USER_ID}/sessions/${SESSION_ID}"
```


### Test via Cloud Run
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

