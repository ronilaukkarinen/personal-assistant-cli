schedule_task() {
  local task_id="$1"
  local duration="$2"
  local datetime="$3"
  local current_day="$4"
  local backlog="$5"

  # Handle date command differences between macOS and Linux
  if [[ "$(uname)" == "Darwin" ]]; then
    date_cmd="gdate"
  else
    date_cmd="date"
  fi

  # Get existing task data
  task_data=$(curl -s --request GET \
    --url "https://api.todoist.com/rest/v2/tasks/$task_id" \
    --header "Authorization: Bearer ${TODOIST_API_KEY}")

  if [ -z "$task_data" ]; then
    echo -e "${RED}Error: Failed to fetch task data for ID $task_id${RESET}"
    return 1
  fi

  # Extract task details
  task_name=$(echo "$task_data" | jq -r '.content')
  labels=$(echo "$task_data" | jq -r '.labels | join(", ")')
  due_date=$(echo "$task_data" | jq -r '.due.date // empty')
  due_datetime=$(echo "$task_data" | jq -r '.due.datetime // empty')
  recurring=$(echo "$task_data" | jq -r '.due.is_recurring')
  due_string=$(echo "$task_data" | jq -r '.due.string // empty')

  # Skip if task already has a specific time
  if [ ! -z "$due_datetime" ]; then
    echo -e "${YELLOW}Skipping task '$task_name' as it already has a specific time set${RESET}"
    return 0
  fi

  # Build update data for tasks with only date
  update_data="{"
  should_add_comment=false

  if [ "$datetime" = "null" ]; then
    # If datetime is explicitly null, remove the due date
    update_data+="\"due_string\": \"no due date\""
  elif [ ! -z "$datetime" ] && [ "$datetime" != "undefined" ]; then
    # Handle recurring tasks differently
    if [ "$recurring" == "true" ] && [ ! -z "$due_string" ]; then
      update_data+="\"due_datetime\": \"$datetime\", \"due_string\": \"$due_string\""
    else
      update_data+="\"due_datetime\": \"$datetime\""
    fi
    should_add_comment=true
    if [ ! -z "$duration" ] && [ "$duration" != "0" ]; then
      update_data+=", \"duration\": \"$duration\", \"duration_unit\": \"minute\""
    fi
  fi

  update_data+="}"

  # Only proceed if we have updates to make
  if [ "$update_data" = "{}" ]; then
    echo -e "${YELLOW}No updates needed for task '$task_name'${RESET}"
    return 0
  fi

  # Make the API call to update the task
  response=$(curl -s --write-out "%{http_code}" --output /dev/null --request POST \
    --url "https://api.todoist.com/rest/v2/tasks/$task_id" \
    --header "Authorization: Bearer ${TODOIST_API_KEY}" \
    --header "Content-Type: application/json" \
    --data "$update_data")

  if [ "$response" -eq 204 ] || [ "$response" -eq 200 ]; then
    echo -e "${GREEN}Successfully scheduled task '$task_name'${RESET}"

    # Add comment about scheduling only if we have a valid datetime
    if [ "$should_add_comment" = true ] && [ ! -z "$datetime" ] && [ "$datetime" != "null" ] && [ "$datetime" != "undefined" ]; then
      formatted_month=$($date_cmd -d "$datetime" "+%B" | tr '[:upper:]' '[:lower:]')
      formatted_date=$($date_cmd -d "$datetime" "+%-d. ${formatted_month}ta %Y")
      formatted_time=$($date_cmd -d "$datetime" "+%H:%M")

      if [ ! -z "$duration" ] && [ "$duration" != "0" ]; then
        comment_data="{\"task_id\": $task_id, \"content\": \"🤖 Rollen tekoälyavustaja v${SCRIPT_VERSION} lykkäsi tätä tehtävää eteenpäin ajalle $formatted_date, kello $formatted_time. Tehtävän kestoksi määriteltiin $duration minuuttia.\"}"
      else
        comment_data="{\"task_id\": $task_id, \"content\": \"🤖 Rollen tekoälyavustaja v${SCRIPT_VERSION} lykkäsi tätä tehtävää eteenpäin ajalle $formatted_date, kello $formatted_time.\"}"
      fi

      comment_response=$(curl -s --request POST \
        --url "https://api.todoist.com/rest/v2/comments" \
        --header "Authorization: Bearer ${TODOIST_API_KEY}" \
        --header "Content-Type: application/json" \
        --data "$comment_data")

      if [ "$DEBUG" = true ]; then
        echo "Comment response: $comment_response"
      fi
    elif [ "$datetime" = "null" ]; then
      comment_data="{\"task_id\": $task_id, \"content\": \"🤖 Rollen tekoälyavustaja v${SCRIPT_VERSION} poisti tämän tehtävän aikataulutuksen.\"}"
      curl -s --request POST \
        --url "https://api.todoist.com/rest/v2/comments" \
        --header "Authorization: Bearer ${TODOIST_API_KEY}" \
        --header "Content-Type: application/json" \
        --data "$comment_data"
    fi
  else
    echo -e "${RED}Failed to schedule task '$task_name'. Response code: $response${RESET}"
  fi
}
