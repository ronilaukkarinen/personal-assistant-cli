#!/bin/bash
# Function: Daily log, record completed tasks to a file with notes by AI
daily_log() {
  # Get absolute path of the script
  script_path=$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)

  # Eliminate possible /tasks from the path
  script_path=${script_path%/tasks}

  # Get .env
  source "$script_path/.env"

  # Imports
  source "$script_path/tasks/check-leisure.sh"
  source "$script_path/tasks/variables.sh"

  # Use Finnish locale for the date
  export LC_TIME=fi_FI.UTF-8

  # Date of today
  today=$(date "+%Y-%m-%d")

  # Lowercase month
  month=$(date "+%B" | tr '[:upper:]' '[:lower:]')

  # Header for the note in Finnish (e. g. Tiistai, 15. lokakuuta 2024)
  weekday=$(date "+%A" | awk '{print toupper(substr($0,1,1)) tolower(substr($0,2))}')
  header="$weekday, $(date "+%-d"). ${month}ta $(date "+%Y")"

  # Log file path (use your preferred location)
  log_file="$HOME/Documents/Brain dump/Päivittäinen reflektointi/$today.md"

  # Fetch completed tasks from Todoist API
  completed_tasks=$(curl -s --request GET \
    --url "https://api.todoist.com/sync/v9/completed/get_all" \
    --header "Authorization: Bearer ${TODOIST_API_KEY}")

  # Check if the response is valid JSON
  if echo "$completed_tasks" | jq empty 2>/dev/null; then
    # Extract task names without labels, ensure the task is completed today, and reverse the order
    task_info=$(echo "$completed_tasks" | jq -r --arg today "$today" '
      .items[] | select(.completed_at | startswith($today)) |
      "- [x] \(.content | sub(" @.*"; "") ) (\(.labels | join(", "))) (valmis \(.completed_at | split("T")[1] | split(".")[0]))"
    ' | while read -r line; do
      completed_time=$(echo "$line" | grep -oP '(?<=valmis )[0-9:]+')
      local_time=$(date -d "$completed_time UTC" +'%H:%M')
      echo "$line" | sed "s/$completed_time/$local_time/"
    done | tac)

    # Count the number of completed tasks
    task_count=$(echo "$completed_tasks" | jq --arg today "$today" '[.items[] | select(.completed_at | startswith($today))] | length')

    # If $task count is 1, print "tehtävä", otherwise print "tehtävää"
    if [ "$task_count" -eq 1 ]; then
      task_label="tehtävä"
    else
      task_label="tehtävää"
    fi

    # Add header to the log file with the task count
    echo -e "# $header\n" > "$log_file"
    echo -e "## Tänään tehdyt asiat\n\n$task_info" >> "$log_file"
    echo -e "\n\nYhteensä $task_count $task_label." >> "$log_file"
    echo "Log saved to $log_file"

    # Debug
    echo ""
    echo "Completed tasks:"
    echo "$task_info"
  else
    echo "Error: Invalid JSON response or no completed tasks."
    echo "Raw API Response: $completed_tasks"
  fi

  # AI notes
  echo ""
  echo -e "Generating AI notes for the completed tasks..."

  # Optional: Generate AI notes on completed tasks
  notes_instructions='Anna yhteenveto ja palaute päivän suoritetuista tehtävistä, pääotsikolla "Päivän yhteenveto". Kerro mitä tämän päivän tehtävistä opittiin. Anna palaute markdown-muodossa ja muista tyhjä rivi otsikkojen jälkeen. Tehtävälista minulla on jo, joten sitä en erikseen tarvitse yhteenvetoon, ellet halua eritellä joistakin tehtävistä nostettuna jotain. Tässä on lista tänään suoritetuista tehtävistä:'
  combined_message="${PROMPT_BGINFO}\n\n$notes_instructions\n\n$task_info"

  # Create a JSON payload for OpenAI API
  json_payload=$(jq -n --arg combined_message "$combined_message" '{
    "model": "gpt-4o-mini",
    "messages": [
      {"role": "system", "content": "Olet avulias assistentti."},
      {"role": "user", "content": $combined_message}
    ],
    "max_tokens": 16000,
    "temperature": 1
  }')

  # Call OpenAI to generate the notes and append to log file
  response=$(curl -s --request POST \
    --url "https://api.openai.com/v1/chat/completions" \
    --header "Content-Type: application/json" \
    --header "Authorization: Bearer ${OPENAI_API_KEY}" \
    --data "$json_payload")

  # Extract AI-generated notes
  ai_notes=$(echo "$response" | jq -r '.choices[0].message.content')

  # Append AI-generated notes to the log file
  echo -e "\n$ai_notes" >> "$log_file"

  echo "Completed tasks and notes have been logged to $log_file"
}

# Run the function
daily_log
