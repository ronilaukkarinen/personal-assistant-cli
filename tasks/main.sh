
# Main function
main() {
  local mode="today"  # Default to processing today's tasks
  local days_to_process=1  # Default to 1 day
  local start_day=$(date +%Y-%m-%d)

  # Parse command-line arguments
  while [[ "$#" -gt 0 ]]; do
    case "$1" in
      --days)
        shift
        if [[ "$1" =~ ^[0-9]+$ ]]; then
          days_to_process="$1"
          mode="days" # Switch mode to process multiple days
        else
          echo "Error: --days argument requires a valid number."
          exit 1
        fi
        ;;
      --debug)
        DEBUG=true
        ;;
      *)
        echo "Unknown argument: $1"
        exit 1
        ;;
    esac
    shift
  done

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
  current_timezone=$(get_timezone)
  current_time=$(TZ="$current_timezone" date "+%H:%M")
  remaining_hours=$(calculate_remaining_hours)

  # Filename format: YYYY-MM-DD_HH-MM-SS.md
  filename=$(date "+%Y-%m-%d_%H-%M-%S")
  date_header=$(date "+%d.%m.%Y")

  # Get the current date in the format "Oct 13 2024", in English

  # Change to English
  export LC_TIME=en_US.UTF-8
  todoist_tasklist_date_header=$(date "+%b %d %Y")

  # Add Todoist plugin header to the first part of the note
  todoist_header='```todoist
  filter: "#Todo & '"$todoist_tasklist_date_header"'"
  autorefresh: 120
  show:
  - description
  ```'

  # Change back to Finnish
  export LC_TIME=fi_FI.UTF-8

  # Killswitch for debugging
  if [ "$KILLSWITH" = true ]; then
    exit 1
  fi

  # Save output to Obsidian vault with the current time and remaining hours in the header
  echo -e "# $date_header\n\n## Todoist\n\n$todoist_header\n\nKello on muistiinpanojen luomishetkellä $current_time. Päivää on jäljellä noin $remaining_hours tuntia.\n\n$priorities" > "$HOME/Documents/Brain dump/Päivän suunnittelu/$filename.md"

  echo -e "${BOLD}${GREEN}Prioritization is ready and saved to Obsidian.${RESET}"

  echo -e "${BOLD}${YELLOW}Postponing tasks to the next day...${RESET}"

  # Debug: Print the full content of postponed_tasks to see what's being parsed
  if [ "$DEBUG" = true ]; then
    echo -e "${BOLD}${CYAN}Content of postponed_tasks:${RESET}\n$priorities\n"
  fi

  # Look for the line (Metadata: "duration": 90, "datetime": "2022-10-14T08:00:00.000000Z") (8183679870, "siirretty seuraavalle päivälle") for postponed tasks

  # If macOS and no ggrep found, install ggrep directly
  if [[ "$(uname)" == "Darwin" ]] && ! command -v ggrep &> /dev/null; then
    echo -e "${BOLD}${YELLOW}Installing ggrep for macOS...${RESET}"
    brew install grep
  fi

  # macOS and Linux compatible version of grep
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

    for task_id in $task_ids_to_postpone; do
      postpone_task "$task_id" "$current_day"
    done
  else
    echo -e "${BOLD}${CYAN}AI did not suggest postponing any tasks or task IDs were not found.${RESET}"
  fi
}

# Run the script
main "$@"
