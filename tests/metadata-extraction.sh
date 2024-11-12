#!/bin/bash

# Tester function: Extract task IDs that are more than 5 digits from the notes
test_metadata_extraction() {
  local test_file="testnote.md"

  if [[ ! -f "$test_file" ]]; then
    echo "Error: testnote.md not found."
    exit 1
  fi

  # Read the file content
  priorities=$(<"$test_file")

  # Extract all numbers with more than 5 digits, which we assume to be task IDs
  task_ids_to_schedule=$(echo "$priorities" | grep -oP '\b[0-9]{6,}\b')

  if [[ -n "$task_ids_to_schedule" ]]; then
    echo "Found the following task IDs for scheduling:"
    echo "$task_ids_to_schedule"

    # Loop through each task and extract duration and datetime
    for task_id in $task_ids_to_schedule; do
      # Search for the metadata that contains duration and datetime for this task ID
      metadata_line=$(echo "$priorities" | grep -P "Metadata:.*id:\s*\"$task_id\"")

      if [[ -n "$metadata_line" ]]; then
        # Extract duration and datetime from the metadata line
        duration=$(echo "$metadata_line" | grep -oP 'duration:\s*"\K[^"]+')
        datetime=$(echo "$metadata_line" | grep -oP 'datetime:\s*"\K[^"]+')

        # If either duration or datetime is missing, display an error
        if [[ -z "$duration" || -z "$datetime" ]]; then
          echo "Error: Missing duration or datetime for task ID $task_id"
        else
          echo "Task ID: $task_id | Duration: $duration minutes | Datetime: $datetime"
        fi
      else
        echo "Error: Metadata not found for task ID $task_id"
      fi
    done
  else
    echo "No task IDs found in the file."
  fi
}

# Run the tester
test_metadata_extraction
