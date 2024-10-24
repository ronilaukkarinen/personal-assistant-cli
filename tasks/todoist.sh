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

    # Filter and format tasks for the current day
    day_tasks=$(echo "$tasks" | jq -r --arg current_day "$current_day" --argjson project_map "$project_map" --argjson subtask_counts "$subtask_counts" '
      .[] | select(.due.date <= $current_day) |
      select(.parent_id == null) |
      .project_name = ($project_map[.project_id | tostring] // "Muu projekti") |
      .project_name = (if .project_name == "Todo" then "Työasiat" else .project_name end) |
      .subtask_count = ($subtask_counts[.id] // 0) |
      "- ID: \(.id) - \(.content) (\(.project_name))" +
      (if (.labels | length > 0) then " (Labels: " + (.labels | join(", ")) + ")" else "" end) +
      " (Alatehtäviä: \(.subtask_count))" +
      (if (.duration != null and .duration.amount != null) then " (Ennalta määritetty kesto: \(.duration.amount) \(.duration.unit))" else "" end) +
      (if (.due.datetime != null) then " (Ennalta määritetty ajankohta: \(.due.datetime))" else "" end)
    ')
  done

  # Print tasks
  echo -e "${BOLD}${GREEN}Tasks fetched:${RESET}\n$day_tasks"

  # Debug
  if [ "$DEBUG" = true ]; then
    echo -e "${BOLD}${CYAN}Tasks:\n$day_tasks${RESET}"
  fi
}
