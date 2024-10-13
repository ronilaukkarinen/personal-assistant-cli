# Function: Calculate remaining hours in the day
calculate_remaining_hours() {
  local current_hour
  local end_of_day=24  # The end of the day is at midnight (24:00)
  current_hour=$(date +%H)  # Get the current hour (24-hour format)
  remaining_hours=$((end_of_day - current_hour))  # Calculate remaining hours
  echo "$remaining_hours"
}
