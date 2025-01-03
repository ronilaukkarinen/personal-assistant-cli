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

# If there is no days_to_process argument, default to 1 day
if [ -z "$days_to_process" ]; then
  days_to_process=0
  offset=0
else
  offset=$((days_to_process - 1))
fi

# Function: Fetch and display today's events from Google Calendar
list_today_events() {
  for i in $(seq 0 $((offset))); do
    timeMin="${current_day}T00:00:00Z"
    timeMax="${current_day}T23:59:59Z"

    # Replace with your Google Calendar ID(s)
    calendar_ids=("${WORK_CALENDAR_ID}" "${FAMILY_CALENDAR_ID}" "${TRAINING_CALENDAR_ID}")

    # Initialize an empty variable to store all events and total duration
    all_events=""
    total_event_duration=0

    # Loop through each calendar to fetch and list events
    for calendar_id in "${calendar_ids[@]}"; do
      # Fetch events from the Google Calendar API
      calendar_events=$(curl -s -X GET "https://www.googleapis.com/calendar/v3/calendars/${calendar_id}/events?timeMin=${timeMin}&timeMax=${timeMax}&singleEvents=true&orderBy=startTime" \
        -H "Authorization: Bearer ${GOOGLE_API_TOKEN}")

      # Check if the response contains an error
      if echo "$calendar_events" | grep -q '"error"'; then
        echo "Error fetching events for calendar: $(echo "$calendar_events" | jq -r '.error.message')"
      else
        # Process each event to format and calculate duration
        while IFS= read -r event; do
          # Extract event summary, start, and end details
          event_name=$(echo "$event" | jq -r '.summary')

          # Skip events with "Focus" in the name or empty event names
          if [[ -z "$event_name" || "$event_name" == *"Focus"* ]]; then
            continue
          fi

          event_start=$(echo "$event" | jq -r '.start.dateTime // .start.date')
          event_end=$(echo "$event" | jq -r '.end.dateTime // .end.date')

          if [[ "$event_start" == *"T"* ]]; then
            # Timed event: Extract and format times
            if [[ "$(uname)" == "Darwin" ]]; then
              event_start_time=$(gdate -d "$event_start" +"%H:%M")
              event_end_time=$(gdate -d "$event_end" +"%H:%M")
              start_epoch=$(gdate -d "$event_start" +%s)
              end_epoch=$(gdate -d "$event_end" +%s)
            else
              event_start_time=$(date -d "$event_start" +"%H:%M")
              event_end_time=$(date -d "$event_end" +"%H:%M")
              start_epoch=$(date -d "$event_start" +%s)
              end_epoch=$(date -d "$event_end" +%s)
            fi

            # Calculate duration in hours and minutes
            duration_in_seconds=$(( end_epoch - start_epoch ))
            event_duration_hours=$(( duration_in_seconds / 3600 ))
            event_duration_minutes=$(( (duration_in_seconds % 3600) / 60 ))

            # Add duration to total_event_duration (in hours)
            export total_event_duration=$((total_event_duration + event_duration_hours))

            # Format the duration string
            if (( event_duration_hours > 0 )) && (( event_duration_minutes > 0 )); then
                duration_text="$event_duration_hours tunti$( [ "$event_duration_hours" -gt 1 ] && echo "a" ) $event_duration_minutes minuuttia"
            elif (( event_duration_hours > 0 )); then
                duration_text="$event_duration_hours tunti$( [ "$event_duration_hours" -gt 1 ] && echo "a" )"
            elif (( event_duration_minutes > 0 )); then
                duration_text="$event_duration_minutes minuuttia"
            else
                duration_text="0 minuuttia"
            fi

            # Count all events except "Lounas" or events that contain "Focus"
            if [[ "$event_name" != *"Lounas"* || "$event_name" != *"Focus"* ]]; then
              event_count=$((event_count + 1))
            fi

            # Add to events list with time details
            all_events+="- $event_name (klo $event_start_time-$event_end_time, kesto $duration_text)\n"
          else
            # All-day event
            all_events+="- $event_name (koko päivän)\n"
          fi
        done <<< "$(echo "$calendar_events" | jq -c '.items[]')"
      fi
    done

    # Calculate remaining work hours (assuming an 8-hour workday)
    export total_work_hours=8
    export remaining_work_hours=$((total_work_hours - total_event_duration))

    # Output formatted events and total summary
    echo -e "${BOLD}${CYAN}Tämän päivän tapahtumat:${RESET}\n$all_events"
    echo -e "Yhteensä tapaamisia tänään $total_event_duration tuntia (mukaanlukien lounas)."
    echo -e "Päivässä aikaa tehtävien suorittamiseen jäljellä yhteensä $remaining_work_hours tuntia."
    echo -e "Palaverien määrä tänään: $event_count."

    # Export all events to make sure they are included in the prompt
    export all_events="$all_events"

  done
}

list_today_events
