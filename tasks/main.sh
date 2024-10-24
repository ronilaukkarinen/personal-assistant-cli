
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

  if [ "$mode" = "days" ] && [ "$days_to_process" -gt 0 ]; then
    echo -e "${BOLD}${YELLOW}Prioritizing tasks with OpenAI for the next $days_to_process days...${RESET}"
    priorities=$(get_priorities "$day_tasks" "$days_to_process" "$start_day")
  else
    echo -e "${BOLD}${YELLOW}Prioritizing tasks and events with OpenAI for today...${RESET}"

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
  remaining_hours=$(calculate_remaining_hours "$current_time")

  # Save output to Obsidian vault with the current time and remaining hours in the header
  echo -e "# $header\n\nKello on muistiinpanojen luomishetkellä $current_time. Päivää on jäljellä noin $remaining_hours tuntia.\n\n$priorities" > "$HOME/Documents/Brain dump/Päivän suunnittelu/$filename.md"

  echo -e "${BOLD}${GREEN}Prioritization is ready and saved to Obsidian.${RESET}"

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
        task_duration=$(echo "$metadata_line" | grep -oP '(?<=duration":\s)[0-9]+')
        task_datetime=$(echo "$metadata_line" | grep -oP '(?<=datetime":\s")[^"]+')

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

  echo -e "${BOLD}${YELLOW}Postponing tasks to the next day...${RESET}"
  # macOS and Linux compatible version
  if [[ "$(uname)" == "Darwin" ]]; then
    task_ids_to_postpone=$(echo "$priorities" | ggrep -oP '\b\d{5,}\b(?=.*siirretty seuraavalle päivälle)')
  else
    task_ids_to_postpone=$(echo "$priorities" | grep -oP '\b\d{5,}\b(?=.*siirretty seuraavalle päivälle)')
  fi

  # Debugging to see the extracted task IDs
  if [ "$DEBUG" = true ]; then
    echo -e "${BOLD}${CYAN}Postponed task IDs:${RESET} $task_ids_to_postpone"
  fi

  # Moving those tasks to the next day that AI suggested
  if [[ -n "$task_ids_to_postpone" ]]; then
    echo -e "${BOLD}${YELLOW}Postponing tasks suggested by AI to the next day...${RESET}"

    for postpone_task_id in $task_ids_to_postpone; do
      postpone_task "$postpone_task_id" "$current_day"
    done
  else
    echo -e "${BOLD}${CYAN}AI did not suggest postponing any tasks or task IDs were not found.${RESET}"
  fi
}

# Run the script
main "$@"
