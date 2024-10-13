# Function: Fetch today's tasks from Todoist, excluding subtasks but calculating subtask count
fetch_tasks() {
  local start_day="$1"
  local days_to_process="$2"
  
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

  for i in $(seq 0 $((days_to_process-1))); do
    current_day=$(date -d "$start_day + $i days" +%Y-%m-%d)
    echo -e "${BOLD}${YELLOW}Fetching tasks for: $current_day...${RESET}"

    # Add the calculated subtask count to each task using `jq` concatenation
    echo "$tasks" | jq -r --arg current_day "$current_day" --argjson project_map "$project_map" --argjson subtask_counts "$subtask_counts" --arg selected_project "$SELECTED_PROJECT" '
      .[] | select(.due.date == $current_day) |
      select(.parent_id == null) |
      .project_name = ($project_map[.project_id | tostring] // "Muu projekti") |
      .project_name = (if .project_name == "Todo" then "Työasiat" else .project_name end) |
      select(
        ($selected_project == "") or
        (.project_name == $selected_project or ($selected_project == "Työasiat"))
      ) |
      .subtask_count = ($subtask_counts[.id] // 0) |
      "- ID: \(.id) - \(.content) (\(.project_name))" +
      (if (.labels | length > 0) then " (Labels: " + (.labels | join(", ")) + ")" else "" end) +
      " (Alatehtäviä: \(.subtask_count))"
    '
  done
}
