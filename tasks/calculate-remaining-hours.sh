# Function: Calculate remaining hours in the day
calculate_remaining_hours() {
  local current_hour

  # Get the current hour in 24-hour format
  if [[ "$(uname)" == "Darwin" ]]; then
    current_hour=$(gdate "+%H")
  else
    current_hour=$(date "+%H")
  fi

  # Calculate remaining hours until the end of the day
  remaining_hours=$((24 - current_hour))
  echo "$remaining_hours"
}
