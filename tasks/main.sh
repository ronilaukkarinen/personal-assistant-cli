
# Main function
main() {
  local mode="today"  # Default to processing today's tasks
  local days_to_process=1  # Default to 1 day
  local start_day=$(date +%Y-%m-%d)

  # Parse command line arguments
  source "${SCRIPTS_LOCATION}/tasks/arguments.sh"

  # Process based on mode
  if [ "$mode" = "days" ] && [ "$days_to_process" -gt 0 ]; then
    echo -e "${BOLD}${YELLOW}Processing tasks for the next $days_to_process days...${RESET}"
    fetch_tasks "$start_day" "$days_to_process"
  else
    echo -e "${BOLD}${YELLOW}Processing today's tasks...${RESET}"
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

  # Filename format: YYYY-MM-DD.md
  filename=$(date "+%Y-%m-%d")

  # Get the current date in the format "Oct 13 2024", in English
  # Change to English
  export LC_TIME=en_US.UTF-8
  todoist_tasklist_date_header=$(date "+%b %d %Y")

  # Change back to Finnish
  export LC_TIME=fi_FI.UTF-8

  # Date of today
  today=$(date "+%Y-%m-%d")

  # Lowercase month
  month=$(date "+%B" | tr '[:upper:]' '[:lower:]')

  # Header for the note in Finnish (e. g. Tiistai, 15. lokakuuta 2024)
  weekday=$(date "+%A" | awk '{print toupper(substr($0,1,1)) tolower(substr($0,2))}')
  header="$weekday, $(date "+%-d"). ${month}ta $(date "+%Y")"

  # Add remaining hours
  remaining_hours=$(calculate_remaining_hours)

  # File path
  file_path="$HOME/Documents/Brain dump/Päivän suunnittelu/$filename.md"

  # Save output to Obsidian vault with the current time and remaining hours in the header
  echo -e "# $header\n\nKello on muistiinpanojen luomishetkellä $current_time. Päivää on jäljellä noin $remaining_hours tuntia. Yhteensä tapaamisia tänään $total_event_duration tuntia (mukaanlukien lounas). Palaverien määrä tänään: $event_count. Päivässä aikaa tehtävien suorittamiseen jäljellä yhteensä $remaining_work_hours tuntia.\n\n## Päivän tapahtumat\n\n$all_events\n$priorities" > "$file_path"

  # Add TASKS_TO_BE_SCHEDULED at the end of the file
  echo -e "\n\n## Aikataulutetut tehtävät\n\n$TASKS_TO_BE_SCHEDULED" >> "$file_path"

  echo -e "${BOLD}${GREEN}Prioritization is ready and saved to Obsidian, file: $file_path.md${RESET}"

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
        metadata_line=$(echo "$priorities" | ggrep -P "Metadata:.*\"duration\":\s*[0-9]+.*\"datetime\":\s*\"[0-9T:.Z-]+\".*$task_id")
      else
        metadata_line=$(echo "$priorities" | grep -P "Metadata:.*\"duration\":\s*[0-9]+.*\"datetime\":\s*\"[0-9T:.Z-]+\".*$task_id")
      fi

      if [[ -n "$metadata_line" ]]; then
        if [[ "$(uname)" == "Darwin" ]]; then
          task_duration=$(echo "$metadata_line" | ggrep -oP '(?<=duration:\s")\d+')
          task_datetime=$(echo "$metadata_line" | ggrep -oP '(?<=datetime:\s")[^"]+')
        else
          task_duration=$(echo "$metadata_line" | grep -oP '(?<=duration:\s")\d+')
          task_datetime=$(echo "$metadata_line" | grep -oP '(?<=datetime:\s")[^"]+')
        fi

        if [[ -n "$task_duration" && -n "$task_datetime" ]]; then
          schedule_task "$task_id" "$task_duration" "$task_datetime"
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
