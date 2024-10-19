#!/bin/bash
# Tester script for Todoist operations (no actual modifications)

# Load environment variables
source ../.env

# Set the Todoist API key from environment variable
TODOIST_API_KEY="${TODOIST_API_KEY}"

# Test event title
event_title="Urhon luo Manun kanssa"

# Function: Check if a task with the same title already exists in Todoist, including completed tasks
task_exists_in_todoist() {
  local project_id="$1"
  local event_title="$2"

  echo "Fetching active tasks for project ID: $project_id..."

  # Fetch active tasks from Todoist
  active_tasks=$(curl -s -X GET "https://api.todoist.com/rest/v2/tasks?project_id=${project_id}" \
    -H "Authorization: Bearer ${TODOIST_API_KEY}")

  # Fetch completed tasks from Todoist
  completed_tasks=$(curl -s -X GET "https://api.todoist.com/sync/v9/completed/get_all?project_id=${project_id}" \
    -H "Authorization: Bearer ${TODOIST_API_KEY}")

  # Check if any active task matches the event title exactly and was created the same day
  if echo "$active_tasks" | jq -r --arg event_title "$event_title" --arg current_day "$current_day" \
    '.[] | select(.content == $event_title) | select(.created_at != null and (.created_at | startswith($current_day)))'; then
    echo "Active task with title '$event_title' exists in Todoist."
    return 0
  fi

  echo "Debug: Checking completed tasks..."
  echo "Debug: Checking completed tasks for event title: $event_title"
  echo "Debug: Completed tasks: $(echo "$completed_tasks" | jq '.items[].content')"

  # Check completed tasks
  task_found=$(echo "$completed_tasks" | jq -r --arg event_title "$event_title" --arg current_day "$current_day" \
    '.items[] | select(.content == $event_title) | select(.created_at != null and (.created_at | startswith($current_day)))')

  if [[ -n "$task_found" ]]; then
    echo "Completed task with title '$event_title' exists in Todoist."
    return 0
  fi

  echo "Task not found."
  return 1
}

# Function to refresh the access token (simulated)
refresh_access_token() {
    echo "Refreshing access token (simulated)..."
    response=$(curl -s -X POST \
    -d "client_id=${GOOGLE_CLIENT_ID}" \
    -d "client_secret=${GOOGLE_CLIENT_SECRET}" \
    -d "refresh_token=${GOOGLE_REFRESH_TOKEN}" \
    -d "grant_type=refresh_token" \
    https://accounts.google.com/o/oauth2/token)

    # Simulate access token retrieval
    access_token=$(echo "$response" | jq -r .access_token)
    export GOOGLE_API_TOKEN=$access_token
    echo "Access token refreshed."
}

# Fetch Todoist project ID by project name (simulated)
get_todoist_project_id() {
  local project_name="$1"
  echo "Fetching project ID for project name: $project_name..."

  # Simulate fetching project ID
  projects=$(curl -s -X GET "https://api.todoist.com/rest/v2/projects" \
    -H "Authorization: Bearer ${TODOIST_API_KEY}")
  project_id=$(echo "$projects" | jq -r --arg name "$project_name" '.[] | select(.name == $name) | .id')

  if [[ -z "$project_id" ]]; then
    echo "Project \"$project_name\" not found in Todoist."
    exit 1
  fi

  echo "Project ID for $project_name: $project_id"
}

# Function: Sync Google Calendar to Todoist (simulated, no actual changes)
sync_google_calendar_to_todoist() {
  local days_to_process=1
  echo "Simulating Google Calendar sync for $days_to_process days..."

  # Simulate fetching events and Todoist tasks
  echo "Fetching events from Google Calendar (simulated)..."
  echo "Fetching Todoist tasks (simulated)..."

  # Simulate checking for task existence
  task_exists_in_todoist "123456" "Test Event Title"

  echo "Google Calendar sync simulated successfully."
}

# Simulate access token refresh
refresh_access_token

# Fetch a test project ID (simulated)
get_todoist_project_id "Todo"

# Simulate Google Calendar sync to Todoist
sync_google_calendar_to_todoist
