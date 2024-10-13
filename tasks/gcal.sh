# Function: Fetch today's Google Calendar events from a specific calendar
fetch_calendar_events() {
  # If GCAL_EVENTS_TO_TASKS_ENABLED is 1, do not run this function
  if [ "$GCAL_EVENTS_TO_TASKS_ENABLED" = 1 ]; then
    return
  fi

  local today
  today=$(date +%Y-%m-%d)

  # Fetch events from the specific calendar and print raw output if debug flag is enabled
  calendar_output=$(gcalcli --nocolor --calendar "Roni Laukkarinen (Rollen työkalenteri)" agenda "$today" "$today 23:00" 2>&1)

  # If debug mode is enabled, show raw gcalcli output
  if [ "$DEBUG" = true ]; then
    echo -e "${BOLD}${CYAN}Raaka gcalcli-vastaus:${RESET}\n$calendar_output\n"
  fi

  # Check for API errors
  if [[ "$calendar_output" == *"Invalid Credentials"* ]]; then
    echo -e "${BOLD}${RED}Virhe: Google Calendar API -avaimet ovat virheelliset tai puuttuvat.${RESET}"
    exit 1
  elif [[ "$calendar_output" == *"No calendars found"* ]]; then
    echo -e "${BOLD}${RED}Virhe: Google Calendar -tilillä ei ole saatavilla olevia kalentereita.${RESET}"
    exit 1
  elif [[ "$calendar_output" == "" ]]; then
    echo -e "${BOLD}${RED}Virhe: Google Calendar API ei palauttanut mitään tapahtumia. Tarkista internet-yhteys tai API-avaimet.${RESET}"
    exit 1
  fi

  # Output all calendar events (no filtering)
  echo "$calendar_output"
}
