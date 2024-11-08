# Get absolute path of the script
script_path=$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)

# Eliminate possible /tasks from the path
script_path=${script_path%/tasks}

# Get .env
source "$script_path/.env"

# If we're using macOS and homebrew not found, install it
if [[ "$(uname)" == "Darwin" && ! -x "$(command -v brew)" ]]; then
  echo -e "${BOLD}${YELLOW}Homebrew not found, installing...${RESET}"
  /bin/bash -c "$(curl -fsSL https://raw.githubusercontent.com/Homebrew/install/HEAD/install.sh)"
fi

# If gdate not found for macOS, install coreutils via homebrew
if [[ "$(uname)" == "Darwin" && ! -x "$(command -v gdate)" ]]; then
  echo -e "${BOLD}${YELLOW}gdate not found, installing coreutils...${RESET}"
  brew install coreutils
fi

# Function: Check if a task with the same title already exists in Todoist, including completed tasks for the same day
task_exists_in_todoist() {
  local project_id="$1"
  local event_title="$2"
  local current_day="$3"

  # Fetch active tasks from Todoist for the specific project
  active_tasks=$(curl -s -X GET "https://api.todoist.com/rest/v2/tasks?project_id=${project_id}" \
    -H "Authorization: Bearer ${TODOIST_API_KEY}")

  # Fetch completed tasks from Todoist for the specific project
  completed_tasks=$(curl -s -X GET "https://api.todoist.com/sync/v9/completed/get_all?project_id=${project_id}" \
    -H "Authorization: Bearer ${TODOIST_API_KEY}")

  # Check if any active task matches the event title exactly and was created the same day (using UTC date)
  if echo "$active_tasks" | jq -r --arg event_title "$event_title" --arg current_day "$current_day" \
    '.[] | select(.content == $event_title) | select(.due.date == $current_day)' | grep -qi "$event_title"; then
    # Active task exists
    return 0
  fi

  # Check if any completed task matches the event title and was completed today (using only the date part)
  if echo "$completed_tasks" | jq -r --arg event_title "$event_title" --arg current_day "$current_day" \
    '.items[] | select(.content | startswith($event_title)) | select(.completed_at | split("T")[0] == $current_day)' | grep -qi "$event_title"; then
    # Completed task exists
    return 0
  fi

  # Task does not exist
  return 1
}

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
  local days_to_process=1

  # If there's --days argument, set the number of days to process
  if [[ -n "$1" ]]; then
    days_to_process="$1"
  fi

  # Define calendar IDs and their associated Todoist projects
  local work_calendar=${WORK_CALENDAR_ID}
  local personal_calendars=("${FAMILY_CALENDAR_ID}" "${TRAINING_CALENDAR_ID}")

  # Automatically fetch Todoist project IDs by name
  local work_project_id=$(get_todoist_project_id "Todo")
  local personal_project_id=$(get_todoist_project_id "Kotiasiat")
  remaining_hours=$(calculate_remaining_hours "$current_time")

  # Debug
  if [ "$DEBUG" = true ]; then
    echo -e "${CYAN}Debug: work_project_id = $work_project_id${RESET}"
    echo -e "${CYAN}Debug: personal_project_id = $personal_project_id${RESET}"
    echo -e "${CYAN}Debug: work_calendar = $work_calendar${RESET}"
    echo -e "${CYAN}Debug: personal_calendars = ${personal_calendars[*]}${RESET}"
    echo -e "${CYAN}Debug: days_to_process = $days_to_process${RESET}"
    echo -e "${CYAN}Debug: start_day = $start_day${RESET}"
    echo -e "${CYAN}Debug: remaining_hours = $remaining_hours${RESET}"
  fi

  # Loop through each day
  for ((day=0; day<days_to_process; day++)); do
    # Calculate the date for each day being processed
    if [[ "$(uname)" == "Darwin" ]]; then
      current_day=$(gdate -I -d "$start_day +$day day")
      current_time=$(gdate +%H:%M:%SZ)
    else
      current_day=$(date -I -d "$start_day +$day day")
      current_time=$(date +%H:%M:%SZ)
    fi

    # Debug
    if [ "$DEBUG" = true ]; then
      echo -e "${CYAN}Debug: Processing day: $current_day${RESET}"
    fi

    # Set current time as the minimum time if processing today
    if [[ "$day" -eq 0 ]]; then
      timeMin="${current_day}T00:00:00Z"
    else
      timeMin="${current_day}T00:00:00Z"
    fi

    # End of each day
    timeMax="${current_day}T23:59:59Z"

    echo -e "${BOLD}${YELLOW}Fetching remaining events for $current_day...${RESET}"

    # Sync work calendar events to Todoist "Todo" project
    echo -e "${BOLD}${YELLOW}Fetching remaining events from work calendar: $work_calendar${RESET}"
    events=$(curl -s -X GET "https://www.googleapis.com/calendar/v3/calendars/${work_calendar}/events?timeMin=${timeMin}&timeMax=${timeMax}&singleEvents=true&orderBy=startTime" \
      -H "Authorization: Bearer ${GOOGLE_API_TOKEN}")

    # Check if the response contains an error
    if echo "$events" | grep -q '"error"'; then
      echo -e "${BOLD}${RED}Error fetching events for work calendar: $(echo "$events" | jq '.error.message')${RESET}"
    else
      echo "$events" | jq -c '.items[]' | while read -r event; do

        # Skip events that contain "Focus" in the title
        if [[ "$(echo "$event" | jq -r '.summary')" == *"Focus"* ]]; then
          echo -e "${BOLD}${RED}Skipping Focus event: $(echo "$event" | jq -r '.summary')${RESET}"
          continue
        fi

        # If attendees is not null
        if [[ "$(echo "$event" | jq -r '.attendees')" != "null" ]]; then
          # Check if the event is declined
          self_status=$(echo "$event" | jq -r '.attendees[] | select(.self == true) | .responseStatus')

          # Debug event status
          if [ "$DEBUG" = true ]; then
            echo -e "${CYAN}Debug: event_status = $self_status${RESET}"
          fi

          if [[ "$self_status" == "declined" ]]; then
            echo -e "${BOLD}${RED}Skipping declined event: $event_title${RESET}"
            continue
          fi
        fi

        event_title="$(echo "$event" | jq -r '.summary')"

        # Cut +03:00 from the end of the timestamp
        event_start=$(echo "$event" | jq -r '.start.dateTime // .start.date' | awk '{print substr($0, 1, 19)}')

        # Skip full-day events that only have date without time
        if [[ "$event_start" =~ ^[0-9]{4}-[0-9]{2}-[0-9]{2}$ ]]; then
          echo -e "${BOLD}${RED}Skipping full-day event: $event_title${RESET}"
          continue
        fi

        # Debug: print the event details
        if [ "$DEBUG" = true ]; then
          echo -e "${CYAN}Debug: event_title = $event_title${RESET}"
          echo -e "${CYAN}Debug: event_start = $event_start${RESET}"
        fi

        # Check if a task with the same title already exists in Todoist
        if task_exists_in_todoist "$work_project_id" "$event_title" "$current_day"; then
          echo -e "${BOLD}${RED}Task \"$event_title\" already exists in Todoist.${RESET}"
          continue
        fi

        # Convert date to seconds since epoch
        if [[ "$(uname)" == "Darwin" ]]; then
          start_timestamp=$(gdate -d "$event_start" +%s)
          end_timestamp=$(gdate -d "$(echo "$event" | jq -r '.end.dateTime // .end.date')" +%s)
        else
          start_timestamp=$(date -d "$event_start" +%s)
          end_timestamp=$(date -d "$(echo "$event" | jq -r '.end.dateTime // .end.date')" +%s)
        fi

        # Debug
        if [ "$DEBUG" = true ]; then
          echo -e "${CYAN}Debug: start_timestamp = $start_timestamp${RESET}"
          echo -e "${CYAN}Debug: end_timestamp = $end_timestamp${RESET}"
        fi

        # Ensure timestamps are valid before calculating the duration
        if [[ -n "$start_timestamp" && -n "$end_timestamp" && "$start_timestamp" -lt "$end_timestamp" ]]; then
            # Calculate the duration in minutes
            event_duration=$(( (end_timestamp - start_timestamp) / 60 ))

            if [ "$DEBUG" = true ]; then
              echo "${CYAN}Debug: Event duration in minutes: $event_duration${RESET}"
            fi
        else
            echo "${BOLD}${RED}Item duration is invalid, skipping event: $event_title${RESET}"
            continue
        fi

        # Create task in Todoist
        createtask=$(curl -s -X POST \
        --url "https://api.todoist.com/rest/v2/tasks" \
        --header "Content-Type: application/json" \
        --header "Authorization: Bearer ${TODOIST_API_KEY}" \
        -d "{
          \"content\": \"$event_title\",
          \"due_datetime\": \"$event_start\",
          \"project_id\": \"$work_project_id\",
          \"duration\": $event_duration,
          \"duration_unit\": \"minute\",
          \"labels\": [\"Google-kalenterin tapahtuma\"],
          \"priority\": 2
        }")

        # Debug
        if [ "$DEBUG" = true ]; then
          echo -e "${CYAN}Debug: createtask response: $createtask${RESET}"
        fi

        echo -e "${BOLD}${GREEN}Created a new task in Todo: $event_title${RESET}"
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

          # Skip events that contain "Focus" in the title
          if [[ "$(echo "$event" | jq -r '.summary')" == *"Focus"* ]]; then
            echo -e "${BOLD}${RED}Skipping Focus event: $(echo "$event" | jq -r '.summary')${RESET}"
            continue
          fi

          # If attendees is not null
          if [[ "$(echo "$event" | jq -r '.attendees')" != "null" ]]; then
            # Check if the event is declined
            self_status=$(echo "$event" | jq -r '.attendees[] | select(.self == true) | .responseStatus')

            # Debug event status
            if [ "$DEBUG" = true ]; then
              echo -e "${CYAN}Debug: event_status = $self_status${RESET}"
            fi

            if [[ "$self_status" == "declined" ]]; then
              echo -e "${BOLD}${RED}Skipping declined event: $event_title${RESET}"
              continue
            fi
          fi

          event_title="$(echo "$event" | jq -r '.summary')"

          # Cut +03:00 from the end of the timestamp
          event_start=$(echo "$event" | jq -r '.start.dateTime // .start.date' | awk '{print substr($0, 1, 19)}')

          # Skip full-day events that only have date without time
          if [[ "$event_start" =~ ^[0-9]{4}-[0-9]{2}-[0-9]{2}$ ]]; then
            echo -e "${BOLD}${RED}Skipping full-day event: $event_title${RESET}"
            continue
          fi

          # Check if a task with the same title already exists in Todoist
          if task_exists_in_todoist "$personal_project_id" "$event_title" "$current_day"; then
            echo -e "${BOLD}${RED}Task \"$event_title\" already exists in Todoist.${RESET}"
            continue
          fi

          # Also check if the task exists in the work project
          if task_exists_in_todoist "$work_project_id" "$event_title" "$current_day"; then
            echo -e "${BOLD}${RED}Task \"$event_title\" already exists in Todoist.${RESET}"
            continue
          fi

          # Convert date to seconds since epoch
          if [[ "$(uname)" == "Darwin" ]]; then
            start_timestamp=$(gdate -d "$event_start" +%s)
            end_timestamp=$(gdate -d "$(echo "$event" | jq -r '.end.dateTime // .end.date')" +%s)
          else
            start_timestamp=$(date -d "$event_start" +%s)
            end_timestamp=$(date -d "$(echo "$event" | jq -r '.end.dateTime // .end.date')" +%s)
          fi

          # Debug
          if [ "$DEBUG" = true ]; then
            echo -e "${CYAN}Debug: start_timestamp = $start_timestamp${RESET}"
            echo -e "${CYAN}Debug: end_timestamp = $end_timestamp${RESET}"
          fi

          # Ensure timestamps are valid before calculating the duration
          if [[ -n "$start_timestamp" && -n "$end_timestamp" && "$start_timestamp" -lt "$end_timestamp" ]]; then
              # Calculate the duration in minutes
              event_duration=$(( (end_timestamp - start_timestamp) / 60 ))

              if [ "$DEBUG" = true ]; then
                echo "${CYAN}Debug: Event duration in minutes: $event_duration${RESET}"
              fi
          else
              echo "${BOLD}${RED}Item duration is invalid, skipping event: $event_title${RESET}"
              continue
          fi

          # Create task in Todoist
          createtask=$(curl -s -X POST \
          --url "https://api.todoist.com/rest/v2/tasks" \
          --header "Content-Type: application/json" \
          --header "Authorization: Bearer ${TODOIST_API_KEY}" \
          -d "{
            \"content\": \"$event_title\",
            \"due_datetime\": \"$event_start\",
            \"project_id\": \"$personal_project_id\",
            \"duration\": $event_duration,
            \"duration_unit\": \"minute\",
            \"labels\": [\"Google-kalenterin tapahtuma\"],
            \"priority\": 2
          }")

          # Debug
          if [ "$DEBUG" = true ]; then
            echo -e "${CYAN}Debug: createtask response: $createtask${RESET}"
          fi

          echo -e "${BOLD}${GREEN}Created a new task in Kotiasiat: $event_title${RESET}"
        done
      fi
    done
  done
}

# Run the function to sync calendars
sync_google_calendar_to_todoist "$days_to_process"
