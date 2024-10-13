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
  # Define calendar IDs and their associated Todoist projects
  local work_calendar=${WORK_CALENDAR_ID}
  local personal_calendars=("${FAMILY_CALENDAR_ID}" "${TRAINING_CALENDAR_ID}")

  # Automatically fetch Todoist project IDs by name
  local work_project_id=$(get_todoist_project_id "Todo")
  local personal_project_id=$(get_todoist_project_id "Kotiasiat")

  # Get today's date
  local today=$(date -I)

  # Sync work calendar events to Todoist "Todo" project
  echo -e "${BOLD}${YELLOW}Fetching events from work calendar: $work_calendar${RESET}"
  events=$(curl -s -X GET "https://www.googleapis.com/calendar/v3/calendars/${work_calendar}/events?timeMin=${today}T00:00:00Z&timeMax=${today}T23:59:59Z&singleEvents=true&orderBy=startTime" \
    -H "Authorization: Bearer ${GOOGLE_API_TOKEN}")

  # Check if the response contains an error
  if echo "$events" | grep -q '"error"'; then
    echo -e "${BOLD}${RED}Error fetching events for work calendar: $(echo "$events" | jq '.error.message')${RESET}"
  else
    echo "$events" | jq -c '.items[]' | while read -r event; do
      event_title=$(echo "$event" | jq -r '.summary')
      event_start=$(echo "$event" | jq -r '.start.dateTime')
      event_end=$(echo "$event" | jq -r '.end.dateTime')

      # Check if start or end time is null
      if [[ "$event_start" == "null" || "$event_end" == "null" ]]; then
        echo -e "${BOLD}${RED}Skipping event with missing date: $event_title${RESET}"
        continue
      fi

      # Calculate duration only if start and end times are valid
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

        echo -e "${BOLD}${GREEN}Created a new task in Todo: $event_title${RESET}"
      else
        echo -e "${BOLD}${YELLOW}Task \"$event_title\" already exists in Todoist.${RESET}"
      fi
    done
  fi

  # Sync personal calendar events to Todoist "Kotiasiat" project
  for calendar_id in "${personal_calendars[@]}"; do
    echo -e "${BOLD}${YELLOW}Fetching events from personal calendar: $calendar_id${RESET}"
    events=$(curl -s -X GET "https://www.googleapis.com/calendar/v3/calendars/${calendar_id}/events?timeMin=${today}T00:00:00Z&timeMax=${today}T23:59:59Z&singleEvents=true&orderBy=startTime" \
      -H "Authorization: Bearer ${GOOGLE_API_TOKEN}")

    # Check if the response contains an error
    if echo "$events" | grep -q '"error"'; then
      echo -e "${BOLD}${RED}Error fetching events for personal calendar: $(echo "$events" | jq '.error.message')${RESET}"
    else
      echo "$events" | jq -c '.items[]' | while read -r event; do
        event_title=$(echo "$event" | jq -r '.summary')
        event_start=$(echo "$event" | jq -r '.start.dateTime')
        event_end=$(echo "$event" | jq -r '.end.dateTime')

        # Check if start or end time is null
        if [[ "$event_start" == "null" || "$event_end" == "null" ]]; then
          echo -e "${BOLD}${RED}Skipping event with missing date: $event_title${RESET}"
          continue
        fi

        # Calculate duration only if start and end times are valid
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

          echo -e "${BOLD}${GREEN}Created a new task in Kotiasiat: $event_title${RESET}"
        else
          echo -e "${BOLD}${YELLOW}Task \"$event_title\" already exists in Todoist.${RESET}"
        fi
      done
    fi
  done
}

# Run the function to sync calendars
sync_google_calendar_to_todoist
