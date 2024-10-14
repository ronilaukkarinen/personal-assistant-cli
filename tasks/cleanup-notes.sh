# Function: Cleanup notes by removing task IDs and metadata, while preserving the original text
cleanup_notes() {
  local notes="$1"
  local cleaned_notes=""

  # Remove patterns like "ID: [number]" and "(ID: [number])", including "(Metadata: ...)"
  cleaned_notes=$(echo "$notes" | sed -E 's/\(ID: [0-9]{5,}\)//g' \
                                    | sed -E 's/ID: [0-9]{5,}//g' \
                                    | sed -E 's/\([0-9]{5,}\)//g' \
                                    | sed -E 's/\(Metadata:.*\)//g')

  # Ensure that original text formatting and extra dashes are not removed from the actual content
  cleaned_notes=$(echo "$cleaned_notes" | sed -E 's/\*\* - /\*\* /g')

  # Remove extra spaces left after cleaning up
  cleaned_notes=$(echo "$cleaned_notes" | sed 's/^[[:space:]]*//;s/[[:space:]]*$//')

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
