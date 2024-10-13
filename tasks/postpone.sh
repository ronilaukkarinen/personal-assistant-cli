postpone_task() {
  local task_id="$1"
  local next_day
  next_day=$(date -d "tomorrow" +%Y-%m-%d)  # Calculate next day date

  # Get existing labels and task name for the task
  task_data=$(curl -s --request GET \
    --url "https://api.todoist.com/rest/v2/tasks/$task_id" \
    --header "Authorization: Bearer ${TODOIST_API_KEY}")
  task_name=$(echo "$task_data" | jq -r '.content')

  # If task is recurring
  if [[ "$task_data" == *"recurring"* ]]; then
    # Get current due_string for recurring tasks
    current_due_string=$(echo "$task_data" | jq -r '.due_string')

    # Update task's due date and keep recurrence
    update_response=$(curl -s --request POST \
      --url "https://api.todoist.com/rest/v2/tasks/$task_id" \
      --header "Content-Type: application/json" \
      --header "Authorization: Bearer ${TODOIST_API_KEY}" \
      --data "{\"due_string\": \"$current_due_string\", \"due_date\": \"$next_day\"}")
  else
    # Update the task's due date
    update_response=$(curl -s --request POST \
      --url "https://api.todoist.com/rest/v2/tasks/$task_id" \
      --header "Content-Type: application/json" \
      --header "Authorization: Bearer ${TODOIST_API_KEY}" \
      --data "{\"due_date\": \"$next_day\"}")
  fi

  # Debug
  if [ "$DEBUG" = true ]; then
    echo -e "${BOLD}${CYAN}Task reponse:${RESET}\n$update_response\n"
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
