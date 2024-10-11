#!/bin/bash
# Load API keys from `.env` file
source .env

TODOIST_API_KEY=${TODOIST_API_KEY}
OPENAI_API_KEY=${OPENAI_API_KEY}
GOOGLE_CLIENT_ID=${GOOGLE_CLIENT_ID}
GOOGLE_CLIENT_SECRET=${GOOGLE_CLIENT_SECRET}
PROMPT=${PROMPT}

# Define color codes for formatting
BOLD=$(tput bold)
RESET=$(tput sgr0)
GREEN=$(tput setaf 2)
YELLOW=$(tput setaf 3)
RED=$(tput setaf 1)
CYAN=$(tput setaf 6)

# Parse command-line arguments for --debug flag
DEBUG=false
for arg in "$@"; do
  if [ "$arg" == "--debug" ]; then
    DEBUG=true
  fi
done

# If not debian based or macOS, exit
if [ "$(uname)" != "Darwin" ] && [ "$(uname)" != "Linux" ]; then
  echo "This script only supports macOS and debian based Linux."
  exit 1
fi

# Check if jq is installed, install it for the user if not
if ! command -v jq &> /dev/null; then
  # If macOS
  if [ "$(uname)" == "Darwin" ]; then
    brew install jq
  else
    # If Linux
    sudo apt-get install jq
  fi
fi

# Check if curl is installed, install it for the user if not
if ! command -v curl &> /dev/null; then
  # If macOS
  if [ "$(uname)" == "Darwin" ]; then
    brew install curl
  else
    # If Linux
    sudo apt-get install curl
  fi
fi

# Check if gcalcli is installed, install it for the user if not
if ! command -v gcalcli &> /dev/null; then
  # If macOS
  if [ "$(uname)" == "Darwin" ]; then
    brew install gcalcli
  else
    # If Linux
    sudo apt-get install gcalcli
  fi
fi

# Leave empty if all tasks should be fetched
SELECTED_PROJECT="Todo"

# Function: Fetch today's tasks from Todoist, including project names and subtask count
fetch_tasks() {
  local today
  today=$(date +%Y-%m-%d)  # Get today's date in YYYY-MM-DD format

  # Fetch tasks from Todoist API
  tasks=$(curl -s --request GET \
    --url "https://api.todoist.com/rest/v2/tasks" \
    --header "Authorization: Bearer ${TODOIST_API_KEY}")

  # Fetch projects from Todoist API
  projects=$(curl -s --request GET \
    --url "https://api.todoist.com/rest/v2/projects" \
    --header "Authorization: Bearer ${TODOIST_API_KEY}")

  # Create a map of project_id -> project_name
  project_map=$(echo "$projects" | jq -r 'map({( .id | tostring ): .name}) | add')

  # Lasketaan alatehtävien määrä jokaiselle tehtävälle Bashissa
  # Haetaan kaikki parent_id:t ja lasketaan, montako kertaa jokainen id esiintyy parent_id:nä
  subtask_counts=$(echo "$tasks" | jq -r '[.[] | select(.parent_id != null) | .parent_id] | group_by(.) | map({(.[0]): length}) | add')

  # Lisää laskettu alatehtävien määrä jokaiseen tehtävään käyttäen `jq`-liitosta
  echo "$tasks" | jq -r --arg today "$today" --argjson project_map "$project_map" --argjson subtask_counts "$subtask_counts" --arg selected_project "$SELECTED_PROJECT" '
    .[] | select(.due.date == $today) |
    .project_name = ($project_map[.project_id | tostring] // "Muu projekti") |
    # Change "Todo" project name to "Työasiat"
    .project_name = (if .project_name == "Todo" then "Työasiat" else .project_name end) |
    # Filter based on selected project if provided (original project name)
    select(
      ($selected_project == "") or
      (.project_name == $selected_project or ($selected_project == "Todo" and .project_name == "Työasiat"))
    ) |
    # Assign pre-calculated subtask count
    .subtask_count = ($subtask_counts[.id] // 0) |
    "- " + .content + " (" + .project_name + ")" +
    (if .labels | length > 0 then " (Labels: " + (.labels | join(", ")) + ")" else "" end) +
    " (Tehtävän laajuus, eli alatehtävien määrä tälle: \(.subtask_count))"'
}

# Function: Fetch today's Google Calendar events from a specific calendar
fetch_calendar_events() {
  local today
  today=$(date +%Y-%m-%d)

  # Fetch events from the specific calendar and print raw output if debug flag is enabled
  calendar_output=$(gcalcli --nocolor --calendar "Roni Laukkarinen (Rollen työkalenteri)" agenda "$today" "$today 23:00" 2>&1)

  # If debug mode is enabled, show raw gcalcli output
  if [ "$DEBUG" = true ]; then
    echo -e "${BOLD}${CYAN}Raaka gcalcli-vastaus:${RESET}\n$calendar_output\n"
  fi

  # Check for API errors
  if [[ "$calendar_output" == *"Invalid Credentials"* ]]; then
    echo -e "${BOLD}${RED}Virhe: Google Calendar API -avaimet ovat virheelliset tai puuttuvat.${RESET}"
    exit 1
  elif [[ "$calendar_output" == *"No calendars found"* ]]; then
    echo -e "${BOLD}${RED}Virhe: Google Calendar -tilillä ei ole saatavilla olevia kalentereita.${RESET}"
    exit 1
  elif [[ "$calendar_output" == "" ]]; then
    echo -e "${BOLD}${RED}Virhe: Google Calendar API ei palauttanut mitään tapahtumia. Tarkista internet-yhteys tai API-avaimet.${RESET}"
    exit 1
  fi

  # Output all calendar events (no filtering)
  echo "$calendar_output"
}

# Function: Send task list to OpenAI and get prioritized tasks using the chat model
get_priorities() {
  local tasks="$1"
  local events="$2"

  if [ -z "$tasks" ]; then
    echo -e "${BOLD}${RED}Ei tämänpäiväisiä tehtäviä Todoistissa.${RESET}"
    exit 0
  fi

  # Combine Todoist tasks and Google Calendar events
  combined_tasks="$tasks\n\nPäivän kalenteritapahtumat:\n$events"

  # Escape the tasks string for JSON format using jq
  escaped_tasks=$(echo "$tasks" | jq -Rs .)

  # Create the JSON payload
  json_payload=$(jq -n --arg prompt "$PROMPT" --arg tasks "$tasks" --arg events "$events" '{
      "model": "gpt-4",
      "messages": [{"role": "system", "content": "Sinä olet tehtävien priorisoija."},
                   {"role": "user", "content": ($prompt + "\n\nTässä on tämänpäiväiset tehtävät:\n" + $tasks + "\n\nTässä ovat päivän kalenteritapahtumat:\n" + $events)}],
      "max_tokens": 500,
      "temperature": 0.5
    }')

  # Make API call to OpenAI with the given message structure
  response=$(curl -s --request POST \
    --url "https://api.openai.com/v1/chat/completions" \
    --header "Content-Type: application/json" \
    --header "Authorization: Bearer ${OPENAI_API_KEY}" \
    --data "$json_payload")

  # If debug flag is enabled, print the raw response
  if [ "$DEBUG" = true ]; then
    echo -e "${BOLD}${CYAN}Raaka OpenAI-vastaus:${RESET}\n$response\n"
  fi

  # Parse response to extract the generated text and check if the response is complete
  local content_part=$(echo "$response" | jq -r '.choices[0].message.content // ""')
  local finish_reason=$(echo "$response" | jq -r '.choices[0].finish_reason // ""')

  # Continue fetching until the response is complete
  while [ "$finish_reason" != "stop" ]; do
    #echo -e "${BOLD}${YELLOW}Vastaus jatkuu, haetaan lisää...${RESET}"

    # Create the JSON payload
    json_payload=$(jq -n --arg content "$content_part" '{
        "model": "gpt-4",
        "messages": [{"role": "user", "content": $content}],
        "max_tokens": 500,
        "temperature": 0.5
      }')

    # Make API call to OpenAI
    response=$(curl -s --request POST \
      --url "https://api.openai.com/v1/chat/completions" \
      --header "Content-Type: application/json" \
      --header "Authorization: Bearer ${OPENAI_API_KEY}" \
      --data "$json_payload")

    # Parse response
    echo "$response" | jq -r '.choices[0].message.content // "Ei tuloksia"'
  done

  # Add basic bold formatting to keywords or task headers
  formatted_text=$(echo "$content_part" | sed 's/Tärkeimmät tehtävät:/\*\*Tärkeimmät tehtävät:\*\*/g; s/\([0-9]\+\.\)/\*\1\*/g')

  # Return formatted text
  echo "$formatted_text"
}

# Main function
main() {
  echo -e "${BOLD}${YELLOW}Haetaan tämänpäiväiset Todoist-tehtävät...${RESET}"
  tasks=$(fetch_tasks)

  echo -e "${BOLD}${YELLOW}Haetaan tämänpäiväiset Google Calendar -tapahtumat...${RESET}"
  events=$(fetch_calendar_events)

  if [ -z "$events" ]; then
    echo -e "${BOLD}${RED}Ei tämänpäiväisiä kalenteritapahtumia Google Calendarissa.${RESET}"
  fi

  if [ -z "$tasks" ] && [ -z "$events" ]; then
    exit 1
  fi

  echo -e "${BOLD}${GREEN}Tämänpäiväiset tehtävät ja kalenteritapahtumat:${RESET}\n$tasks\n\n$events\n"

  echo -e "${BOLD}${YELLOW}Priorisoidaan tehtävät ja palaverit OpenAI:n avulla...${RESET}"
  priorities=$(get_priorities "$tasks" "$events")

  echo -e "${BOLD}${GREEN}Priorisoidut tehtävät ja asiat:${RESET}\n$priorities\n"

  # Save output to Obsidian vault
  date_filename=$(date "+%Y-%m-%d_%H-%M-%S")
  date_header=$(date "+%d.%m.%Y")

  echo -e "# $date_header\n\n$priorities" > "$HOME/Documents/Brain dump/Päivän suunnittelu/$date_filename.md"

  echo -e "${BOLD}${GREEN}Priorisointi on valmis ja tallennettu Obsidian-vaultiin.${RESET}"
}

# Run the script
main "$@"
