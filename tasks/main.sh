# Main function
main() {
  echo -e "${BOLD}${YELLOW}Fetching Todoist tasks for today...${RESET}"
  tasks=$(fetch_tasks)

  #echo -e "${BOLD}${YELLOW}Fetching Google Calendar events for today...${RESET}"
  # events=$(fetch_calendar_events)

  echo -e "${BOLD}${YELLOW}Prioritizing tasks and events with OpenAI and creating a note...${RESET}"
  priorities=$(get_priorities "$tasks" "$events")

  echo -e "${BOLD}${GREEN}Prioritization ready:${RESET}\n$priorities\n"

  # Get the current local time with timezone
  current_time=$(TZ=$(cat /etc/timezone) date "+%H:%M")
  remaining_hours=$(calculate_remaining_hours)

  # Filename format: YYYY-MM-DD_HH-MM-SS.md
  filename=$(date "+%Y-%m-%d_%H-%M-%S")
  date_header=$(date "+%d.%m.%Y")
  todois_tasklist_date_header=$(date "+%b %d %Y")

  # Add Todoist plugin header to the first part of the note
  todoist_header='```todoist
  filter: "#Todo & '"$todois_tasklist_date_header"'"
  autorefresh: 120
  show:
  - description
  ```'

  # Save output to Obsidian vault with the current time and remaining hours in the header
  echo -e "# $date_header\n\n## Todoist\n\n$todoist_header\n\nKello on muistiinpanojen luomishetkellä $current_time. Päivää on jäljellä noin $remaining_hours tuntia.\n\n$priorities" > "$HOME/Documents/Brain dump/Päivän suunnittelu/$filename.md"

  echo -e "${BOLD}${GREEN}Prioritization is ready and saved to Obsidian.${RESET}"

  echo -e "${BOLD}${YELLOW}Postponing tasks to the next day...${RESET}"

  # Debug: Print the full content of postponed_tasks to see what's being parsed
  if [ "$DEBUG" = true ]; then
    echo -e "${BOLD}${CYAN}Content of postponed_tasks:${RESET}\n$priorities\n"
  fi

  # Select all numbers that have more than 5 digits
  #task_ids_to_postpone=$(echo "$priorities" | grep -oP '\d{5,}')

  # Look for the line (Metadata: "duration": 90, "datetime": "2022-10-14T08:00:00.000000Z") (8183679870, "siirretty seuraavalle päivälle") for postponed tasks
  task_ids_to_postpone=$(echo "$priorities" | grep -oP '(\d{10,}, "siirretty seuraavalle päivälle")' | cut -d, -f1)

  # Debugging to see the extracted task IDs
  if [ "$DEBUG" = true ]; then
    echo -e "${BOLD}${CYAN}Postponed task IDs:${RESET} $task_ids_to_postpone"
  fi

  # Moving those tasks to the next day that AI suggested
  if [[ -n "$task_ids_to_postpone" ]]; then
    echo -e "${BOLD}${YELLOW}Postponing tasks suggested by AI to the next day...${RESET}"

    for task_id in $task_ids_to_postpone; do
      postpone_task "$task_id"
    done
  else
    echo -e "${BOLD}${CYAN}AI did not suggest postponing any tasks or task IDs were not found.${RESET}"
  fi
}

# Run the script
main "$@"
