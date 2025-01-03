#!/bin/bash

# Function to clean up metadata from notes by removing "(Metadata: ...)"
cleanup_notes() {
  local file="$1"
  local cleaned_notes=""

  # Ensure the file exists before attempting to clean it
  if [ ! -f "$file" ]; then
    echo "File not found: $file"
    return
  fi

  # Use sed to remove only the "(Metadata: ...)" part, leaving the rest intact
  cleaned_notes=$(sed 's/(Metadata:.*)//g' "$file")

  # Debugging: Display cleaned notes if in DEBUG mode
  if [ "$DEBUG" = true ]; then
    echo -e "${GREEN}Cleaned notes for $file:${RESET}\n$cleaned_notes"
  fi

  # Overwrite the original file with cleaned notes
  echo "$cleaned_notes" > "$file"
}

# Determine the appropriate date command for macOS (Darwin) or other systems
if [[ "$(uname)" == "Darwin" ]]; then
  date_cmd="gdate"
else
  date_cmd="date"
fi

# Get month as two digits and written name
month_num=$($date_cmd "+%m")
month=$($date_cmd "+%B" | tr '[:upper:]' '[:lower:]')

# Determine file paths based on the existence of start and end dates
if [ -n "$start_day" ] && [ -n "$end_day" ]; then
  # Multi-day file format
  file_path="$HOME/Documents/Brain dump/Päivän suunnittelu/${start_day}-${end_day} (useampi päivä).md"
  cleanup_notes "$file_path"
else
  # Single-day file format
  if [[ "$(uname)" == "Darwin" ]]; then
    filename=$(gdate -d "${start_day:-$(gdate "+%Y-%m-%d")}" "+%Y-%m-%d")
  else
    filename=$(date -d "${start_day:-$(date "+%Y-%m-%d")}" "+%Y-%m-%d")
  fi
  # Create directory structure
  year=$($date_cmd "+%Y")
  month_num=$($date_cmd "+%m")
  mkdir -p "$HOME/Documents/Brain dump/Päivän suunnittelu/$year/$month_num"

  # Set file path with proper date format
  if [[ "$(uname)" == "Darwin" ]]; then
    # macOS version
    file_path="$HOME/Documents/Brain dump/Päivän suunnittelu/$year/$month_num/$($date_cmd "%-d.%-m.%Y").md"
  else
    # Linux version - remove leading zeros with sed
    day=$($date_cmd -d "$start_day" "+%d" | sed 's/^0//')
    month=$($date_cmd -d "$start_day" "+%m" | sed 's/^0//')
    file_path="$HOME/Documents/Brain dump/Päivän suunnittelu/$year/$month_num/${day}.${month}.$($date_cmd -d "$start_day" "+%Y").md"
  fi
  cleanup_notes "$file_path"
fi
