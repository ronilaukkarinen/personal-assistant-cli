# Function: Determine whether it's work time or leisure time
is_leisure_time() {
  local input_date="$1"
  local current_hour

  # Get the day of week (1-7, where 1 is Monday)
  if [[ "$(uname)" == "Darwin" ]]; then
    current_day=$(gdate -d "$input_date" +%u)
  else
    current_day=$(date -d "$input_date" +%u)
  fi

  # Get the current hour (24-hour format)
  current_hour=$(date +%H)

  # Determine if it's leisure time:
  # - Weekdays (Monday to Friday) after 18:00
  # - Weekends (Friday after 18:00 until Monday 00:00)
  if ((current_day >= 1 && current_day <= 5 && current_hour >= 18)) || \
     ((current_day == 5 && current_hour >= 18)) || \
     ((current_day == 6)) || \
     ((current_day == 7)); then
    return 0  # True
  else
    return 1  # False
  fi
}

# Function: Check if it's weekend
is_weekend() {
  local input_date="$1"

  # Get the day of week (1-7, where 1 is Monday)
  if [[ "$(uname)" == "Darwin" ]]; then
    current_day=$(gdate -d "$input_date" +%u)
  else
    current_day=$(date -d "$input_date" +%u)
  fi

  # If it's Saturday (6) or Sunday (7), return true
  if ((current_day == 6)) || ((current_day == 7)); then
    return 0  # True
  else
    return 1  # False
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
