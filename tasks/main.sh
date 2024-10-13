# Main function
main() {
  echo -e "${BOLD}${YELLOW}Haetaan tämänpäiväiset Todoist-tehtävät...${RESET}"
  tasks=$(fetch_tasks)

  echo -e "${BOLD}${YELLOW}Haetaan tämänpäiväiset Google Calendar -tapahtumat...${RESET}"
  events=$(fetch_calendar_events)

  if [ -z "$events" ]; then
    echo -e "${BOLD}${RED}Ei tämänpäiväisiä kalenteritapahtumia Google Calendarissa.${RESET}"
  fi

  if [ -z "$tasks" ] && [ -z "$events" ]; then
    exit 1
  fi

  echo -e "${BOLD}${GREEN}Tämänpäiväiset tehtävät ja kalenteritapahtumat:${RESET}\n$tasks\n\n$events\n"

  echo -e "${BOLD}${YELLOW}Priorisoidaan tehtävät ja palaverit OpenAI:n avulla ja luodaan muistiinpano...${RESET}"
  priorities=$(get_priorities "$tasks" "$events")

  echo -e "${BOLD}${GREEN}Priorisoidut tehtävät ja asiat:${RESET}\n$priorities\n"

  # Get the current local time with timezone
  current_time=$(TZ=$(cat /etc/timezone) date "+%H:%M")
  remaining_hours=$(calculate_remaining_hours)

  # Filename format: YYYY-MM-DD_HH-MM-SS.md
  filename=$(date "+%Y-%m-%d_%H-%M-%S")
  date_header=$(date "+%d.%m.%Y")

  # Add Todoist plugin header to the first part of the note
  todoist_header='```todoist
  filter: "#Todo & '"$date_header"'"
  autorefresh: 120
  show:
  - description
  ```'

  # Save output to Obsidian vault with the current time and remaining hours in the header
  echo -e "# $date_header\n\n## Todoist\n\n$todoist_header\n\nKello on muistiinpanojen luomishetkellä $current_time. Päivää on jäljellä noin $remaining_hours tuntia.\n\n$priorities" > "$HOME/Documents/Brain dump/Päivän suunnittelu/$filename.md"
  echo -e "${BOLD}${GREEN}Priorisointi on valmis ja tallennettu Obsidian-vaultiin.${RESET}"

  echo -e "${BOLD}${YELLOW}Siirretään tehtäviä seuraavalle päivälle...${RESET}"

  # Debug: Print the full content of postponed_tasks to see what's being parsed
  if [ "$DEBUG" = true ]; then
    echo -e "${BOLD}${CYAN}Content of postponed_tasks:${RESET}\n$priorities\n"
  fi

  # Select all numbers that have more than 5 digits
  task_ids_to_postpone=$(echo "$priorities" | grep -oP '\d{5,}')

  # Debugging to see the extracted task IDs
  if [ "$DEBUG" = true ]; then
    echo -e "${BOLD}${CYAN}Postponed task IDs:${RESET} $task_ids_to_postpone"
  fi

  # Moving those tasks to the next day that AI suggested
  if [[ -n "$task_ids_to_postpone" ]]; then
    echo -e "${BOLD}${YELLOW}Siirretään AI:n suosittelemat tehtävät seuraavalle päivälle...${RESET}"

    for task_id in $task_ids_to_postpone; do
      postpone_task "$task_id"
    done
  else
    echo -e "${BOLD}${CYAN}AI ei suositellut tehtävien siirtämistä.${RESET}"
  fi
}

# Run the script
main "$@"
