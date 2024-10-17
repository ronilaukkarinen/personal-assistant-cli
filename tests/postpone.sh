#!/bin/bash
source ../.env

# Tester function to postpone task directly
test_postpone_task() {
  local task_id="8489972326" # Testing with this ID
  local current_day=$(date +%Y-%m-%d) # Use today's date

  # Call the postpone_task function
  postpone_task "$task_id" "$current_day"
}

# Postpone task function
postpone_task() {
  local task_id="$1"
  local current_day="$2"
  local next_day

  # Calculate the next day based on the current day
  next_day=$(date -d "$current_day + 1 day" "+%Y-%m-%d")

  # Get existing labels and task name for the task
  task_data=$(curl -s --request GET \
    --url "https://api.todoist.com/rest/v2/tasks/$task_id" \
    --header "Authorization: Bearer ${TODOIST_API_KEY}")
  task_name=$(echo "$task_data" | jq -r '.content')
  labels=$(echo "$task_data" | jq -r '.labels')

  # Debugging output to see the current task status
  echo "Current task data:"
  echo "Task name: $task_name, Labels: $labels"

  # Check if task has a label with name "Google-kalenterin tapahtuma"
  if echo "$task_data" | jq -r '.labels[]' | grep -q "Google-kalenterin tapahtuma"; then
    echo -e "${YELLOW}Skipping postponing task, because it has the calendar label: $task_name (ID: $task_id)${RESET}"
    return 0
  fi

  # Handle label updates for "Lykätty"
  retry_count=1
  updated_labels=()

  # Iterate over labels and handle the "Lykätty" label separately
  for label in $(echo "$labels" | jq -r '.[]'); do
    if [[ "$label" =~ "Lykätty" ]]; then
      # Extract current retry count from "Lykätty"
      retry_count=$(echo "$label" | grep -oP '\d+' || echo "1")
      retry_count=$((retry_count + 1))
    else
      # Add non-"Lykätty" labels to updated_labels array
      updated_labels+=("\"$label\"")
    fi
  done

  # Set the correct "Lykätty" label
  if [ "$retry_count" -eq 1 ]; then
    new_label="Lykätty kerran"
  else
    new_label="Lykätty $retry_count kertaa"
  fi
  updated_labels+=("\"$new_label\"")

  # Convert updated_labels array into JSON array format
  updated_labels_str=$(printf '%s, ' "${updated_labels[@]}")
  updated_labels_str="[${updated_labels_str%, }]"

  # Handle recurring tasks
  recurring=$(echo "$task_data" | jq -r '.due.is_recurring')
  due_string=$(echo "$task_data" | jq -r '.due.string')

  if [ "$recurring" == "true" ]; then
    # Update task's due date and keep recurrence
    update_response=$(curl -s --request POST \
      --url "https://api.todoist.com/rest/v2/tasks/$task_id" \
      --header "Content-Type: application/json" \
      --header "Authorization: Bearer ${TODOIST_API_KEY}" \
      --data "{\"due_string\": \"$due_string\", \"due_date\": \"$next_day\", \"labels\": $updated_labels_str}")
  else
    # Update the task's due date
    update_response=$(curl -s --request POST \
      --url "https://api.todoist.com/rest/v2/tasks/$task_id" \
      --header "Content-Type: application/json" \
      --header "Authorization: Bearer ${TODOIST_API_KEY}" \
      --data "{\"due_date\": \"$next_day\", \"labels\": $updated_labels_str}")
  fi

  # Check if there was an error during the update
  if echo "$update_response" | grep -q '"error"'; then
    echo -e "${RED}Error postponing task with ID $task_id: $update_response${RESET}"
  else
    echo -e "${GREEN}Task with ID $task_id successfully postponed.${RESET}"
    echo -e "Update response:\n$update_response"
  fi
}

# Test the function with provided task ID and current day
test_postpone_task
