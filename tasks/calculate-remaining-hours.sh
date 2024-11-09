# Function: Calculate remaining hours in the day
calculate_remaining_hours() {
  local current_hour
  local remaining_hours

  # Get the current hour in 24-hour format
  if [[ "$(uname)" == "Darwin" ]]; then
    # For macOS, ensure gdate is available and use full path if needed
    if command -v gdate >/dev/null 2>&1; then
      current_hour=$(gdate "+%H")
    else
      echo "Error: gdate not found. Please install coreutils." >&2
      return 1
    fi
  else
    # For Linux, use date with explicit format
    current_hour=$(date "+%H")
  fi

  # Ensure current_hour is a number
  if ! [[ "$current_hour" =~ ^[0-9]+$ ]]; then
    echo "Error: Invalid hour format" >&2
    return 1
  fi

  # Calculate remaining hours until the end of the day
  remaining_hours=$((24 - current_hour))

  # Ensure we return a valid number
  if [[ "$remaining_hours" -ge 0 && "$remaining_hours" -le 24 ]]; then
    echo "$remaining_hours"
  else
    echo "Error: Invalid remaining hours calculation" >&2
    return 1
  fi
}
