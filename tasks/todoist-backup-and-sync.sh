#!/bin/bash
# Function: Backup Todoist tasks (work, personal, and watchlist) to Obsidian
# and mark tasks as completed if marked as done in Markdown files.
todoist_backup_and_sync() {
  # Get absolute path of the script
  script_path=$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)

  # Eliminate possible /tasks from the path
  script_path=${script_path%/tasks}

  # Get .env
  source "$script_path/.env"

  # Use Finnish locale for the date
  export LC_TIME=fi_FI.UTF-8

  # Date of today
  today=$(date "+%d.%m.%Y")

  # Check if macOS is used
  if [[ "$(uname)" == "Darwin" ]]; then
    current_time=$(gdate "+%H:%M")
  else
    current_time=$(date "+%H:%M")
  fi

  # Log file paths
  log_file_work="$HOME/Documents/Brain dump/Todoist/Todo.md"
  log_file_personal="$HOME/Documents/Brain dump/Todoist/Kotiasiat.md"
  log_file_watchlist="$HOME/Documents/Brain dump/Todoist/Watchlist.md"
  debug_log="/tmp/todoist-debug.log"
  error_log="/tmp/todoist-error.log"

  # Clear previous logs
  echo "Starting sync..." > "$debug_log"
  echo "Starting sync..." > "$error_log"

  # Fetch active tasks from Todoist API
  tasks=$(curl -s --request GET \
    --url "https://api.todoist.com/rest/v2/tasks" \
    --header "Authorization: Bearer ${TODOIST_API_KEY}")

  # Fetch all projects from Todoist API to get project names and IDs
  projects=$(curl -s --request GET \
    --url "https://api.todoist.com/rest/v2/projects" \
    --header "Authorization: Bearer ${TODOIST_API_KEY}")

  # Map of project ID to project name
  project_map=$(echo "$projects" | jq -r 'map({(.id | tostring): .name}) | add')

  # Check if the response is valid JSON
  if echo "$tasks" | jq empty 2>/dev/null; then
    # Extract work tasks (by project name matching "Todo")
    work_tasks=$(echo "$tasks" | jq -r --argjson project_map "$project_map" '
      .[] | select($project_map[.project_id | tostring] == "Todo") |
      {id: .id, content: .content, parent_id: .parent_id, labels: .labels, due: .due, url: .url} |
      if .parent_id == null then
        "- [ ] \(.content | sub(" @.*"; "") )" +
        (if .due.date then " (Aikataulutettu: \(.due.date))" else "" end) +
        "\(.url | " ([Katso tehtävä](\(.)))")" +
        (if (.labels | length > 0) then " (\(.labels | join(", ")))" else "" end)
      else
        "    - [ ] \(.content | sub(" @.*"; "") )" +
        (if .due.date then " (Aikataulutettu: \(.due.date))" else "" end) +
        "\(.url | " ([Katso tehtävä](\(.)))")" +
        (if (.labels | length > 0) then " (\(.labels | join(", ")))" else "" end)
      end
    ')

    # Extract personal tasks (by project name matching "Kotiasiat")
    personal_tasks=$(echo "$tasks" | jq -r --argjson project_map "$project_map" '
      .[] | select($project_map[.project_id | tostring] == "Kotiasiat") |
      {id: .id, content: .content, parent_id: .parent_id, labels: .labels, due: .due, url: .url} |
      if .parent_id == null then
        "- [ ] \(.content | sub(" @.*"; "") )" +
        (if .due.date then " (Aikataulutettu: \(.due.date))" else "" end) +
        "\(.url | " ([Katso tehtävä](\(.)))")" +
        (if (.labels | length > 0) then " (\(.labels | join(", ")))" else "" end)
      else
        "    - [ ] \(.content | sub(" @.*"; "") )" +
        (if .due.date then " (Aikataulutettu: \(.due.date))" else "" end) +
        "\(.url | " ([Katso tehtävä](\(.)))")" +
        (if (.labels | length > 0) then " (\(.labels | join(", ")))" else "" end)
      end
    ')

    # Extract watchlist tasks
    watchlist_tasks=$(echo "$tasks" | jq -r '
      .[] | select(.labels | index("Watchlist")) |
      {id: .id, content: .content, parent_id: .parent_id, labels: .labels, due: .due, url: .url} |
      if .parent_id == null then
        "- [ ] \(.content | sub(" @.*"; "") )" +
        (if .due.date then " (Aikataulutettu: \(.due.date))" else "" end) +
        "\(.url | " ([Katso tehtävä](\(.)))")" +
        (if (.labels | length > 0) then " (\(.labels | join(", ")))" else "" end)
      else
        "    - [ ] \(.content | sub(" @.*"; "") )" +
        (if .due.date then " (Aikataulutettu: \(.due.date))" else "" end) +
        "\(.url | " ([Katso tehtävä](\(.)))")" +
        (if (.labels | length > 0) then " (\(.labels | join(", ")))" else "" end)
      end
    ')

    # Count the number of tasks
    work_task_count=$(echo "$tasks" | jq --argjson project_map "$project_map" '[.[] | select($project_map[.project_id | tostring] == "Todo")] | length')
    personal_task_count=$(echo "$tasks" | jq --argjson project_map "$project_map" '[.[] | select($project_map[.project_id | tostring] == "Kotiasiat")] | length')
    watchlist_task_count=$(echo "$tasks" | jq '[.[] | select(.labels | index("Watchlist"))] | length')

    # If $task_count is 1, print "tehtävä", otherwise print "tehtävää"
    if [ "$work_task_count" -eq 1 ]; then
      work_task_label="tehtävä"
    else
      work_task_label="tehtävää"
    fi

    if [ "$personal_task_count" -eq 1 ]; then
      personal_task_label="tehtävä"
    else
      personal_task_label="tehtävää"
    fi

    if [ "$watchlist_task_count" -eq 1 ]; then
      watchlist_task_label="tehtävä"
    else
      watchlist_task_label="tehtävää"
    fi

    # Add header and task count to the work tasks log file
    echo -e "# Työasiat\n\nYhteensä $work_task_count $work_task_label Todoistissa. Lista päivitetty viimeksi $today kello $current_time.\n\n$work_tasks" > "$log_file_work"
    echo "Work tasks saved to $log_file_work"

    # Add header and task count to the personal tasks log file
    echo -e "# Kotiasiat\n\nYhteensä $personal_task_count $personal_task_label Todoistissa. Lista päivitetty viimeksi $today kello $current_time.\n\n$personal_tasks" > "$log_file_personal"
    echo "Personal tasks saved to $log_file_personal"

    # Add header and task count to the watchlist tasks log file
    echo -e "# Watchlist\n\nYhteensä $watchlist_task_count $watchlist_task_label Todoistissa. Lista päivitetty viimeksi $today kello $current_time.\n\n$watchlist_tasks" > "$log_file_watchlist"
    echo "Watchlist tasks saved to $log_file_watchlist"

    echo "Sync complete." | tee -a "$debug_log"

  else
    echo "Error: Invalid JSON response or no tasks."
    echo "Raw API Response: $tasks"
  fi
}

# Run the function
todoist_backup_and_sync
