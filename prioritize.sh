#!/bin/bash
# Load API keys from `.env` file
source .env

TODOIST_API_KEY=${TODOIST_API_KEY}
OPENAI_API_KEY=${OPENAI_API_KEY}
GOOGLE_CLIENT_ID=${GOOGLE_CLIENT_ID}
GOOGLE_CLIENT_SECRET=${GOOGLE_CLIENT_SECRET}

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

# Function: Calculate remaining hours in the day
calculate_remaining_hours() {
  local current_hour
  local end_of_day=24  # The end of the day is at midnight (24:00)
  current_hour=$(date +%H)  # Get the current hour (24-hour format)
  remaining_hours=$((end_of_day - current_hour))  # Calculate remaining hours
  echo "$remaining_hours"
}

# Leave empty if all tasks should be fetched
if is_leisure_time; then
  SELECTED_PROJECT=""
  PROMPT_BGINFO=${LEISURE_PROMPT_BGINFO}
  PROMPT_NOTES=${LEISURE_PROMPT_NOTES}
else
  SELECTED_PROJECT="Todo"
  PROMPT_BGINFO=${WORK_PROMPT_BGINFO}
  PROMPT_NOTES=${WORK_PROMPT_NOTES}
fi

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

  # Count the number of subtasks for each task in Bash
  # Get all parent_ids and count how many times each id appears as a parent_id
  subtask_counts=$(echo "$tasks" | jq -r '[.[] | select(.parent_id != null) | .parent_id] | group_by(.) | map({(.[0]): length}) | add')

  # Add the calculated subtask count to each task using `jq` concatenation
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
    "- ID: " + .id + " - " + .content + " (" + .project_name + ")" +
      (if .labels | length > 0 then " (Labels: " + (.labels | join(", ")) + ")" else "" end) +
      " (Alatehtäviä: \(.subtask_count))"'
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

postpone_task() {
  local task_id="$1"
  local next_day
  next_day=$(date -d "tomorrow" +%Y-%m-%d)  # Calculate next day date

  # Get existing labels and task name for the task
  task_data=$(curl -s --request GET \
    --url "https://api.todoist.com/rest/v2/tasks/$task_id" \
    --header "Authorization: Bearer ${TODOIST_API_KEY}")
  task_name=$(echo "$task_data" | jq -r '.content')

  # Update the task's due date
  update_response=$(curl -s --request POST \
    --url "https://api.todoist.com/rest/v2/tasks/$task_id" \
    --header "Content-Type: application/json" \
    --header "Authorization: Bearer ${TODOIST_API_KEY}" \
    --data "{\"due_date\": \"$next_day\"}")

  # Debug
  if [ "$DEBUG" = true ]; then
    echo -e "${BOLD}${CYAN}Tehtävän päivitysvastaus:${RESET}\n$update_response\n"
  fi

  # If error occurs, print the error message
  if [[ "$update_response" == *"error"* ]]; then
    echo -e "${BOLD}${RED}Virhe: Tehtävän siirtäminen seuraavalle päivälle epäonnistui.${RESET}"
    exit 1
  else
    # Print the task ID and name when the task is postponed
    echo -e "${YELLOW}Tehtävä siirretty: $task_name (ID: $task_id)${RESET}"
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

# Function to estimate token count from word count
estimate_token_count() {
  local text="$1"
  # Estimate token count as roughly 1.33 tokens per word
  echo "$text" | wc -w | awk '{print int($1 * 1.33)}'
}

get_priorities() {
  local tasks="$1"
  local events="$2"

  # Get the current local time and remaining hours
  current_time=$(TZ=$(cat /etc/timezone) date "+%H:%M")
  remaining_hours=$(calculate_remaining_hours)

  # Day of the week in Finnish
  day_of_week=$(date +%A)

  # Pass $time_msg "Nyt on viikonloppu" if it's weekend
  if is_weekend; then
    time_msg="Ota myös huomioon että nyt on viikonloppu, eikä silloin työasioita tehdä."
  fi

  # Pass $time_msg "Nyt on loma" if it's holiday
  if is_holiday; then
    time_msg="Ota myös huomioon että nyt on loma, eikä silloin työasioita tehdä."
  fi

  # Combine parts of the message in Bash, removing unnecessary spaces and line breaks
  combined_message="${PROMPT_BGINFO}\n\n${PROMPT_NOTES}\n\nTässä on tämänpäiväiset tehtävät (mukana ID:t):\n${tasks}\n\nTässä ovat päivän kalenteritapahtumat:\n${events}\n\nTänään on $day_of_week. Kello on $current_time. Päivää on jäljellä noin $remaining_hours tuntia.\n\n$time_msg"

  # Estimate the number of tokens in the combined message based on character count
  message_token_count=$(estimate_token_count "$combined_message")

  # Calculate the maximum allowed response tokens, with a larger safety margin
  max_context_tokens=8192

  # Works with max 50 tasks and events combined
  safety_margin=2000

  max_tokens_for_response=$(( max_context_tokens - message_token_count - safety_margin ))

  # Ensure max_tokens_for_response is not negative or zero
  if [ "$max_tokens_for_response" -le 0 ]; then
    echo "Error: Message is too long and exceeds the maximum context length of 8192 tokens."
    exit 1
  fi

  # Debugging: Print token counts only locally, not affecting the payload
  if [ "$DEBUG" = true ]; then
    echo -e "Message token count (estimated): $message_token_count"
    echo -e "Max tokens for response with margin: $max_tokens_for_response"
  fi

  # Create the JSON payload - no debug info is included in the payload
  json_payload=$(jq -n --arg combined_message "$combined_message" --argjson max_tokens "$max_tokens_for_response" '{
      "model": "gpt-4",
      "messages": [
          {"role": "system", "content": "Sinä olet tehtävien priorisoija."},
          {"role": "user", "content": $combined_message}
      ],
      "max_tokens": $max_tokens,
      "temperature": 0.5
  }')

  # Make API call to OpenAI with the given message structure
  response=$(curl -s --request POST \
    --url "https://api.openai.com/v1/chat/completions" \
    --header "Content-Type: application/json" \
    --header "Authorization: Bearer ${OPENAI_API_KEY}" \
    --data "$json_payload")

  # Print the response anyway if there's an error
  if [[ "$response" == *"error"* ]]; then
    echo -e "${BOLD}${RED}Virhe: OpenAI-priorisointi epäonnistui.${RESET}"

    # Message
    echo -e "${BOLD}${RED}Viesti:${RESET}\n$response"
    exit 1
  fi

  # Parse response
  echo "$response" | jq -r '.choices[0].message.content // "Ei tuloksia"'
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

  echo -e "${BOLD}${YELLOW}Priorisoidaan tehtävät ja palaverit OpenAI:n avulla ja luodaan muistiinpano...${RESET}"
  priorities=$(get_priorities "$tasks" "$events")

  echo -e "${BOLD}${GREEN}Priorisoidut tehtävät ja asiat:${RESET}\n$priorities\n"

  # Get the current local time with timezone
  current_time=$(TZ=$(cat /etc/timezone) date "+%H:%M")
  remaining_hours=$(calculate_remaining_hours)

  # Filename format: YYYY-MM-DD_HH-MM-SS.md
  filename=$(date "+%Y-%m-%d_%H-%M-%S")
  date_header=$(date "+%d.%m.%Y")

  # Save output to Obsidian vault with the current time and remaining hours in the header
  echo -e "# $date_header\n\nKello on muistiinpanojen luomishetkellä $current_time. Päivää on jäljellä noin $remaining_hours tuntia.\n\n$priorities" > "$HOME/Documents/Brain dump/Päivän suunnittelu/$filename.md"
  echo -e "${BOLD}${GREEN}Priorisointi on valmis ja tallennettu Obsidian-vaultiin.${RESET}"

  echo -e "${BOLD}${YELLOW}Siirretään tehtäviä seuraavalle päivälle...${RESET}"

  # Debug: Print the full content of postponed_tasks to see what's being parsed
  if [ "$DEBUG" = true ]; then
    echo -e "${BOLD}${CYAN}Content of postponed_tasks:${RESET}\n$priorities\n"
  fi

  # Select all numbers that are in side parentheses like (8479576161)
  task_ids_to_postpone=$(echo "$priorities" | grep -oP '\(\K[0-9]+(?=\))')

  # Debugging to see the extracted task IDs
  if [ "$DEBUG" = true ]; then
    echo -e "${BOLD}${CYAN}Postponed task IDs:${RESET} $task_ids_to_postpone"
  fi

  # Moving those tasks to the next day that AI suggested
  if [[ -n "$task_ids_to_postpone" ]]; then
    echo -e "${BOLD}${YELLOW}Siirretään AI:n suosittelemat tehtävät seuraavalle päivälle...${RESET}"

    for task_id in $task_ids_to_postpone; do
      postpone_task "$task_id"
    done
  else
    echo -e "${BOLD}${CYAN}AI ei suositellut tehtävien siirtämistä.${RESET}"
  fi
}

# Run the script
main "$@"
