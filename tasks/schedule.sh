schedule_task() {
  local task_id="$1"
  local duration="$2"
  local datetime="$3"
  local current_day="$4"

  if [[ -z "$duration" || -z "$datetime" ]]; then
    echo -e "${RED}Error: Missing duration or datetime for task ID $task_id${RESET}"
    return
  fi

  # Check if local time is UTC, if not, convert to UTC
  if [[ "$(date +%Z)" != "UTC" ]]; then
    datetime=$(date -u -d "$datetime" "+%Y-%m-%dT%H:%M:%SZ")
  fi

  echo -e "${YELLOW}Scheduling task with ID: $task_id (Duration: $duration minutes, Datetime: $datetime)...${RESET}"

  # Get existing labels and task name for the task
  task_data=$(curl -s --request GET \
    --url "https://api.todoist.com/rest/v2/tasks/$task_id" \
    --header "Authorization: Bearer ${TODOIST_API_KEY}")
  task_name=$(echo "$task_data" | jq -r '.content')

  # Handle labels correctly as array, filtering out any empty values
  labels=$(echo "$task_data" | jq -r '.labels | map(select(length > 0))')

  # Skip scheduling if the task name contains "Google-kalenterin tapahtuma"
  if [[ "$task_name" == *"Google-kalenterin tapahtuma"* ]]; then
    echo -e "${YELLOW}Skipping scheduling task: $task_name (ID: $task_id)${RESET}"
    return 0
  fi

  # Handle recurring tasks
  recurring=$(echo "$task_data" | jq -r '.due.is_recurring')
  due_string=$(echo "$task_data" | jq -r '.due.string')

  # Debugging output to check the variables
  echo "Task name: $task_name, Task ID: $task_id, Duration: $duration, Datetime: $datetime, Recurring: $recurring, Labels: $labels"

  if [ "$recurring" == "true" ]; then
    if [ "$duration" -gt 0 ]; then
      # Update task's details and keep recurrence with duration
      update_response=$(curl -s --request POST \
        --url "https://api.todoist.com/rest/v2/tasks/$task_id" \
        --header "Content-Type: application/json" \
        --header "Authorization: Bearer ${TODOIST_API_KEY}" \
        --data "{\"due_datetime\": \"$datetime\", \"due_string\": \"$due_string\", \"duration\": \"$duration\", \"duration_unit\": \"minute\", \"labels\": $labels}")
    else
      # Update task's details and keep recurrence without duration
      update_response=$(curl -s --request POST \
        --url "https://api.todoist.com/rest/v2/tasks/$task_id" \
        --header "Content-Type: application/json" \
        --header "Authorization: Bearer ${TODOIST_API_KEY}" \
        --data "{\"due_datetime\": \"$datetime\", \"due_string\": \"$due_string\", \"labels\": $labels}")
    fi
  else
    if [ "$duration" -gt 0 ]; then
      # Update the task's details with duration
      update_response=$(curl -s --request POST \
        --url "https://api.todoist.com/rest/v2/tasks/$task_id" \
        --header "Content-Type: application/json" \
        --header "Authorization: Bearer ${TODOIST_API_KEY}" \
        --data "{\"due_datetime\": \"$datetime\", \"duration\": \"$duration\", \"duration_unit\": \"minute\", \"labels\": $labels}")
    else
      # Update the task's details without duration
      update_response=$(curl -s --request POST \
        --url "https://api.todoist.com/rest/v2/tasks/$task_id" \
        --header "Content-Type: application/json" \
        --header "Authorization: Bearer ${TODOIST_API_KEY}" \
        --data "{\"due_datetime\": \"$datetime\", \"labels\": $labels}")
    fi
  fi

  # Check if there was an error during the update
  if echo "$update_response" | grep -q '"error"'; then
    echo -e "${RED}Error scheduling task with ID $task_id: $update_response${RESET}"
  else
    echo -e "${GREEN}Task with ID $task_id successfully scheduled.${RESET}"
  fi

  # Debug response
  if [ "$DEBUG" = true ]; then
    echo -e "${CYAN}Update response:${RESET}\n$update_response\n"
  fi
}
