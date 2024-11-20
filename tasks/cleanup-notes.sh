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
  file_path="$HOME/Documents/Brain dump/Päivän suunnittelu/$filename.md"
  cleanup_notes "$file_path"
fi
