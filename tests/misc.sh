#!/bin/bash
# Tester function for Todoist

# Get absolute path of the script
script_path=$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)

# Eliminate possible /tasks from the path
script_path=${script_path%/tasks}

# Get root
root_path=$(cd "$script_path/.." && pwd)

# Get .env
source "$root_path/.env"

# Imports
source "$root_path/tasks/check-leisure.sh"
source "$root_path/tasks/variables.sh"
source "$root_path/tasks/calculate-remaining-hours.sh"

# Set the task_id to search for
task_id="8538082022"  # Update this to the actual ID you’re testing for

# Example priorities list
priorities='28. personal-assistant-cli: Ota huomioon montako tuntia työpäivää on jäljellä (Kotiasiat) (Vapaa-ajan projektit / Personal) (Metadata: id: "8537351600", priority: "1", duration: "undefined", datetime: "undefined")
29. personal-assistant-cli: Ota huomioon kalenterieventit google calendar API:n kautta... (Kotiasiat) (Vapaa-ajan projektit / Personal) (Metadata: id: "8537957275", priority: "1", duration: "undefined", datetime: "undefined")
30. personal-assistant-cli: Obsidian-muistiinpanoon taskin linkki (Kotiasiat) (Vapaa-ajan projektit / Personal) (Metadata: id: "8538082022", priority: "1", duration: "45", datetime: "2024-10-31T12:00:00")
31. personal-assistant-cli: Poista gcalcli-dependenssi (Kotiasiat) (Vapaa-ajan projektit / Personal) (Metadata: id: "8538113818", priority: "1", duration: "undefined", datetime: "undefined")'

# Extract the full line that includes the specific task ID, duration, and datetime
if [[ "$(uname)" == "Darwin" ]]; then
  metadata_line=$(echo "$priorities" | ggrep -P "Metadata:.*id:\s*\"$task_id\".*priority:\s*\"[0-9]+\".*duration:\s*\"[0-9a-zA-Z]+\".*datetime:\s*\"[0-9T:.Z-]+\"")
  task_duration=$(echo "$metadata_line" | ggrep -oP '(?<=duration: ")[0-9a-zA-Z]+')
  task_datetime=$(echo "$metadata_line" | ggrep -oP '(?<=datetime: ")[^"]+')
else
  metadata_line=$(echo "$priorities" | grep -P "Metadata:.*id:\s*\"$task_id\".*priority:\s*\"[0-9]+\".*duration:\s*\"[0-9a-zA-Z]+\".*datetime:\s*\"[0-9T:.Z-]+\"")
  task_duration=$(echo "$metadata_line" | grep -oP '(?<=duration: ")[0-9a-zA-Z]+')
  task_datetime=$(echo "$metadata_line" | grep -oP '(?<=datetime: ")[^"]+')
fi

# Print the matched line and extracted values
echo "metadata_line: $metadata_line"
echo "task_duration: $task_duration"
echo "task_datetime: $task_datetime"
