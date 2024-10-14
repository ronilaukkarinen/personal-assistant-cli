# Function: Cleanup notes by removing only (Metadata: ...) lines, while preserving the original text
cleanup_notes() {
  local notes="$1"
  local cleaned_notes=""

  # Remove the entire line containing "(Metadata: ...)"
  cleaned_notes=$(echo "$notes" | sed '/(Metadata:.*)/d')

  # Debugging: Print the cleaned version of notes before saving
  if [ "$DEBUG" = true ]; then
    echo -e "${GREEN}Cleaned notes:${RESET}\n$cleaned_notes"
  fi

  # Overwrite the original
  echo "$cleaned_notes" > "$file"
}

# Get today's notes and clean them up
notefile_format="$HOME/Documents/Brain dump/Päivän suunnittelu/$(date "+%Y-%m-%d")"

# Loop through all files that match the pattern and clean them up
find "$notefile_format"* -type f | while IFS= read -r file; do
  if [ -f "$file" ]; then
    notes=$(cat "$file")
    cleanup_notes "$notes"
  else
    echo "No files found matching the pattern: $notefile_format"
  fi
done
