#!/bin/bash

# Get absolute path of the script
script_path=$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)

# Eliminate possible /tasks from the path
script_path=${script_path%/tasks}

# Get root
root_path=$(cd "$script_path/.." && pwd)

# Get .env
source "$root_path/.env"

# Import the list-events.sh script to simulate its availability
source "$root_path/tests/list-events.sh"
list_today_events

# List events
events=$all_events
echo "events: $events"

# Function: Determine whether it's work time or leisure time
is_leisure_time() {
  local current_day
  local current_hour

  # Get the current day of the week (1 = Monday, ..., 7 = Sunday)
  current_day=$(date +%u)

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
  current_day=$(date +%u)

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
  today=$(date +%Y-%m-%d)

  # Check if the events contain keywords for holidays
  if [[ "$events" == *"loma"* || "$events" == *"joulu"* || "$events" == *"vapaa"* ]]; then
    # Zero in bash means true
    return 0
  else
    # Non-zero in bash means false
    return 1
  fi
}

# Test function: is_leisure_time
test_is_leisure_time() {
  if is_leisure_time; then
    echo "Leisure time: Yes"
  else
    echo "Leisure time: No"
  fi
}

# Test function: is_weekend
test_is_weekend() {
  if is_weekend; then
    echo "Weekend: Yes"
  else
    echo "Weekend: No"
  fi
}

# Test function: is_holiday
test_is_holiday() {
  if is_holiday; then
    echo "Holiday: Yes"
  else
    echo "Holiday: No"
  fi
}

# Run tests
echo "Running time and event tests..."
test_is_leisure_time
test_is_weekend
test_is_holiday
