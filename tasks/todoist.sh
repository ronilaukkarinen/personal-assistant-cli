# Function: Fetch today's tasks from Todoist, including project names and subtask count
fetch_tasks() {
  local today
  today=$(date +%Y-%m-%d)  # Get today's date in YYYY-MM-DD format

  # Fetch tasks from Todoist API
  tasks=$(curl -s --request GET \
    --url "https://api.todoist.com/rest/v2/tasks" \
    --header "Authorization: Bearer ${TODOIST_API_KEY}")

  # Fetch projects from Todoist API
  projects=$(curl -s --request GET \
    --url "https://api.todoist.com/rest/v2/projects" \
    --header "Authorization: Bearer ${TODOIST_API_KEY}")

  # Create a map of project_id -> project_name
  project_map=$(echo "$projects" | jq -r 'map({( .id | tostring ): .name}) | add')

  # Count the number of subtasks for each task in Bash
  # Get all parent_ids and count how many times each id appears as a parent_id
  subtask_counts=$(echo "$tasks" | jq -r '[.[] | select(.parent_id != null) | .parent_id] | group_by(.) | map({(.[0]): length}) | add')

  # Add the calculated subtask count to each task using `jq` concatenation
  echo "$tasks" | jq -r --arg today "$today" --argjson project_map "$project_map" --argjson subtask_counts "$subtask_counts" --arg selected_project "$SELECTED_PROJECT" '
    .[] | select(.due.date <= $today) |
    .project_name = ($project_map[.project_id | tostring] // "Muu projekti") |
    # Change "Todo" project name to "Työasiat"
    .project_name = (if .project_name == "Todo" then "Työasiat" else .project_name end) |
    # Filter based on selected project if provided (original project name)
    select(
      ($selected_project == "") or
      (.project_name == $selected_project or ($selected_project == "Todo" and .project_name == "Työasiat"))
    ) |
    # Assign pre-calculated subtask count
    .subtask_count = ($subtask_counts[.id] // 0) |
    "- ID: " + .id + " - " + .content + " (" + .project_name + ")" +
      (if .labels | length > 0 then " (Labels: " + (.labels | join(", ")) + ")" else "" end) +
      " (Alatehtäviä: \(.subtask_count))"'
}
