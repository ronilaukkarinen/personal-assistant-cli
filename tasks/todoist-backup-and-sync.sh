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
  if [[ "$(uname)" == "Darwin" ]]; then
    today=$(date "%-d.%-m.%Y")
  else
    day=$(date "+%d" | sed 's/^0//')
    month=$(date "+%m" | sed 's/^0//')
    today="${day}.${month}.$(date "+%Y")"
  fi

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
  debug_log="/tmp/todoist-debug.log"
  error_log="/tmp/todoist-error.log"

  # Clear previous logs
  echo "Starting sync..." > "$debug_log"
  echo "Starting sync..." > "$error_log"

  # Function to mark task as completed in Todoist
  mark_task_completed() {
    task_id=$1
    due_string=$2
    echo "Processing task ID: $task_id" | tee -a "$debug_log"

    # Ensure task_id is not empty
    if [ -z "$task_id" ]; then
      echo "Error: task_id is empty. Skipping task." | tee -a "$error_log"
      return
    fi

    # Use /tasks/close to close the task in Todoist
    response=$(curl -s --write-out "%{http_code}" --output /dev/null --request POST \
      --url "https://api.todoist.com/rest/v2/tasks/$task_id/close" \
      --header "Authorization: Bearer ${TODOIST_API_KEY}" \
      --header "Content-Type: application/json")

    # Check for errors
    if [ "$response" -ne 204 ]; then
      echo "Error closing task $task_id. HTTP Response: $response" | tee -a "$error_log"
    else
      echo "Task $task_id closed successfully. HTTP Response: $response" | tee -a "$debug_log"
    fi

    # If recurring task, restore due string
    if [ ! -z "$due_string" ]; then
      echo "Restoring due string for task ID: $task_id" | tee -a "$debug_log"
      response=$(curl -s --write-out "%{http_code}" --output /dev/null --request POST \
        --url "https://api.todoist.com/rest/v2/tasks/$task_id" \
        --header "Authorization: Bearer ${TODOIST_API_KEY}" \
        --header "Content-Type: application/json" \
        --data "{\"due_string\": \"$due_string\"}")

      # Check for errors in due_string restoration
      if [ "$response" -ne 204 ]; then
        echo "Error restoring due_string for task $task_id. HTTP Response: $response" | tee -a "$error_log"
      else
        echo "Due string for task $task_id restored successfully. HTTP Response: $response" | tee -a "$debug_log"
      fi
    fi
  }

  # Sync completed tasks before fetching from Todoist
  sync_completed_tasks() {
    file=$1
    if [ -f "$file" ]; then
      echo "Syncing completed tasks from $file" | tee -a "$debug_log"
      # Search for both - [x] and - [X] tasks and extract task_id from URL
      $grep_command -P "^- \[[xX]\] " "$file" | while read -r line; do
        echo "Line found: $line" | tee -a "$debug_log"
        task_id=$(echo "$line" | $grep_command -oP '(?<=https://app.todoist.com/app/task/)\d+')
        echo "Task ID extracted: $task_id" | tee -a "$debug_log"

        # Fetch the due_string from Todoist API
        due_string=$(curl -s --request GET \
          --url "https://api.todoist.com/rest/v2/tasks/$task_id" \
          --header "Authorization: Bearer ${TODOIST_API_KEY}" \
          | jq -r '.due.string')
        echo "Due string: $due_string" | tee -a "$debug_log"

        mark_task_completed "$task_id" "$due_string"
      done
    else
      echo "File $file not found." | tee -a "$debug_log"
    fi
  }

  # Sync completed tasks for work, personal, and watchlist
  sync_completed_tasks "$log_file_work"
  sync_completed_tasks "$log_file_personal"
  sync_completed_tasks "$log_file_watchlist"

  # Now fetch from Todoist API and update logs
  echo "Fetching tasks from Todoist..." | tee -a "$debug_log"
  tasks=$(curl -s --request GET \
    --url "https://api.todoist.com/rest/v2/tasks" \
    --header "Authorization: Bearer ${TODOIST_API_KEY}")

  if [ -z "$tasks" ]; then
    echo "Error: No tasks fetched." | tee -a "$debug_log"
    exit 1
  fi

  echo "Tasks fetched:" | tee -a "$debug_log"
  echo "$tasks" >> "$debug_log"

  # Fetch all projects from Todoist API to get project names and IDs
  projects=$(curl -s --request GET \
    --url "https://api.todoist.com/rest/v2/projects" \
    --header "Authorization: Bearer ${TODOIST_API_KEY}")

  # Map of project ID to project name
  project_map=$(echo "$projects" | jq -r 'map({(.id | tostring): .name}) | add')

  # Now generate the new lists after syncing
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
  echo "Work tasks saved to $log_file_work" | tee -a "$debug_log"

  # Add header and task count to the personal tasks log file
  echo -e "# Kotiasiat\n\nYhteensä $personal_task_count $personal_task_label Todoistissa. Lista päivitetty viimeksi $today kello $current_time.\n\n$personal_tasks" > "$log_file_personal"
  echo "Personal tasks saved to $log_file_personal" | tee -a "$debug_log"

  # Add header and task count to the Watchlist tasks log file
  echo -e "# Watchlist\n\nYhteensä $watchlist_task_count $watchlist_task_label Todoistissa. Lista päivitetty viimeksi $today kello $current_time.\n\n$watchlist_tasks" > "$log_file_watchlist"
  echo "Watchlist tasks saved to $log_file_watchlist" | tee -a "$debug_log"

  echo "Sync complete." | tee -a "$debug_log"
}

# Run the function
todoist_backup_and_sync
