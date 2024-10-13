postpone_task() {
  local task_id="$1"
  local next_day
  next_day=$(date -d "tomorrow" +%Y-%m-%d)  # Calculate next day date

  # Get existing labels and task name for the task
  task_data=$(curl -s --request GET \
    --url "https://api.todoist.com/rest/v2/tasks/$task_id" \
    --header "Authorization: Bearer ${TODOIST_API_KEY}")
  task_name=$(echo "$task_data" | jq -r '.content')

  # Update the task's due date
  update_response=$(curl -s --request POST \
    --url "https://api.todoist.com/rest/v2/tasks/$task_id" \
    --header "Content-Type: application/json" \
    --header "Authorization: Bearer ${TODOIST_API_KEY}" \
    --data "{\"due_date\": \"$next_day\"}")

  # Debug
  if [ "$DEBUG" = true ]; then
    echo -e "${BOLD}${CYAN}Tehtävän päivitysvastaus:${RESET}\n$update_response\n"
  fi

  # If error occurs, print the error message
  if [[ "$update_response" == *"error"* ]]; then
    echo -e "${BOLD}${RED}Virhe: Tehtävän siirtäminen seuraavalle päivälle epäonnistui.${RESET}"
    exit 1
  else
    # Print the task ID and name when the task is postponed
    echo -e "${YELLOW}Tehtävä siirretty: $task_name (ID: $task_id)${RESET}"
  fi
}
