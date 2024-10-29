# Function: Fetch tasks from Todoist for a range of days, excluding subtasks but calculating subtask count
fetch_tasks() {
  local start_day="$1"
  local days_to_process="$2"

  # Fetch tasks from Todoist API
  tasks=$(curl -s --request GET \
    --url "https://api.todoist.com/rest/v2/tasks" \
    --header "Authorization: Bearer ${TODOIST_API_KEY}")

  # Fetch projects from Todoist API
  projects=$(curl -s --request GET \
    --url "https://api.todoist.com/rest/v2/projects" \
    --header "Authorization: Bearer ${TODOIST_API_KEY}")

  # Create a map of project_id -> project_name
  project_map=$(echo "$projects" | jq -r 'map({(.id | tostring): .name}) | add')

  # Count the number of subtasks for each task in Bash
  subtask_counts=$(echo "$tasks" | jq -r '[.[] | select(.parent_id != null) | .parent_id] | group_by(.) | map({(.[0]): length}) | add')

  # Loop through the days to process
  for i in $(seq 0 $((days_to_process - 1))); do

    # Calculate current day
    if [[ "$(uname)" == "Darwin" ]]; then
      current_day=$(gdate -d "$start_day + $i days" "+%Y-%m-%d")
    else
      current_day=$(date -d "$start_day + $i days" "+%Y-%m-%d")
    fi

    echo -e "${BOLD}${YELLOW}Fetching tasks for: $current_day...${RESET}"

    # Initialize the counter
    counter=1

    # Process each task and format it with the counter for a numbered list
    day_tasks=""
    while IFS= read -r line; do
      # Add the counter to each task
      day_tasks+="$counter. $line\n"
      # Increment the counter
      counter=$((counter + 1))
    done < <(echo "$tasks" | jq -r --arg current_day "$current_day" --argjson project_map "$project_map" --argjson subtask_counts "$subtask_counts" '
      .[] |
      select(.due.date <= $current_day) |
      select(.parent_id == null) |
      select((.labels | index("Google-kalenterin tapahtuma") | not) and (.labels | index("Nobot") | not)) |
      .project_name = ($project_map[.project_id | tostring] // "Muu projekti") |
      .project_name = (if .project_name == "Todo" then "Työasiat" else .project_name end) |
      .subtask_count = ($subtask_counts[.id] // 0) |
      "\(.content) (\(.project_name))" +
      (if (.labels | length > 0) then " (\(.labels | join(", ")))" else "" end) +
      (if (.subtask_count > 0) then " (Alatehtäviä: \(.subtask_count))" else "" end) +
      " (Metadata: id: \"\(.id)\", priority: \"\(.priority // "none")\", duration: \"\(.duration.amount // "undefined")\", datetime: \"\(.due.datetime // "undefined")\")"
    ')
  done

  # Export tasks to be scheduled to a variable used later in other script
  export TASKS_TO_SCHEDULE="$tasks"

  # Print tasks
  echo -e "${BOLD}${GREEN}Tasks fetched:${RESET}\n$day_tasks"

  # Debug
  if [ "$DEBUG" = true ]; then
    echo -e "${BOLD}${CYAN}Tasks:\n$day_tasks${RESET}"
  fi

  # Clear text version
  TASKS_TO_BE_SCHEDULED=""

  # Process each task and format it as a Todoist markdown link
  while IFS= read -r line; do
    # Extract task name and ID for link creation
    task_name=$(echo "$line" | jq -r '.content')
    task_id=$(echo "$line" | jq -r '.id')

    # Format each task with a link
    TASKS_TO_BE_SCHEDULED+="- [ ] [$task_name](https://app.todoist.com/showTask?id=$task_id)\n"
  done < <(echo "$tasks" | jq -c --arg current_day "$current_day" --argjson project_map "$project_map" --argjson subtask_counts "$subtask_counts" '
    .[] |
    select(.due.date <= $current_day) |
    select(.parent_id == null) |
    select((.labels | index("Google-kalenterin tapahtuma") | not) and (.labels | index("Nobot") | not)) |
    .project_name = ($project_map[.project_id | tostring] // "Muu projekti") |
    {content: .content, id: .id}
  ')

  # Export variable to be used in other part of the program
  export TASKS_TO_BE_SCHEDULED
}
