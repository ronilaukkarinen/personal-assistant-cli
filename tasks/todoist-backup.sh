#!/bin/bash
# Function: Backup Todoist tasks (work and personal) to Obsidian
todoist_backup() {
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
      "- [ ] \(.content | sub(" @.*"; "") ) (Labels: \(.labels | join(", ")))"
    ')

    # Extract personal tasks (by project name matching "Kotiasiat")
    personal_tasks=$(echo "$tasks" | jq -r --argjson project_map "$project_map" '
      .[] | select($project_map[.project_id | tostring] == "Kotiasiat") |
      "- [ ] \(.content | sub(" @.*"; "") ) (Labels: \(.labels | join(", ")))"
    ')

    # Count the number of work tasks
    work_task_count=$(echo "$tasks" | jq --argjson project_map "$project_map" '[.[] | select($project_map[.project_id | tostring] == "Todo")] | length')

    # Count the number of personal tasks
    personal_task_count=$(echo "$tasks" | jq --argjson project_map "$project_map" '[.[] | select($project_map[.project_id | tostring] == "Kotiasiat")] | length')

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

    # Add header and task count to the work tasks log file
    echo -e "# Työasiat\n\nYhteensä $work_task_count $work_task_label Todoistissa. Lista päivitetty viimeksi $today kello $current_time.\n\n$work_tasks" > "$log_file_work"
    echo "Work tasks saved to $log_file_work"

    # Add header and task count to the personal tasks log file
    echo -e "# Kotiasiat\n\nYhteensä $personal_task_count $personal_task_label Todoistissa. Lista päivitetty viimeksi $today kello $current_time.\n\n$personal_tasks" > "$log_file_personal"
    echo "Personal tasks saved to $log_file_personal"

    # Debug
    echo ""
    echo "Work tasks:"
    echo "$work_tasks"
    echo ""
    echo "Personal tasks:"
    echo "$personal_tasks"
  else
    echo "Error: Invalid JSON response or no tasks."
    echo "Raw API Response: $tasks"
  fi
}

# Run the function
todoist_backup
