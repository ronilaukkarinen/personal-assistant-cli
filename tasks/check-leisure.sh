# Function: Determine whether it's work time or leisure time
is_leisure_time() {
  local current_day
  local current_hour

  # Get the current day passed with: if is_leisure_time "$current_day"
  current_day=$1

  # Get the current hour (24-hour format)
  current_hour=$(date +%H)

  # Determine if it's leisure time:
  # - Weekdays (Monday to Friday) after 18:00
  # - Weekends (Friday after 18:00 until Monday 00:00)
  if ((current_day >= 1 && current_day <= 5 && current_hour >= 18)) || \
     ((current_day == 5 && current_hour >= 18)) || \
     ((current_day == 6)) || \
     ((current_day == 7 && current_hour < 24)); then
    # Zero in bash means true
    return 0
  else
    # Non-zero in bash means false
    return 1
  fi
}

# Function: Check if it's weekend
is_weekend() {
  local current_day

  # Get the current day passed with: if is_weekend "$current_day"
  current_day=$1

  # If it's Saturday or Sunday, return true
  if ((current_day == 6)) || ((current_day == 7)); then
    # Zero in bash means true
    return 0
  else
    # Non-zero in bash means false
    return 1
  fi
}

# Function: Check if it's holiday
is_holiday() {
  local today
  local current_day

  # Get the current day passed with: if is_holiday "$current_day"
  current_day=$1

  # Check if the events contain keywords for holidays
  if [[ "$events" == *"loma"* || "$events" == *"joulu"* || "$events" == *"vapaa"* ]]; then
    # Zero in bash means true
    return 0
  else
    # Non-zero in bash means false
    return 1
  fi
}
