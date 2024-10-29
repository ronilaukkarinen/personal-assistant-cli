# Refresh access token for Google API
refresh_access_token() {
    response=$(curl -s -X POST \
    -d "client_id=${GOOGLE_CLIENT_ID}" \
    -d "client_secret=${GOOGLE_CLIENT_SECRET}" \
    -d "refresh_token=${GOOGLE_REFRESH_TOKEN}" \
    -d "grant_type=refresh_token" \
    https://accounts.google.com/o/oauth2/token)

    access_token=$(echo "$response" | jq -r .access_token)
    export GOOGLE_API_TOKEN=$access_token
}

# Call the function to refresh the access token before making API calls
refresh_access_token

# Function: Fetch and display today's events from Google Calendar
list_today_events() {
  # Get --days to process
  if [ -z "$1" ]; then
    days_to_process=1
  else
    days_to_process=$1
  fi

  # Get --start_day
  if [ -z "$2" ]; then
    if [[ "$(uname)" == "Darwin" ]]; then
      start_day=$(gdate "+%Y-%m-%d")
    else
      start_day=$(date "+%Y-%m-%d")
    fi
  else
    start_day=$2
  fi

  timeMin="${current_day}T00:00:00Z"
  timeMax="${current_day}T23:59:59Z"

  for i in $(seq 0 $((days_to_process-1))); do
    # Check if macOS is used
    if [[ "$(uname)" == "Darwin" ]]; then
      current_day=$(gdate -d "$start_day + $i days" "+%Y-%m-%d")
      current_time=$(gdate "+%H:%M")
    else
      current_day=$(date -d "$start_day + $i days" "+%Y-%m-%d")
      current_time=$(date "+%H:%M")
    fi

    # Replace with your Google Calendar ID(s)
    calendar_ids=("${WORK_CALENDAR_ID}" "${FAMILY_CALENDAR_ID}" "${TRAINING_CALENDAR_ID}")

    # Loop through each calendar to fetch and list events
    for calendar_id in "${calendar_ids[@]}"; do
      echo -e "\n${BOLD}${CYAN}Listing events for calendar: $calendar_id\n\n${RESET}"

      # Fetch events from the Google Calendar API
      events=$(curl -s -X GET "https://www.googleapis.com/calendar/v3/calendars/${calendar_id}/events?timeMin=${timeMin}&timeMax=${timeMax}&singleEvents=true&orderBy=startTime" \
        -H "Authorization: Bearer ${GOOGLE_API_TOKEN}")

      # Check if the response contains an error
      if echo "$events" | grep -q '"error"'; then
        echo "Error fetching events for calendar: $(echo "$events" | jq -r '.error.message')"
      else
        # Print out each event's summary and start time
        echo "$events" | jq -r '.items[] | "\(.summary) (\(.start.dateTime // .start.date))"'
      fi
    done
  done
}
