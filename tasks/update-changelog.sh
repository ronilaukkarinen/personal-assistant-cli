#!/bin/bash

# Function: Update and anonymize changelog
update_changelog() {
  # Get absolute path of the script
  script_path=$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)

  # Eliminate possible /tasks from the path
  script_path=${script_path%/tasks}

  # Get .env
  source "$script_path/.env"

  # Define color codes for formatting, only if we have a terminal
  if [ -t 1 ]; then
    export TERM=xterm-256color
    BOLD=$(tput bold)
    RESET=$(tput sgr0)
    GREEN=$(tput setaf 2)
    YELLOW=$(tput setaf 3)
    RED=$(tput setaf 1)
    CYAN=$(tput setaf 6)
  else
    # No terminal, no colors
    BOLD=""
    RESET=""
    GREEN=""
    YELLOW=""
    RED=""
    CYAN=""
  fi

  # Debug mode (can be set with --debug flag)
  DEBUG=${DEBUG:-false}

  # Paths
  private_changelog="$HOME/Documents/Brain dump/CHANGELOG.md"
  public_changelog="$HOME/changelog/CHANGELOG.md"

  # Create directory if it doesn't exist
  mkdir -p "$(dirname "$public_changelog")"

  # Check if private changelog exists
  if [ ! -f "$private_changelog" ]; then
    echo -e "${RED}Error: Private changelog not found at $private_changelog${RESET}"
    exit 1
  fi

  echo -e "${YELLOW}Reading private changelog...${RESET}"

  # Read the private changelog
  changelog_content=$(cat "$private_changelog")

  # Create the anonymization prompt
  anonymization_prompt="Please anonymize the following changelog entries by:
  1. Replacing specific project names with generic terms (e.g., 'Project A', 'Client B')
  2. Replacing people's names with roles or aliases (e.g., 'colleague', 'client')
  3. Keeping technical details, dates, and version numbers intact
  4. Maintaining the original markdown structure and formatting
  5. Preserving all version numbers and dates exactly as they are
  6. Keeping all bullet points and indentation
  7. Only modifying content that could identify specific people, projects, or organizations
  8. Start directly from the version information with heading 3 ###
  9. Remove extra information from the start like heading 1 or 2 or metadata like stickers

  The example form of the CHANGELOG.md file is (please note, it starts with version information without any main headings or anything else, DO NOT even include Changelog heading or description):

  ### 1.0.0: 2025-01-08

  * Initial release: Life 1.0
  * 2.86 km daily run
  * Open changelog
  * Monthly meeting at 1pm with team members
  * After huddle with team members
  * Image load from CDN issue, new task: T-24103
  * Release, T-21730
  * Longer lunch with a colleague

  Here's the changelog content to anonymize:

  $changelog_content"

  echo -e "${YELLOW}Sending to OpenAI for anonymization...${RESET}"

  # Create JSON payload for OpenAI API
  json_payload=$(jq -n \
    --arg prompt "$anonymization_prompt" \
    '{
      "model": "gpt-4o-mini",
      "messages": [
        {"role": "system", "content": "You are a changelog anonymizer that maintains technical accuracy while protecting privacy."},
        {"role": "user", "content": $prompt}
      ],
      "max_tokens": 16000,
      "temperature": 0.7
    }')

  # Call OpenAI API
  response=$(curl -s --request POST \
    --url "https://api.openai.com/v1/chat/completions" \
    --header "Content-Type: application/json" \
    --header "Authorization: Bearer ${OPENAI_API_KEY}" \
    --data "$json_payload")

  # Check for API errors
  if [[ "$response" == *"error"* ]]; then
    echo -e "${RED}Error: OpenAI API request failed${RESET}"
    echo "$response"
    exit 1
  fi

  # Extract anonymized content
  anonymized_content=$(echo "$response" | jq -r '.choices[0].message.content')

  # Write to public changelog, overwriting existing content
  echo "$anonymized_content" > "$public_changelog"

  echo -e "${GREEN}Successfully updated public changelog at $public_changelog${RESET}"

  # Debug info if --debug flag is present
  if [ "$DEBUG" = true ]; then
    echo -e "\n${CYAN}Debug: Original content length: $(echo "$changelog_content" | wc -l) lines${RESET}"
    echo -e "${CYAN}Debug: Anonymized content length: $(echo "$anonymized_content" | wc -l) lines${RESET}"
  fi
}

# Parse command line arguments
while [[ "$#" -gt 0 ]]; do
  case $1 in
    --debug) DEBUG=true ;;
    *) echo "Unknown parameter: $1"; exit 1 ;;
  esac
  shift
done

# Run the function
update_changelog
