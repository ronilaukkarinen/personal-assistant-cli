postpone_task() {
  local task_id="$1"
  local current_day="$2"
  local next_day

  # Calculate the next day based on the current day
  if [[ "$(uname)" == "Darwin" ]]; then
    next_day=$(gdate -d "$current_day + 1 day" "+%Y-%m-%d")
  else
    next_day=$(date -d "$current_day + 1 day" "+%Y-%m-%d")
  fi

  # Get existing labels and task name for the task
  task_data=$(curl -s --request GET \
    --url "https://api.todoist.com/rest/v2/tasks/$task_id" \
    --header "Authorization: Bearer ${TODOIST_API_KEY}")
  task_name=$(echo "$task_data" | jq -r '.content')
  labels=$(echo "$task_data" | jq -r '.labels')

  # Get task duration, handle cases where duration is null or missing
  task_duration=$(echo "$task_data" | jq -r '.duration.amount // empty')

  # Get task date
  task_date=$(echo "$task_data" | jq -r '.due.date')

  # If task date is not today, skip postponing
  if [ "$task_date" != "$current_day" ]; then
    echo -e "${YELLOW}Skipping postponing task that is not due today: $task_name (ID: $task_id)${RESET}"
    return 0
  fi

  # Do not postpone task if it contains "Rutiinit"
  if [[ "$task_name" == *"Rutiinit"* ]]; then
    echo -e "${YELLOW}Skipping postponing task: $task_name (ID: $task_id)${RESET}"
    return 0
  fi

  # Do not postpone if the task name contains "Google-kalenterin tapahtuma"
  if [[ "$task_name" == *"Google-kalenterin tapahtuma"* ]]; then
    echo -e "${YELLOW}Skipping postponing task: $task_name (ID: $task_id)${RESET}"
    return 0
  fi

  # Check if the task already has a 'Lykätty x kertaa' label
  retry_count=1
  updated_labels=()
  for label in $(echo "$labels" | jq -r '.[]'); do
    if [[ "$label" =~ "Lykätty" ]]; then
      # Extract current retry count
      retry_count=$(echo "$label" | grep -oP '\d+')
      retry_count=$((retry_count + 1))
    else
      # Add all other labels to updated_labels array
      updated_labels+=("\"$label\"")
    fi
  done

  # Set the correct "Lykätty" label based on retry count
  if [ "$retry_count" -eq 1 ]; then
    new_label="Lykätty kerran"
  else
    new_label="Lykätty $retry_count kertaa"
  fi

  # Add the new "Lykätty" label to the updated_labels array
  updated_labels+=("\"$new_label\"")

  # Handle recurring tasks
  recurring=$(echo "$task_data" | jq -r '.due.is_recurring')
  due_string=$(echo "$task_data" | jq -r '.due.string')

  if [ "$recurring" == "true" ]; then
    # Update task's due date and keep recurrence
    update_response=$(curl -s --request POST \
      --url "https://api.todoist.com/rest/v2/tasks/$task_id" \
      --header "Content-Type: application/json" \
      --header "Authorization: Bearer ${TODOIST_API_KEY}" \
      --data "{\"due_string\": \"$due_string\", \"due_date\": \"$next_day\", \"labels\": [$(echo ${updated_labels[@]} | sed 's/ /, /g')]}")
  else
    # Update the task's due date
    update_response=$(curl -s --request POST \
      --url "https://api.todoist.com/rest/v2/tasks/$task_id" \
      --header "Content-Type: application/json" \
      --header "Authorization: Bearer ${TODOIST_API_KEY}" \
      --data "{\"due_date\": \"$next_day\", \"labels\": [$(echo ${updated_labels[@]} | sed 's/ /, /g')]}")
  fi

  # Debug
  if [ "$DEBUG" = true ]; then
    echo -e "${BOLD}${CYAN}Task response:${RESET}\n$update_response\n"
  fi

  # If error occurs, print the error message
  if [[ "$update_response" == *"error"* ]]; then
    echo -e "${BOLD}${RED}Error while postponing task:${RESET}\n$update_response"
    exit 1
  else
    # Print the task ID and name when the task is postponed
    echo -e "${YELLOW}Task postponed: $task_name (ID: $task_id)${RESET}"
  fi
}
