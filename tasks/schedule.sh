# Function: Schedule a task based on metadata information in the notes
schedule_task() {
  local task_id="$1"
  local note="$2"

  # Use grep to extract the Metadata line and extract the duration and datetime from it
  if [[ "$note" =~ Metadata:\ \"duration\":\ ([0-9]+),\ \"datetime\":\ \"([0-9-T:.]+)\" ]]; then
    local duration="${BASH_REMATCH[1]}"
    local datetime="${BASH_REMATCH[2]}"

    echo -e "${YELLOW}Scheduling task with ID: $task_id (Duration: $duration minutes, Datetime: $datetime)...${RESET}"

    # Fetch the current task data to preserve recurrence and labels
    task_data=$(curl -s --request GET \
      --url "https://api.todoist.com/rest/v2/tasks/$task_id" \
      --header "Authorization: Bearer ${TODOIST_API_KEY}")

    # Extract recurrence and labels
    recurring=$(echo "$task_data" | jq -r '.due.is_recurring')
    labels=$(echo "$task_data" | jq -r '.labels | join(", ")')

    # Send a POST request to Todoist API to update the task's duration, due datetime, labels, and recurrence
    update_response=$(curl -s --request POST \
      --url "https://api.todoist.com/rest/v2/tasks/$task_id" \
      --header "Authorization: Bearer ${TODOIST_API_KEY}" \
      --header "Content-Type: application/json" \
      --data '{
        "due_datetime": "'"$datetime"'",
        "duration": {
          "amount": '"$duration"',
          "unit": "minute"
        },
        "labels": ['"$labels"'],
        "is_recurring": '"$recurring"'
      }')

    # Check if there was an error during the update
    if echo "$update_response" | grep -q '"error"'; then
      echo -e "${RED}Error scheduling task with ID $task_id: $update_response${RESET}"
    else
      echo -e "${GREEN}Task with ID $task_id successfully scheduled.${RESET}"
    fi
  else
    echo -e "${RED}Error: Metadata not found for task $task_id${RESET}"
  fi
}
