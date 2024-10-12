#!/bin/bash
# Load API keys from `.env` file
source .env

TODOIST_API_KEY=${TODOIST_API_KEY}
OPENAI_API_KEY=${OPENAI_API_KEY}
GOOGLE_CLIENT_ID=${GOOGLE_CLIENT_ID}
GOOGLE_CLIENT_SECRET=${GOOGLE_CLIENT_SECRET}
WORK_PROMPT=${WORK_PROMPT}
LEISURE_PROMPT=${LEISURE_PROMPT}

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

# Define the work project name
WORK_PROJECT="Todo"
DELAYED_LABEL="Lykätyt"  # Label name for delayed tasks

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

  # Count subtasks for each task in Bash
  subtask_counts=$(echo "$tasks" | jq -r '[.[] | select(.parent_id != null) | .parent_id] | group_by(.) | map({(.[0]): length}) | add')

  # Filter tasks based on whether it's work time or leisure time
  if is_leisure_time; then
    # Fetch all tasks for leisure time
    echo "$tasks" | jq -r --arg today "$today" --argjson project_map "$project_map" --argjson subtask_counts "$subtask_counts" '
      .[] | select(.due.date == $today) |
      .project_name = ($project_map[.project_id | tostring] // "Muu projekti") |
      # Assign pre-calculated subtask count, defaulting to 0 if null
      .subtask_count = ($subtask_counts[.id] // 0) |
      "- ID: " + .id + " - " + .content + " (" + .project_name + ")" +
      (if .labels | length > 0 then " (Labels: " + (.labels | join(", ")) + ")" else "" end) +
      " (Alatehtäviä: \(.subtask_count))"'
  else
    # Fetch only tasks from the work project during work time
    echo "$tasks" | jq -r --arg today "$today" --argjson project_map "$project_map" --argjson subtask_counts "$subtask_counts" --arg WORK_PROJECT "$WORK_PROJECT" '
      .[] | select(.due.date == $today and .project_name == $WORK_PROJECT) |
      .project_name = ($project_map[.project_id | tostring] // "Muu projekti") |
      # Assign pre-calculated subtask count, defaulting to 0 if null
      .subtask_count = ($subtask_counts[.id] // 0) |
      "- ID: " + .id + " - " + .content + " (" + .project_name + ")" +
      (if .labels | length > 0 then " (Labels: " + (.labels | join(", ")) + ")" else "" end) +
      " (Alatehtäviä: \(.subtask_count))"'
  fi
}

# Function: Fetch today's Google Calendar events from a specific calendar
fetch_calendar_events() {
  local today
  today=$(date +%Y-%m-%d)

  # Fetch events from the specific calendar and print raw output if debug flag is enabled
  calendar_output=$(gcalcli --nocolor --calendar "Roni Laukkarinen (Rollen työkalenteri)" agenda "$today" "$today 23:00" --details length 2>&1)

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

# Function: Ensure that the "Lykätyt" label exists and get its ID
ensure_delayed_label() {
  local delayed_label_id

  # Fetch all labels
  labels=$(curl -s --request GET \
    --url "https://api.todoist.com/rest/v2/labels" \
    --header "Authorization: Bearer ${TODOIST_API_KEY}")

  # Check if "Lykätyt" label already exists
  delayed_label_id=$(echo "$labels" | jq -r '.[] | select(.name == "Lykätyt") | .id')

  # If not found, create the "Lykätyt" label
  if [[ -z "$delayed_label_id" ]]; then
    delayed_label_id=$(curl -s --request POST \
      --url "https://api.todoist.com/rest/v2/labels" \
      --header "Content-Type: application/json" \
      --header "Authorization: Bearer ${TODOIST_API_KEY}" \
      --data '{"name": "Lykätyt"}' | jq -r '.id')
    echo "Label 'Lykätyt' luotiin."
  fi

  echo "$delayed_label_id"
}

# Function: Delay a task to the next day and add a "Lykätyt" label
delay_task() {
  local task_id="$1"
  local delayed_label_id="$2"
  local next_day
  next_day=$(date -d "tomorrow" +%Y-%m-%d)  # Calculate next day date

  # Get existing labels and task name for the task
  task_data=$(curl -s --request GET \
    --url "https://api.todoist.com/rest/v2/tasks/$task_id" \
    --header "Authorization: Bearer ${TODOIST_API_KEY}")

  task_name=$(echo "$task_data" | jq -r '.content')
  current_labels=$(echo "$task_data" | jq -r '.labels')

  # Add "Lykätyt" label if not already present
  if [[ "$current_labels" != *"$delayed_label_id"* ]]; then
    # Merge the current labels with the "Lykätyt" label ID
    current_labels=$(echo "$current_labels" | jq --arg delayed "$delayed_label_id" '. += [$delayed]')
  fi

  # Update the task's due date and labels
  curl -s --request POST \
    --url "https://api.todoist.com/rest/v2/tasks/$task_id" \
    --header "Content-Type: application/json" \
    --header "Authorization: Bearer ${TODOIST_API_KEY}" \
    --data "{\"due_date\": \"$next_day\", \"labels\": $current_labels}" >/dev/null

  # Print the task ID and name when the task is delayed
  echo -e "${YELLOW}Tehtävä siirretty: $task_name (ID: $task_id)${RESET}"
}

# Function: Call OpenAI to create detailed notes
get_notes() {
  local tasks="$1"
  local events="$2"
  local is_work="$3" # Boolean flag to indicate if these are work tasks

  if [ -z "$tasks" ]; then
    echo -e "${BOLD}${RED}Ei tämänpäiväisiä tehtäviä Todoistissa.${RESET}"
    exit 0
  fi

  # Select the appropriate prompt based on whether tasks are work-related or personal
  if [[ "$is_work" == "true" ]]; then
    prompt="$WORK_PROMPT"
  else
    prompt="$LEISURE_PROMPT"
  fi

  # Construct the JSON payload for note creation
  json_payload=$(jq -n --arg prompt "$PROMPT" --arg tasks "$tasks" --arg events "$events" '{
      "model": "gpt-4",
      "messages": [
        {"role": "system", "content": "Sinä olet tehtävien priorisoija."},
        {"role": "user", "content": ($prompt + "\n\nTässä on tämänpäiväiset tehtävät:\n" + $tasks + "\n\nTässä ovat päivän kalenteritapahtumat:\n" + $events + "\n\nKirjoita yksityiskohtaiset muistiinpanot, joissa selität, miksi tietyt tehtävät ovat tärkeitä ja mitkä tehtävät voidaan siirtää tai delegoida.") }
      ],
      "max_tokens": 3000,
      "temperature": 0.5
  }')

  # Make API call to OpenAI for note creation
  response=$(curl -s --request POST \
    --url "https://api.openai.com/v1/chat/completions" \
    --header "Content-Type: application/json" \
    --header "Authorization: Bearer ${OPENAI_API_KEY}" \
    --data "$json_payload")

  # Parse response
  echo "$response" | jq -r '.choices[0].message.content // "Ei tuloksia"'
}

# Function: Call OpenAI to prioritize tasks and suggest which tasks to delay
get_priorities() {
  local tasks="$1"
  local events="$2"
  local is_work="$3" # Boolean flag to indicate if these are work tasks

  if [ -z "$tasks" ]; then
    echo -e "${BOLD}${RED}Ei tämänpäiväisiä tehtäviä Todoistissa.${RESET}"
    exit 0
  fi

  # Select the appropriate prompt based on whether tasks are work-related or personal
  if [[ "$is_work" == "true" ]]; then
    prompt="$WORK_PROMPT"
  else
    prompt="$LEISURE_PROMPT"
  fi

  # Construct the JSON payload with proper quoting
  json_payload=$(jq -n --arg prompt "$PROMPT" --arg tasks "$tasks" --arg events "$events" '{
      "model": "gpt-4",
      "messages": [
        {"role": "system", "content": "Sinä olet tehtävien priorisoija."},
        {"role": "user", "content": ($prompt + "\n\nTässä on tämänpäiväiset tehtävät (mukana ID:t):\n" + $tasks + "\n\nTässä ovat päivän kalenteritapahtumat:\n" + $events + "\n\nMerkitse ne tehtävät, jotka tulisi siirtää seuraavalle päivälle, lisäämällä niiden perään \"siirretty seuraavalle päivälle\". Jos tehtäviä ei tarvitse siirtää, älä lisää mitään.") }
      ],
      "max_tokens": 3000,
      "temperature": 0.5
  }')

  # Make API call to OpenAI
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

  echo -e "${BOLD}${GREEN}Tämänpäiväiset tehtävät ja kalenteritapahtumat:${RESET}\n$tasks\n\n$events\n"

  # Prioritize tasks and get AI's feedback
  echo -e "${BOLD}${YELLOW}Priorisoidaan tehtävät ja palaverit OpenAI:n avulla...${RESET}"
  priorities=$(get_priorities "$tasks" "$events" "$is_work")

  # Show AI's output in terminal
  echo -e "${BOLD}${GREEN}Priorisoidut tehtävät:${RESET}\n$priorities"

  # Ensure the "Delayed" label exists and get its ID
  delayed_label_id=$(ensure_delayed_label)

  # Save output to Obsidian vault
  date_filename=$(date "+%Y-%m-%d_%H-%M-%S")
  date_header=$(date "+%d.%m.%Y")

  # Get detailed notes from OpenAI
  echo -e "${BOLD}${YELLOW}Luodaan yksityiskohtaiset muistiinpanot...${RESET}"
  notes=$(get_notes "$tasks" "$events")

  # Show AI's detailed notes output in terminal
  echo -e "${BOLD}${GREEN}Muistiinpanot:${RESET}\n$notes"

  # Append detailed notes to the same Obsidian file
  echo -e "\n\n## Yksityiskohtaiset muistiinpanot\n\n$notes" >> "$HOME/Documents/Brain dump/Päivän suunnittelu/$date_filename.md"

  echo -e "${BOLD}${YELLOW}Muistiinpanot on tallennettu Obsidian-vaultiin.${RESET}"

  # Choose to be delayed tasks based on the AI response
  task_ids_to_delay=$(echo "$priorities" | grep -oE 'ID: [0-9]+.*siirretty seuraavalle päivälle' | awk '{print $2}')

  # Moving those tasks to the next day that AI suggested
  if [[ -n "$task_ids_to_delay" ]]; then
    echo -e "${BOLD}${YELLOW}Siirretään AI:n suosittelemat tehtävät seuraavalle päivälle...${RESET}"
    for task_id in $task_ids_to_delay; do
      # Tarkistetaan, että tehtävä on todella siirrettävissä
      task_due_date=$(curl -s --request GET \
        --url "https://api.todoist.com/rest/v2/tasks/$task_id" \
        --header "Authorization: Bearer ${TODOIST_API_KEY}" | jq -r '.due.date')

      if [[ "$task_due_date" == $(date +%Y-%m-%d) ]]; then
        delay_task "$task_id" "$delayed_label_id"
        echo -e "${YELLOW}Tehtävä siirretty: $task_id${RESET}"
      else
        echo -e "${YELLOW}Tehtävää $task_id ei voitu siirtää, koska se ei ole tälle päivälle ajoitettu.${RESET}"
      fi
    done
  else
    echo -e "${BOLD}${CYAN}AI ei suositellut tehtävien siirtämistä.${RESET}"
  fi
}

# Run the script
main "$@"
