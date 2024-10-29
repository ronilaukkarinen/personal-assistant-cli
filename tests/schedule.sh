#!/bin/bash
source ../.env

# Colors
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[0;33m'
CYAN='\033[0;36m'
RESET='\033[0m'

# Todoist API Key (replace with your own key)
export TODOIST_API_KEY=${TODOIST_API_KEY}

# Tester function to schedule task directly
test_schedule_task() {
  local task_id="8538172256" # Testing with this ID
  local duration="60" # Set duration for 60 minutes
  local datetime="2024-10-29T22:30:00" # Set test datetime
  local current_day=$(date +%Y-%m-%d) # Use today's date

  # Call the schedule_task function
  schedule_task "$task_id" "$duration" "$datetime" "$current_day"
}

# Function: Schedule a task based on passed duration and datetime
schedule_task() {
  local task_id="$1"
  local duration="$2"
  local datetime="$3"
  local current_day="$4"

  # Calculate the next day based on the current day
  if [[ "$(uname)" == "Darwin" ]]; then
    next_day=$(gdate -d "$current_day + 1 day" "+%Y-%m-%d")
  else
    next_day=$(date -d "$current_day + 1 day" "+%Y-%m-%d")
  fi

  # Check if duration and datetime are set
  if [[ -z "$duration" || -z "$datetime" ]]; then
    echo -e "${RED}Error: Missing duration or datetime for task ID $task_id${RESET}"
    return
  fi

  echo -e "${YELLOW}Scheduling task with ID: $task_id (Duration: $duration minutes, Datetime: $datetime)...${RESET}"

  # Get existing labels and task name for the task
  task_data=$(curl -s --request GET \
    --url "https://api.todoist.com/rest/v2/tasks/$task_id" \
    --header "Authorization: Bearer ${TODOIST_API_KEY}")
  task_name=$(echo "$task_data" | jq -r '.content')
  labels=$(echo "$task_data" | jq -r '.labels | join(", ")')

  # Get task duration, handle cases where duration is null or missing
  task_duration=$(echo "$task_data" | jq -r '.duration.amount // empty')

  # Check if task has a label with name "Google-kalenterin tapahtuma"
  if echo "$task_data" | jq -r '.labels[]' | grep -q "Google-kalenterin tapahtuma"; then
    echo -e "${YELLOW}Skipping postponing task, because it has the calendar label: $task_name (ID: $task_id)${RESET}"
    return 0
  fi

  # Handle recurring tasks
  recurring=$(echo "$task_data" | jq -r '.due.is_recurring')
  due_string=$(echo "$task_data" | jq -r '.due.string')

  # Debugging output to check the variables, add cyan to the values
  echo -e "Task name: ${CYAN}$(echo "$task_data" | jq -r '.content')${RESET}, Task ID: ${CYAN}$task_id${RESET}, Duration: ${CYAN}$duration${RESET}, Datetime: ${CYAN}$datetime${RESET}, Recurring: ${CYAN}$recurring${RESET}, Labels: ${CYAN}$labels${RESET}"

  # Update the task
  if [ "$recurring" == "true" ]; then
    update_response=$(curl -s --request POST \
      --url "https://api.todoist.com/rest/v2/tasks/$task_id" \
      --header "Content-Type: application/json" \
      --header "Authorization: Bearer ${TODOIST_API_KEY}" \
      --data "{\"due_datetime\": \"$datetime\", \"due_string\": \"$due_string\", \"duration\": \"$duration\", \"duration_unit\": \"minute\"}")
  else
    update_response=$(curl -s --request POST \
      --url "https://api.todoist.com/rest/v2/tasks/$task_id" \
      --header "Content-Type: application/json" \
      --header "Authorization: Bearer ${TODOIST_API_KEY}" \
      --data "{\"due_datetime\": \"$datetime\", \"duration\": \"$duration\", \"duration_unit\": \"minute\"}")
  fi

  # Check if there was an error during the update
  if echo "$update_response" | grep -q '"error"'; then
    echo -e "${RED}Error scheduling task with ID $task_id: $update_response${RESET}"
  else
    echo -e "${GREEN}Task with ID $task_id successfully scheduled.${RESET}"
  fi

  # Debug output
  echo -e "${CYAN}Update response:${RESET}\n$update_response\n"
}

# Run the tester
test_schedule_task
