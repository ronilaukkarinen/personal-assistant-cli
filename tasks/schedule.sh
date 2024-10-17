schedule_task() {
  local task_id="$1"
  local duration="$2"
  local datetime="$3"
  local current_day="$4"

  if [[ -z "$duration" || -z "$datetime" ]]; then
    echo -e "${RED}Error: Missing duration or datetime for task ID $task_id${RESET}"
    return
  fi

  # Ensure duration and datetime are valid by using only the first match
  # Ensures only the first duration is used
  duration=$(echo "$duration" | head -n 1)

  # Ensures only the first datetime is used
  datetime=$(echo "$datetime" | head -n 1)

  # Get task data
  task_data=$(curl -s --request GET \
    --url "https://api.todoist.com/rest/v2/tasks/$task_id" \
    --header "Authorization: Bearer ${TODOIST_API_KEY}")
  task_name=$(echo "$task_data" | jq -r '.content')

  echo -e "${YELLOW}Scheduling task $task_name, with ID: $task_id (Duration: $duration minutes, Datetime: $datetime)...${RESET}"

  # Check if task has a label with name "Google-kalenterin tapahtuma"
  if echo "$task_data" | jq -r '.labels[]' | grep -q "Google-kalenterin tapahtuma"; then
    echo -e "${YELLOW}Skipping postponing task, because it has the calendar label: $task_name (ID: $task_id)${RESET}"
    return 0
  fi

  # Skip scheduling if the task name contains "Rutiinit"
  if [[ "$task_name" == *"Rutiinit"* ]]; then
    echo -e "${YELLOW}Skipping scheduling task: $task_name (ID: $task_id)${RESET}"
    return 0
  fi

  # Handle recurring tasks
  recurring=$(echo "$task_data" | jq -r '.due.is_recurring')
  due_string=$(echo "$task_data" | jq -r '.due.string')

  # Debugging output to check the variables
  echo "Task name: $task_name, Task ID: $task_id, Duration: $duration, Datetime: $datetime, Recurring: $recurring"

  if [ "$recurring" == "true" ]; then
    if [ "$duration" -gt 0 ]; then
      # Update task's details and keep recurrence with duration
      update_response=$(curl -s --request POST \
        --url "https://api.todoist.com/rest/v2/tasks/$task_id" \
        --header "Content-Type: application/json" \
        --header "Authorization: Bearer ${TODOIST_API_KEY}" \
        --data "{\"due_datetime\": \"$datetime\", \"due_string\": \"$due_string\", \"duration\": \"$duration\", \"duration_unit\": \"minute\"}")
    else
      # Update task's details and keep recurrence without duration
      update_response=$(curl -s --request POST \
        --url "https://api.todoist.com/rest/v2/tasks/$task_id" \
        --header "Content-Type: application/json" \
        --header "Authorization: Bearer ${TODOIST_API_KEY}" \
        --data "{\"due_datetime\": \"$datetime\", \"due_string\": \"$due_string\"}")
    fi
  else
    if [ "$duration" -gt 0 ]; then
      # Update the task's details with duration
      update_response=$(curl -s --request POST \
        --url "https://api.todoist.com/rest/v2/tasks/$task_id" \
        --header "Content-Type: application/json" \
        --header "Authorization: Bearer ${TODOIST_API_KEY}" \
        --data "{\"due_datetime\": \"$datetime\", \"duration\": \"$duration\", \"duration_unit\": \"minute\"}")
    else
      # Update the task's details without duration
      update_response=$(curl -s --request POST \
        --url "https://api.todoist.com/rest/v2/tasks/$task_id" \
        --header "Content-Type: application/json" \
        --header "Authorization: Bearer ${TODOIST_API_KEY}" \
        --data "{\"due_datetime\": \"$datetime\"}")
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
