#!/bin/bash
# File: list-events.sh
# Purpose: List today's events from Google Calendar

# Get absolute path of the script
script_path=$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)

# Eliminate possible /tasks from the path
script_path=${script_path%/tasks}

# Get root
root_path=$(cd "$script_path/.." && pwd)

# Get .env
source "$root_path/.env"

# Imports
source "$root_path/tasks/check-leisure.sh"
source "$root_path/tasks/variables.sh"
source "$root_path/tasks/calculate-remaining-hours.sh"

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
  # Define the start and end times for today in UTC
  current_day=$(date -u +"%Y-%m-%d")
  timeMin="${current_day}T00:00:00Z"
  timeMax="${current_day}T23:59:59Z"

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
}

# Run the function
list_today_events
