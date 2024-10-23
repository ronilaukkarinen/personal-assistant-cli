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
    grep_command="ggrep"
  else
    current_time=$(date "+%H:%M")
    grep_command="grep"
  fi

  # Log file paths
  log_file_work="$HOME/Documents/Brain dump/Todoist/Todo.md"
  log_file_personal="$HOME/Documents/Brain dump/Todoist/Kotiasiat.md"
  log_file_watchlist="$HOME/Documents/Brain dump/Todoist/Watchlist.md"

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
    # Function to mark task as completed in Todoist
    mark_task_completed() {
      task_id=$1
      due_string=$2
      # Update task in Todoist as completed
      curl -s --request POST \
        --url "https://api.todoist.com/sync/v9/sync" \
        --header "Authorization: Bearer ${TODOIST_API_KEY}" \
        --header "Content-Type: application/json" \
        --data "{\"commands\":[{\"type\":\"item_close\",\"uuid\":\"$(uuidgen)\",\"args\":{\"id\":$task_id}}]}"
      echo "Task $task_id marked as completed in Todoist."

      # If recurring task, restore due string
      if [ ! -z "$due_string" ]; then
        curl -s --request POST \
          --url "https://api.todoist.com/rest/v2/tasks/$task_id" \
          --header "Authorization: Bearer ${TODOIST_API_KEY}" \
          --header "Content-Type: application/json" \
          --data "{\"due_string\": \"$due_string\"}"
        echo "Restored due string for recurring task $task_id: $due_string"
      fi
    }

    # Sync completed tasks before writing files
    sync_completed_tasks() {
      file=$1
      if [ -f "$file" ]; then
        $grep_command -P "^- \[X\] " "$file" | while read -r line; do
          task_id=$(echo "$line" | $grep_command -oP '(?<=https://todoist.com/showTask?id=)\d+')
          due_string=$(echo "$tasks" | jq -r --arg task_id "$task_id" '.[] | select(.id == ($task_id | tonumber)) | .due.string')
          mark_task_completed "$task_id" "$due_string"
        done
      fi
    }

    # Sync completed tasks for work, personal, and watchlist
    sync_completed_tasks "$log_file_work"
    sync_completed_tasks "$log_file_personal"
    sync_completed_tasks "$log_file_watchlist"

    # Now generate the new lists after syncing
    work_tasks=$(echo "$tasks" | jq -r --argjson project_map "$project_map" '
      .[] | select($project_map[.project_id | tostring] == "Todo") |
      "- [ ] \(.content | sub(" @.*"; "") ) (Due: \(.due.date // "No due date"))\(.url | " ([Katso tehtävä](\(.)))")"
    ')

    personal_tasks=$(echo "$tasks" | jq -r --argjson project_map "$project_map" '
      .[] | select($project_map[.project_id | tostring] == "Kotiasiat") |
      "- [ ] \(.content | sub(" @.*"; "") ) (Due: \(.due.date // "No due date"))\(.url | " ([Katso tehtävä](\(.)))")"
    ')

    watchlist_tasks=$(echo "$tasks" | jq -r '
      .[] | select(.labels | index("Watchlist")) |
      "- [ ] \(.content | sub(" @.*"; "") ) (Due: \(.due.date // "No due date"))\(.url | " ([Katso tehtävä](\(.)))")"
    ')

    # Count tasks
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

    # Add header and task count to the Watchlist tasks log file
    echo -e "# Watchlist\n\nYhteensä $watchlist_task_count $watchlist_task_label Todoistissa. Lista päivitetty viimeksi $today kello $current_time.\n\n$watchlist_tasks" > "$log_file_watchlist"
    echo "Watchlist tasks saved to $log_file_watchlist"

    echo "Sync complete."
  else
    echo "Error: Invalid JSON response or no tasks."
    echo "Raw API Response: $tasks"
  fi
}

# Run the function
todoist_backup_and_sync
