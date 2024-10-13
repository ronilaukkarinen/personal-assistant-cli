# Function to refresh the access token
refresh_access_token() {
    response=$(curl -s -X POST \
    -d "client_id=${GOOGLE_CLIENT_ID}" \
    -d "client_secret=${GOOGLE_CLIENT_SECRET}" \
    -d "refresh_token=${GOOGLE_REFRESH_TOKEN}" \
    -d "grant_type=refresh_token" \
    https://accounts.google.com/o/oauth2/token)

    # Parse and store the new access token
    access_token=$(echo $response | jq -r .access_token)

    # Set the new access token in the environment variable
    export GOOGLE_API_TOKEN=$access_token
}

# Call the function to refresh the access token before making API calls
refresh_access_token

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

  # Get today's date in proper format for Google Calendar API
  local today=$(date -I)

  # Get current UTC time
  local current_time=$(date -u +%H:%M:%SZ)

  # Set current time as the minimum time
  local timeMin="${today}T${current_time}"

  # End of today
  local timeMax="${today}T23:59:59Z"

  # Sync work calendar events to Todoist "Todo" project
  echo -e "${BOLD}${YELLOW}Fetching remaining events from work calendar: $work_calendar${RESET}"
  events=$(curl -s -X GET "https://www.googleapis.com/calendar/v3/calendars/${work_calendar}/events?timeMin=${timeMin}&timeMax=${timeMax}&singleEvents=true&orderBy=startTime" \
    -H "Authorization: Bearer ${GOOGLE_API_TOKEN}")

  # Check if the response contains an error
  if echo "$events" | grep -q '"error"'; then
    echo -e "${BOLD}${RED}Error fetching events for work calendar: $(echo "$events" | jq '.error.message')${RESET}"
  else
    echo "$events" | jq -c '.items[]' | while read -r event; do
      event_title=$(echo "$event" | jq -r '.summary')
      event_start=$(echo "$event" | jq -r '.start.dateTime // .start.date')
      event_end=$(echo "$event" | jq -r '.end.dateTime // .end.date')

      # Convert Unix timestamp to readable date if necessary
      if [[ "$event_start" =~ ^[0-9]+$ ]]; then
        event_start=$(date -d "@$event_start" +'%Y-%m-%dT%H:%M:%S')
      fi

      if [[ "$event_end" =~ ^[0-9]+$ ]]; then
        event_end=$(date -d "@$event_end" +'%Y-%m-%dT%H:%M:%S')
      fi

      # Check if start or end time is null
      if [[ "$event_start" == "null" || "$event_end" == "null" ]]; then
        echo -e "${BOLD}${RED}Skipping event with missing date: $event_title${RESET}"
        continue
      fi

      # Calculate duration only if start and end times are valid
      start_timestamp=$(date -d "$event_start" +%s)
      end_timestamp=$(date -d "$event_end" +%s)
      if [[ "$start_timestamp" != "" && "$end_timestamp" != "" ]]; then
        event_duration=$(date -u -d "@$((end_timestamp - start_timestamp))" +%H:%M)
      else
        echo -e "${BOLD}${RED}Item duration is invalid${RESET}"
        continue
      fi

      today=$(date -I)

      # Check if the event is for today
      if [[ "$event_start" == "$today"* ]]; then
        # Event is for today, create task in Todoist
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
        echo -e "${BOLD}${YELLOW}Skipping event: $event_title, not for today.${RESET}"
      fi

    done
  fi

  # Sync personal calendar events to Todoist "Kotiasiat" project
  for calendar_id in "${personal_calendars[@]}"; do
    echo -e "${BOLD}${YELLOW}Fetching remaining events from personal calendar: $calendar_id${RESET}"
    events=$(curl -s -X GET "https://www.googleapis.com/calendar/v3/calendars/${calendar_id}/events?timeMin=${timeMin}&timeMax=${timeMax}&singleEvents=true&orderBy=startTime" \
      -H "Authorization: Bearer ${GOOGLE_API_TOKEN}")

    # Check if the response contains an error
    if echo "$events" | grep -q '"error"'; then
      echo -e "${BOLD}${RED}Error fetching events for personal calendar: $(echo "$events" | jq '.error.message')${RESET}"
    else
      echo "$events" | jq -c '.items[]' | while read -r event; do
        event_title=$(echo "$event" | jq -r '.summary')
        event_start=$(echo "$event" | jq -r '.start.dateTime // .start.date')
        event_end=$(echo "$event" | jq -r '.end.dateTime // .end.date')

        # Convert Unix timestamp to readable date if necessary
        if [[ "$event_start" =~ ^[0-9]+$ ]]; then
          event_start=$(date -d "@$event_start" +'%Y-%m-%dT%H:%M:%S')
        fi

        if [[ "$event_end" =~ ^[0-9]+$ ]]; then
          event_end=$(date -d "@$event_end" +'%Y-%m-%dT%H:%M:%S')
        fi

        # Check if start or end time is null
        if [[ "$event_start" == "null" || "$event_end" == "null" ]]; then
          echo -e "${BOLD}${RED}Skipping event with missing date: $event_title${RESET}"
          continue
        fi

        # Calculate duration only if start and end times are valid
        start_timestamp=$(date -d "$event_start" +%s)
        end_timestamp=$(date -d "$event_end" +%s)
        if [[ "$start_timestamp" != "" && "$end_timestamp" != "" ]]; then
          event_duration=$(date -u -d "@$((end_timestamp - start_timestamp))" +%H:%M)
        else
          echo -e "${BOLD}${RED}Item duration is invalid${RESET}"
          continue
        fi

        today=$(date -I)

        # Check if the event is for today
        if [[ "$event_start" == "$today"* ]]; then
          # Event is for today, create task in Todoist
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
          echo -e "${BOLD}${YELLOW}Skipping event: $event_title, not for today.${RESET}"
        fi

      done
    fi
  done
}

# Run the function to sync calendars
sync_google_calendar_to_todoist
