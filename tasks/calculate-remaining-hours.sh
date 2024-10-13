# Function: Calculate remaining hours in the day
calculate_remaining_hours() {
  local current_hour
  local end_of_day=24  # The end of the day is at midnight (24:00)

  # Check if macOS is used
  if [[ "$(uname)" == "Darwin" ]]; then
    current_hour=$(gdate "+%H")  # Get the current hour (24-hour format)
  else
    current_hour=$(date "+%H")  # Get the current hour (24-hour format)
  fi

  remaining_hours=$((end_of_day - current_hour))  # Calculate remaining hours
  echo "$remaining_hours"
}
