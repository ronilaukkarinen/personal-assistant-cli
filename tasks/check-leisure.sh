# Function: Determine whether it's work time or leisure time
is_leisure_time() {
  local current_day
  local current_hour

  current_day=$(date +%u)  # Get the current day of the week (1 = Monday, ..., 7 = Sunday)
  current_hour=$(date +%H)  # Get the current hour (24-hour format)

  # Determine if it's leisure time:
  # - Weekdays (Monday to Friday) after 18:00
  # - Weekends (Friday after 18:00 until Monday 00:00)
  if ((current_day >= 1 && current_day <= 5 && current_hour >= 18)) || \
     ((current_day == 5 && current_hour >= 18)) || \
     ((current_day == 6)) || \
     ((current_day == 7 && current_hour < 24)); then
    return 0  # It's leisure time
  else
    return 1  # It's work time
  fi
}

# Function: Check if it's weekend
is_weekend() {
  local current_day
  current_day=$(date +%u)

  # If it's Saturday or Sunday, return true
  if ((current_day == 6)) || ((current_day == 7)); then
    return 0
  else
    return 1
  fi
}

# Function: Check if it's holiday
is_holiday() {
  local today
  today=$(date +%Y-%m-%d)

  # If gcal shows "loma" or "joulu" or "vapaa" in the calendar event, return true
  if [[ $(gcalcli --nocolor --calendar "Roni Laukkarinen (Rollen työkalenteri)" agenda "$today" "$today 23:00" 2>&1) == *"loma"* ]] || \
     [[ $(gcalcli --nocolor --calendar "Roni Laukkarinen (Rollen työkalenteri)" agenda "$today" "$today 23:00" 2>&1) == *"joulu"* ]] || \
     [[ $(gcalcli --nocolor --calendar "Roni Laukkarinen (Rollen työkalenteri)" agenda "$today" "$today 23:00" 2>&1) == *"vapaa"* ]]; then
    return 0
  else
    return 1
  fi
}
