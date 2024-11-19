schedule_task() {
  local task_id="$1"
  local duration="$2"
  local datetime="$3"
  local current_day="$4"

  # Ensure duration and datetime are valid by using only the first match if present
  if [ ! -z "$duration" ]; then
    duration=$(echo "$duration" | head -n 1)
  fi
  if [ ! -z "$datetime" ]; then
    datetime=$(echo "$datetime" | head -n 1)
  fi

  # Get existing labels and task name for the task
  task_data=$(curl -s --request GET \
    --url "https://api.todoist.com/rest/v2/tasks/$task_id" \
    --header "Authorization: Bearer ${TODOIST_API_KEY}")

  if [ -z "$task_data" ]; then
    echo -e "${RED}Error: Failed to fetch task data for ID $task_id${RESET}"
    return 1
  fi

  task_name=$(echo "$task_data" | jq -r '.content')
  labels=$(echo "$task_data" | jq -r '.labels | join(", ")')

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

  # Determine the appropriate date command for macOS (Darwin) or other systems
  if [[ "$(uname)" == "Darwin" ]]; then
    date_cmd="gdate"
  else
    date_cmd="date"
  fi

  if [ ! -z "$datetime" ]; then
    formatted_month=$($date_cmd -d "$datetime" "+%B" | tr '[:upper:]' '[:lower:]')
    formatted_date=$($date_cmd -d "$datetime" "+%-d. ${formatted_month}ta %Y")
    formatted_time=$($date_cmd -d "$datetime" "+%H:%M")
    task_date=$($date_cmd -d "$datetime" "+%Y-%m-%d")
  fi

  # Build update data based on what's available
  update_data="{"
  if [ "$recurring" == "true" ]; then
    if [ ! -z "$datetime" ]; then
      update_data+="\"due_datetime\": \"$datetime\", \"due_string\": \"$due_string\""
    fi
    if [ ! -z "$duration" ] && [ "$duration" -gt 0 ]; then
      if [ ! -z "$datetime" ]; then update_data+=", "; fi
      update_data+="\"duration\": \"$duration\", \"duration_unit\": \"minute\""
    fi
  else
    if [ ! -z "$datetime" ]; then
      update_data+="\"due_datetime\": \"$datetime\""
    fi
    if [ ! -z "$duration" ] && [ "$duration" -gt 0 ]; then
      if [ ! -z "$datetime" ]; then update_data+=", "; fi
      update_data+="\"duration\": \"$duration\", \"duration_unit\": \"minute\""
    fi
  fi
  update_data+="}"

  # Only update if we have data to update
  if [ "$update_data" != "{}" ]; then
    update_response=$(curl -s --request POST \
      --url "https://api.todoist.com/rest/v2/tasks/$task_id" \
      --header "Content-Type: application/json" \
      --header "Authorization: Bearer ${TODOIST_API_KEY}" \
      --data "$update_data")
  fi

  # Only add comment if task is scheduled for a different day and datetime exists
  if [ ! -z "$datetime" ] && [ ! -z "$task_date" ] && [ "$task_date" != "$current_day" ]; then
    # Prettified comment to be added to the scheduled task
    comment="🤖 Rollen tekoälyavustaja v${SCRIPT_VERSION} lykkäsi tätä tehtävää eteenpäin ajalle $formatted_date, kello $formatted_time. Tehtävän kestoksi määriteltiin $duration minuuttia."

    # Add a comment to the task after scheduling
    comment_response=$(curl -s --request POST \
      --url "https://api.todoist.com/rest/v2/comments" \
      --header "Content-Type: application/json" \
      --header "Authorization: Bearer ${TODOIST_API_KEY}" \
      --data "{\"task_id\": \"$task_id\", \"content\": \"$comment\"}")
  fi

  # Check if there was an error during the update
  if [ ! -z "$update_response" ] && echo "$update_response" | grep -q '"error"'; then
    echo -e "${RED}Error scheduling task with ID $task_id: $update_response${RESET}"
  else
    echo -e "${GREEN}Task with ID $task_id successfully scheduled with comment.${RESET}"
  fi

  # Debug response
  if [ "$DEBUG" = true ]; then
    echo -e "${CYAN}Update response:${RESET}\n$update_response\n"
    echo -e "${CYAN}Comment response:${RESET}\n$comment_response\n"
  fi
}
