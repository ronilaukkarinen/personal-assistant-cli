# Function: Cleanup notes by removing only the (Metadata: ...) part from each line, preserving the original text
cleanup_notes() {
  local notes="$1"
  local cleaned_notes=""

  # Use sed to remove only the "(Metadata: ...)" part from each line, leaving the rest of the line intact
  cleaned_notes=$(echo "$notes" | sed 's/(Metadata:.*)//g')

  # Debugging: Print the cleaned version of notes before saving
  if [ "$DEBUG" = true ]; then
    echo -e "${GREEN}Cleaned notes:${RESET}\n$cleaned_notes"
  fi

  # Overwrite the original file with cleaned notes
  echo "$cleaned_notes" > "$file"
}

# Get today's notes and clean them up
# If current day is defined, use it in the file name
if [[ "$(uname)" == "Darwin" ]]; then
  notefile_format="$HOME/Documents/Brain dump/Päivän suunnittelu/$current_day.md"
else
  notefile_format="$HOME/Documents/Brain dump/Päivän suunnittelu/$(date "+%Y-%m-%d").md"
fi

# Loop through all files that match the pattern and clean them up
find "$notefile_format"* -type f | while IFS= read -r file; do
  if [ -f "$file" ]; then
    notes=$(cat "$file")
    cleanup_notes "$notes"
  else
    echo "No files found matching the pattern: $notefile_format"
  fi
done
