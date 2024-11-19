# Main function
main() {
  local mode="today"  # Default to processing today's tasks
  local days_to_process=1  # Default to 1 day

  # Process based on mode
  if [ "$mode" = "days" ] && [ "$days_to_process" -gt 0 ]; then
    echo -e "${BOLD}${YELLOW}Processing tasks for the next $days_to_process days...${RESET}"
    fetch_tasks "$start_day" "$days_to_process"
  else
    echo -e "${BOLD}${YELLOW}Processing tasks for $start_day...${RESET}"
    fetch_tasks "$start_day" 1
  fi

  # Get --debug argument
  if [[ " $* " == *" --debug "* ]]; then
    DEBUG=true
  else
    DEBUG=false
  fi

  if [ "$mode" = "days" ] && [ "$days_to_process" -gt 0 ]; then
    echo -e "${BOLD}${YELLOW}Prioritizing tasks with OpenAI for the next $days_to_process days...${RESET}"
    priorities=$(get_priorities "$day_tasks" "$days_to_process" "$start_day")
  else
    echo -e "${BOLD}${YELLOW}Prioritizing tasks and events with OpenAI for $start_day...${RESET}"

    priorities=$(get_priorities "$day_tasks" 1 "$start_day")
  fi

  echo -e "${BOLD}${GREEN}Prioritization ready:${RESET}\n$priorities\n"

  # Get the current local time with timezone
  current_time=$(date "+%H:%M")

  # Get the current date in the format "Oct 13 2024", in English
  # Change to English
  export LC_TIME=en_US.UTF-8
  todoist_tasklist_date_header=$(date "+%b %d %Y")

  # Change back to Finnish
  export LC_TIME=fi_FI.UTF-8

  # macOS and Linux compatible version of date
  if [[ "$(uname)" == "Darwin" ]]; then
    today=$(gdate -d "$start_day" "+%Y-%m-%d")
    month=$(gdate -d "$start_day" "+%B" | tr '[:upper:]' '[:lower:]')
    weekday=$(gdate -d "$start_day" "+%A" | awk '{print toupper(substr($0,1,1)) tolower(substr($0,2))}')
    header="$weekday, $(gdate -d "$start_day" "+%-d"). ${month}ta $(gdate -d "$start_day" "+%Y")"
    filename=$(gdate -d "$start_day" "+%Y-%m-%d")
  else
    today=$(date -d "$start_day" "+%Y-%m-%d")
    month=$(date -d "$start_day" "+%B" | tr '[:upper:]' '[:lower:]')
    weekday=$(date -d "$start_day" "+%A" | awk '{print toupper(substr($0,1,1)) tolower(substr($0,2))}')
    header="$weekday, $(date -d "$start_day" "+%-d"). ${month}ta $(date -d "$start_day" "+%Y")"
    filename=$(date -d "$start_day" "+%Y-%m-%d")
  fi

  # Calculate remaining hours
  if [[ "$(uname)" == "Darwin" ]]; then
    remaining_hours=$(calculate_remaining_hours)
    current_time=$(gdate "+%H:%M")
  else
    remaining_hours=$(calculate_remaining_hours)
    current_time=$(date "+%H:%M")
  fi

  # Debug remaining hours calculation
  if [ "$DEBUG" = true ]; then
    echo -e "${CYAN}Debug: Current time: $current_time${RESET}"
    echo -e "${CYAN}Debug: Remaining hours: $remaining_hours${RESET}"
  fi

  # File path
  file_path="$HOME/Documents/Brain dump/Päivän suunnittelu/$filename.md"

  # Save output to Obsidian vault with the current time and remaining hours in the header
  if [ -n "$remaining_hours" ]; then
    echo -e "# $header\n\nKello on muistiinpanojen luomishetkellä $current_time. Päivää on jäljellä noin $remaining_hours tuntia.\n\nYhteensä tapaamisia tänään $total_event_duration tuntia (mukaanlukien lounas). Tehtäviä tänään: **${TOTAL_TASK_COUNT}**. Palaverien määrä tänään: **${event_count}**. Päivässä aikaa tehtävien suorittamiseen jäljellä yhteensä **${remaining_work_hours} tuntia**.\n\n## Päivän tapahtumat\n\n$all_events\n$priorities" > "$file_path"
  else
    # Fallback if calculate_remaining_hours fails
    current_hour=$(date "+%H")
    remaining_hours=$((24 - current_hour))
    echo -e "# $header\n\nKello on muistiinpanojen luomishetkellä $current_time. Päivää on jäljellä noin $remaining_hours tuntia.\n\nYhteensä tapaamisia tänään $total_event_duration tuntia (mukaanlukien lounas). Tehtäviä tänään: **${TOTAL_TASK_COUNT}**. Palaverien määrä tänään: **${event_count}**. Päivässä aikaa tehtävien suorittamiseen jäljellä yhteensä **${remaining_work_hours} tuntia**.\n\n## Päivän tapahtumat\n\n$all_events\n$priorities" > "$file_path"
  fi

  # Add TASKS_TO_BE_SCHEDULED at the end of the file
  echo -e "\n## Aikataulutetut tehtävät\n\n$TASKS_TO_BE_SCHEDULED" >> "$file_path"

  echo -e "${BOLD}${GREEN}Prioritization is ready and saved to Obsidian, file: "$file_path"${RESET}"

  # Debug: Print the full content of tasks to see what's being parsed
  if [ "$DEBUG" = true ]; then
    echo -e "${BOLD}${CYAN}Content of tasks that are being parsed:${RESET}\n$priorities\n"
  fi

  # If macOS and no ggrep found, install ggrep directly
  if [[ "$(uname)" == "Darwin" ]] && ! command -v ggrep &> /dev/null; then
    echo -e "${BOLD}${YELLOW}Installing ggrep for macOS...${RESET}"
    brew install grep
  fi

  # macOS and Linux compatible version of grep
  if [[ "$(uname)" == "Darwin" ]]; then
    # Extract all numbers with more than 5 digits, which we assume to be task IDs
    task_ids_to_schedule=$(echo "$priorities" | ggrep -oP '\b[0-9]{6,}\b')
  else
    # Extract all numbers with more than 5 digits, which we assume to be task IDs
    task_ids_to_schedule=$(echo "$priorities" | grep -oP '\b[0-9]{6,}\b')
  fi

  if [[ -n "$task_ids_to_schedule" ]]; then
    echo -e "${BOLD}${YELLOW}Scheduling tasks based on metadata...${RESET}"

    for task_id in $task_ids_to_schedule; do
      if [[ "$(uname)" == "Darwin" ]]; then
        metadata_line=$(echo "$priorities" | ggrep -P "Metadata:.*id:\s*\"$task_id\".*priority:\s*\"[0-9]+\".*duration:\s*\"[0-9a-zA-Z]+\".*datetime:\s*\"[0-9T:.Z-]+\".*backlog:\s*\"?(true|false)")
      else
        metadata_line=$(echo "$priorities" | grep -P "Metadata:.*id:\s*\"$task_id\".*priority:\s*\"[0-9]+\".*duration:\s*\"[0-9a-zA-Z]+\".*datetime:\s*\"[0-9T:.Z-]+\".*backlog:\s*\"?(true|false)")
      fi

      if [[ -n "$metadata_line" ]]; then
        if [[ "$(uname)" == "Darwin" ]]; then
          task_duration=$(echo "$metadata_line" | ggrep -oP '(?<=duration: ")[0-9a-zA-Z]+')
          task_datetime=$(echo "$metadata_line" | ggrep -oP '(?<=datetime: ")[^"]+')
          backlog=$(echo "$metadata_line" | ggrep -oP '(?<=backlog: )(true|false)')
        else
          task_duration=$(echo "$metadata_line" | grep -oP '(?<=duration: ")[0-9a-zA-Z]+')
          task_datetime=$(echo "$metadata_line" | grep -oP '(?<=datetime: ")[^"]+')
          backlog=$(echo "$metadata_line" | grep -oP '(?<=backlog: )(true|false)')
        fi

        if [[ -n "$task_duration" && -n "$task_datetime" ]]; then
          schedule_task "$task_id" "$task_duration" "$task_datetime" "$today" "$backlog"
        else
          echo -e "${RED}Error: Missing duration or datetime for task ID $task_id${RESET}"
        fi
      else
        echo -e "${RED}Error: No metadata found for task ID $task_id${RESET}"
      fi
    done
  else
    echo -e "${BOLD}${CYAN}AI did not suggest scheduling any tasks or task IDs were not found.${RESET}"
  fi
}

# Run the script
main "$@"
