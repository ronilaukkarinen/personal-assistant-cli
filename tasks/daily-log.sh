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

  # Determine the appropriate date command for macOS (Darwin) or other systems
  if [[ "$(uname)" == "Darwin" ]]; then
    date_cmd="gdate"
  else
    date_cmd="date"
  fi


  today=$($date_cmd "+%Y-%m-%d")
  #today="2024-10-24"

  echo "Processing daily log for $today..."

  # Get month as two digits and written name
  month_num=$($date_cmd "+%m")
  month=$($date_cmd "+%B" | tr '[:upper:]' '[:lower:]')

  # Header for the note in Finnish (e.g. Tiistai, 15. lokakuuta 2024)
  weekday=$($date_cmd "+%A" | awk '{print toupper(substr($0,1,1)) tolower(substr($0,2))}')
  header="$weekday, $($date_cmd "+%-d"). ${month}ta $($date_cmd "+%Y")"

  # Log file path (use your preferred location), uses yyyy/mm/d.m.yyyy.md structure
  if [[ "$(uname)" == "Darwin" ]]; then
    # macOS version
    log_file="$HOME/Documents/Brain dump/Päivittäinen reflektointi/$($date_cmd "+%Y")/$month_num/$($date_cmd "%-d.%-m.%Y").md"
  else
    # Linux version - remove leading zeros with sed
    day=$($date_cmd "+%d" | sed 's/^0//')
    month=$($date_cmd "+%m" | sed 's/^0//')
    log_file="$HOME/Documents/Brain dump/Päivittäinen reflektointi/$($date_cmd "+%Y")/$month_num/${day}.${month}.$($date_cmd "+%Y").md"
  fi

  # Create directory structure if it doesn't exist
  mkdir -p "$(dirname "$log_file")"

  # Fetch completed tasks
  completed_tasks=$(curl -s -H "Authorization: Bearer $TODOIST_API_KEY" "https://api.todoist.com/sync/v9/completed/get_all")

  # Extract task names without labels, ensure the task is completed today
  task_info=$(echo "$completed_tasks" | jq -r --arg today "$today" '
    .items | map(select(.completed_at | startswith($today))) | sort_by(.completed_at) | .[] |
    # Check if task has a parent based on content indentation
    if (.content | startswith("  ")) then
      "    - [x] \(.content | sub(" @.*"; "") | sub("^  "; "")) (valmis \(.completed_at | split("T")[1] | split(".")[0]))"
    else
      "- [x] \(.content | sub(" @.*"; "") ) (valmis \(.completed_at | split("T")[1] | split(".")[0]))"
    end
  ' | while IFS= read -r line; do
    if [[ "$(uname)" == "Darwin" ]]; then
      completed_time=$(echo "$line" | ggrep -oP '(?<=valmis )[0-9:]+')
    else
      completed_time=$(echo "$line" | grep -oP '(?<=valmis )[0-9:]+')
    fi
    local_time=$($date_cmd -d "$completed_time UTC" +'%H:%M')
    echo "$line" | sed "s/$completed_time/$local_time/"
  done)

  # Count the number of completed tasks
  task_count=$(echo "$completed_tasks" | jq --arg today "$today" '[.items[] | select(.completed_at | startswith($today))] | length')
  task_count=${task_count:-0}  # Set to 0 if empty

  # If $task count is 1, print "tehtävä", otherwise print "tehtävää"
  if [ "$task_count" -eq 1 ]; then
    task_label="tehtävä"
  else
    task_label="tehtävää"
  fi

  # Add header to the log file
  echo -e "# $header\n" > "$log_file"
  echo -e "## Tänään tehdyt asiat\n" >> "$log_file"
  echo -e "Yhteensä $task_count $task_label.\n" >> "$log_file"
  echo -e "$task_info" >> "$log_file"
  echo "Log saved to $log_file"

  # Debug
  echo ""
  echo "Completed tasks:"
  echo "$task_info"

  # AI notes
  echo ""
  echo -e "Generating AI notes for the completed tasks..."

  # Optional: Generate AI notes on completed tasks
  notes_instructions='Anna yhteenveto ja palaute päivän suoritetuista tehtävistä, pääotsikolla "Päivän yhteenveto". Kerro mitä tämän päivän tehtävistä opittiin. Anna palaute markdown-muodossa ja muista AINA tyhjä rivi otsikkojen jälkeen, älä käytä kaksoispisteitä otsikoissa. Otsikkotyyppisiin käytä aina otsikkoa boldauksen sijaan. Tehtävälista minulla on jo, joten sitä en erikseen tarvitse yhteenvetoon, ellet halua eritellä joistakin tehtävistä nostettuna jotain. Tässä on lista tänään suoritetuista tehtävistä:'
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
