# Function: Calculate remaining hours in the day
calculate_remaining_hours() {
  local current_hour
  local current_minute
  local remaining_hours

  # Get the current time in 24-hour format
  if [[ "$(uname)" == "Darwin" ]]; then
    if ! command -v gdate >/dev/null 2>&1; then
      logger -t "calculate-hours" "Error: gdate not found. Please install coreutils."
      exit 1  # Exit explicitly instead of return for cron
    fi
    current_hour=$(gdate "+%H") || { logger -t "calculate-hours" "Failed to get hour"; exit 1; }
    current_minute=$(gdate "+%M") || { logger -t "calculate-hours" "Failed to get minute"; exit 1; }
  else
    current_hour=$(date "+%H") || { logger -t "calculate-hours" "Failed to get hour"; exit 1; }
    current_minute=$(date "+%M") || { logger -t "calculate-hours" "Failed to get minute"; exit 1; }
  fi

  # Validate hour format
  if ! [[ "$current_hour" =~ ^[0-9]+$ ]] || [ "$current_hour" -gt 23 ]; then
    logger -t "calculate-hours" "Error: Invalid hour format: $current_hour"
    exit 1
  fi

  # Calculate remaining hours, accounting for minutes
  if [ "$current_minute" -gt 0 ]; then
    remaining_hours=$((23 - current_hour))
  else
    remaining_hours=$((24 - current_hour))
  fi

  # Validate result
  if [[ "$remaining_hours" -ge 0 && "$remaining_hours" -le 24 ]]; then
    echo "$remaining_hours"
    exit 0
  else
    logger -t "calculate-hours" "Error: Invalid calculation result: $remaining_hours"
    exit 1
  fi
}
