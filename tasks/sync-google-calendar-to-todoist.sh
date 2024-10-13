# Function: Fetch Todoist project ID by project name
get_todoist_project_id() {
  local project_name="$1"

  # Fetch all projects from Todoist
  projects=$(curl -s -X GET "https://api.todoist.com/rest/v2/projects" \
    -H "Authorization: Bearer ${TODOIST_API_KEY}")

  # Extract the project ID based on the project name
  project_id=$(echo "$projects" | jq -r --arg name "$project_name" '.[] | select(.name == $name) | .id')

  if [[ -z "$project_id" ]]; then
    echo "Project \"$project_name\" not found in Todoist."
    exit 1
  fi

  echo "$project_id"
}

# Function: Fetch events from multiple Google Calendars and add them as Todoist tasks
sync_google_calendar_to_todoist() {
  # Use environment variable to define whether sync is enabled or not
  GCAL_EVENTS_TO_TASKS_ENABLED=1

  # Define calendar IDs and their associated Todoist projects
  local work_calendar="Roni Laukkarinen (Rollen työkalenteri)"
  local personal_calendars=("Perhekalenteri" "Treenit")

  # Automatically fetch Todoist project IDs by name
  local work_project_id=$(get_todoist_project_id "Todo")
  local personal_project_id=$(get_todoist_project_id "Kotiasiat")

  # Get today's date
  local today=$(date -I)

  # Sync work calendar events to Todoist "Todo" project
  echo "${BOLD}${YELLOW}Fetching events from work calendar: $work_calendar${RESET}"
  events=$(curl -s -X GET "https://www.googleapis.com/calendar/v3/calendars/${work_calendar}/events?timeMin=${today}T00:00:00Z&timeMax=${today}T23:59:59Z&singleEvents=true&orderBy=startTime" \
    -H "Authorization: Bearer ${GOOGLE_API_TOKEN}")

  echo "$events" | jq -c '.items[]' | while read -r event; do
    event_title=$(echo "$event" | jq -r '.summary')
    event_start=$(echo "$event" | jq -r '.start.dateTime')
    event_end=$(echo "$event" | jq -r '.end.dateTime')
    event_duration=$(date -u -d "$(date -d "$event_end" +%s) - $(date -d "$event_start" +%s)" +%H:%M)

    # Check if task already exists in Todoist
    existing_task=$(curl -s -X GET "https://api.todoist.com/rest/v2/tasks?filter=search:$event_title" \
      -H "Authorization: Bearer ${TODOIST_API_KEY}")

    if [[ -z "$existing_task" ]]; then
      # Create task in "Todo" project
      curl -s -X POST "https://api.todoist.com/rest/v2/tasks" \
      -H "Authorization: Bearer ${TODOIST_API_KEY}" \
      -H "Content-Type: application/json" \
      -d '{
        "content": "'"$event_title"'",
        "due_datetime": "'"$event_start"'",
        "project_id": "'"$work_project_id"'",
        "duration": "'"$event_duration"'"
      }'

      echo "${BOLD}${GREEN}Created a new task in Todo: $event_title${RESET}"
    else
      echo "${BOLD}${RED}Task \"$event_title\" already exists in Todoist.${RESET}"
    fi
  done

  # Sync personal calendar events to Todoist "Kotiasiat" project
  for calendar_id in "${personal_calendars[@]}"; do
    echo "Fetching events from personal calendar: $calendar_id"
    events=$(curl -s -X GET "https://www.googleapis.com/calendar/v3/calendars/${calendar_id}/events?timeMin=${today}T00:00:00Z&timeMax=${today}T23:59:59Z&singleEvents=true&orderBy=startTime" \
      -H "Authorization: Bearer ${GOOGLE_API_TOKEN}")

    echo "$events" | jq -c '.items[]' | while read -r event; do
      event_title=$(echo "$event" | jq -r '.summary')
      event_start=$(echo "$event" | jq -r '.start.dateTime')
      event_end=$(echo "$event" | jq -r '.end.dateTime')
      event_duration=$(date -u -d "$(date -d "$event_end" +%s) - $(date -d "$event_start" +%s)" +%H:%M)

      # Check if task already exists in Todoist
      existing_task=$(curl -s -X GET "https://api.todoist.com/rest/v2/tasks?filter=search:$event_title" \
        -H "Authorization: Bearer ${TODOIST_API_KEY}")

      if [[ -z "$existing_task" ]]; then
        # Create task in "Kotiasiat" project
        curl -s -X POST "https://api.todoist.com/rest/v2/tasks" \
        -H "Authorization: Bearer ${TODOIST_API_KEY}" \
        -H "Content-Type: application/json" \
        -d '{
          "content": "'"$event_title"'",
          "due_datetime": "'"$event_start"'",
          "project_id": "'"$personal_project_id"'",
          "duration": "'"$event_duration"'"
        }'

        echo "${BOLD}${GREEN}Created a new task in Kotiasiat: $event_title${RESET}"
      else
        echo "${BOLD}${RED}Task \"$event_title\" already exists in Todoist.${RESET}"
      fi
    done
  done
}

# Run the function to sync calendars
sync_google_calendar_to_todoist
