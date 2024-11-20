# Get dependencies
source ${SCRIPTS_LOCATION}/tasks/schedule.sh

# Batch process tasks and sync Google Calendar events to Todoist
function batch() {
  echo -e "${BOLD}${YELLOW}Processing tasks from $start_day for the next $days_to_process days...${RESET}"

  # Calculate end date
  # macOS and Linux compatible version
  if [[ "$(uname)" == "Darwin" ]]; then
    start_day=$(gdate -d "$start_day" "+%Y-%m-%d")
    end_day=$(gdate -d "$start_day + $days_to_process days" "+%Y-%m-%d")
  else
    start_day=$(date -d "$start_day" "+%Y-%m-%d")
    end_day=$(date -d "$start_day + $days_to_process days" "+%Y-%m-%d")
  fi

  # Sync Google Calendar events to Todoist
  echo -e "${BOLD}${YELLOW}Syncing Google Calendar events to Todoist...${RESET}"

  # Run sync first
  source ${SCRIPTS_LOCATION}/tasks/sync-google-calendar-to-todoist.sh

  # Fetch tasks from Todoist API
  tasks=$(curl -s --request GET \
    --url "https://api.todoist.com/rest/v2/tasks" \
    --header "Authorization: Bearer ${TODOIST_API_KEY}")

  # Fetch projects from Todoist API
  projects=$(curl -s --request GET \
    --url "https://api.todoist.com/rest/v2/projects" \
    --header "Authorization: Bearer ${TODOIST_API_KEY}")

  # Create a map of project_id -> project_name
  project_map=$(echo "$projects" | jq -r 'map({(.id | tostring): .name}) | add')

  # Count the number of subtasks for each task in Bash
  subtask_counts=$(echo "$tasks" | jq -r '[.[] | select(.parent_id != null) | .parent_id] | group_by(.) | map({(.[0]): length}) | add')

  # Initialize the counter
  counter=1

  # Process each task and format it with the counter for a numbered list
  days_tasks=""
  while IFS= read -r line; do
    # Add the counter to each task
    days_tasks+="$counter. $line\n"
    # Increment the counter
    counter=$((counter + 1))
  done < <(echo "$tasks" | jq -r --arg current_day "$current_day" --argjson project_map "$project_map" --argjson subtask_counts "$subtask_counts" '
    .[] |
    select(.due.date <= $current_day) |
    select(.parent_id == null) |
    select((.labels | index("Google-kalenterin tapahtuma") | not) and (.labels | index("Nobot") | not)) |
    .project_name = ($project_map[.project_id | tostring] // "Muu projekti") |
    .project_name = (if .project_name == "Todo" then "Työasiat" else .project_name end) |
    .subtask_count = ($subtask_counts[.id] // 0) |
    "\(.content) (\(.project_name))" +
    (if (.labels | length > 0) then " (\(.labels | join(", ")))" else "" end) +
    (if (.subtask_count > 0) then " (Alatehtäviä: \(.subtask_count))" else "" end) +
    " (Metadata: id: \"\(.id)\", priority: \"\(.priority // "none")\", duration: \"\(.duration.amount // "0")\", datetime: \"\(.due.datetime // "undefined")\")"
  ')

  # Debug
  echo -e "${BOLD}${CYAN}Tasks between $start_day and $end_day:\n$days_tasks${RESET}"

  # Instruct AI to prioritize tasks
  the_prompt="\
  Tässä lista tehtävistä:\n\n${days_tasks}\n\nTässä lista kalenteritapahtumista:\n\n${all_events}\n\n
  Taustatiedot: Olen teknologiayrittäjä ja perustaja 15 henkilön yrityksessä. Yrityksessä priorisoimme asiat, joista saa rahaa nopeasti, seuraavaksi asiat, joista saa rahaa tulevaisuudessa ja vasta sitten kaikki muu. Vapaa-ajalla arvostan rentoutumista.\n\n

  Pyydän, että priorisoit ja aikataulutat nämä tehtävät koko määritetylle ajalle (päivien '$start_day' - '$end_day' välillä) seuraavasti:
  1. Kaikille tehtäville lisätään tai päivitetään metadatariville \"duration\" ja \"datetime\" kentät. Mikäli tehtävään on merkity \"Backlog / asiat, joita ei tarvitse tehdä heti\", voit lykätä tehtäviä vapaasti pidemmällekin, vaikka kuukauden päähän.\n
  2. Kunkin tehtävän muoto on: Tehtävän nimi (Kategoria 1, Kategoria 2) (Metadata: id: \"1234567890\", priority: \"1-4\", duration: \"0-999\", datetime: \"YYYY-MM-DDTHH:MM:SS\"). Lisää myös tehtävän perään selkokielinen päiväys siitä minne se on lykätty.\n
  3. Älä koskaan aikatauluta tehtäviä yöajalle tai ennen kello 10:00.\n
  4. Jos päivälle on liikaa tekemistä, lykkää loput tehtävistä myöhemmille päiville ja viikoille, poislukien 1 ja 2 prioriteetin tehtävät.\n
  5. Tehtävälistan tulee olla yhtenäinen, ja kaikki tehtävät tulee sisällyttää, vaikka aikataulua muokataan!!! Tämä on tärkeää.

  Anna aikataululista yhtenä kokonaisuutena ja lisää lopuksi muistiinpanot valinnoista. Käytä vain pieniä kirjaimia paitsi otsikoissa. Käytä seuraavia otsikoita: \"Tärkeimmät tehtävät tänään\", \"Lykätyt tehtävät\" ja \"Yhteenveto\"."

  # Create the JSON payload - no debug info is included in the payload
  json_payload=$(jq -n --arg the_prompt "$the_prompt" '{
      "model": "gpt-4o-mini",
      "messages": [
          {"role": "system", "content": "Sinä olet tehtävien priorisoija."},
          {"role": "user", "content": $the_prompt}
      ],
      "max_tokens": 16000,
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
    echo -e "${BOLD}${RED}Error: OpenAI-priorization failed.${RESET}"

    # Message
    echo -e "${BOLD}${RED}Message:${RESET}\n$response"
    exit 1
  fi

  # Parse response
  priorities=$(echo "$response" | jq -r '.choices[0].message.content // "Ei tuloksia"')

  echo -e "${BOLD}${GREEN}Prioritization ready:${RESET}\n$priorities\n"

  # Date header for notes
  date_header='Päivien '$start_day' - '$end_day' tehtävien priorisointi'

  # Save output to Obsidian vault with the start and end date in the header
  echo -e "# $date_header\n\n$priorities" > "$HOME/Documents/Brain dump/Päivän suunnittelu/${start_day}-${end_day} (useampi päivä).md"

  echo -e "${BOLD}${GREEN}Prioritization is ready and saved to Obsidian.${RESET}"

  # Debug: Print the full content of tasks to see what's being parsed
  if [ "$DEBUG" = true ]; then
    echo -e "${BOLD}${CYAN}Content of tasks that are being parsed:${RESET}\n$priorities\n"
  fi

  # If macOS and no ggrep found, install ggrep directly
  if [[ "$(uname)" == "Darwin" ]] && ! command -v ggrep &> /dev/null; then
    echo -e "${BOLD}${YELLOW}Installing ggrep for macOS...${RESET}"
    brew install grep
  fi

  # macOS and Linux compatible version of grep
  if [[ "$(uname)" == "Darwin" ]]; then
    # Extract all numbers with more than 5 digits, which we assume to be task IDs
    task_ids_to_schedule=$(echo "$priorities" | ggrep -oP '\b[0-9]{6,}\b')
  else
    # Extract all numbers with more than 5 digits, which we assume to be task IDs
    task_ids_to_schedule=$(echo "$priorities" | grep -oP '\b[0-9]{6,}\b')
  fi

  if [[ -n "$task_ids_to_schedule" ]]; then
    echo -e "${BOLD}${YELLOW}Scheduling tasks based on metadata...${RESET}"

    for task_id in $task_ids_to_schedule; do
      # First find the line containing the metadata for this task ID
      if [[ "$(uname)" == "Darwin" ]]; then
        metadata_line=$(echo "$priorities" | ggrep -P "Metadata:.*id:\s*\"$task_id\"")
      else
        metadata_line=$(echo "$priorities" | grep -P "Metadata:.*id:\s*\"$task_id\"")
      fi

      if [[ -n "$metadata_line" ]]; then
        # Then extract duration and datetime separately
        if [[ "$(uname)" == "Darwin" ]]; then
          task_duration=$(echo "$metadata_line" | ggrep -oP 'duration:\s*"\K[^"]+')
          task_datetime=$(echo "$metadata_line" | ggrep -oP 'datetime:\s*"\K[^"]+')
        else
          task_duration=$(echo "$metadata_line" | grep -oP 'duration:\s*"\K[^"]+')
          task_datetime=$(echo "$metadata_line" | grep -oP 'datetime:\s*"\K[^"]+')
        fi

        if [[ -n "$task_duration" && -n "$task_datetime" ]]; then
          schedule_task "$task_id" "$task_duration" "$task_datetime"
        else
          echo -e "${RED}Error: Missing duration or datetime for task ID $task_id${RESET}"
        fi
      else
        echo -e "${RED}Error: No metadata found for task ID $task_id${RESET}"
      fi
    done
  else
    echo -e "${BOLD}${CYAN}AI did not suggest scheduling any tasks or task IDs were not found.${RESET}"
  fi

  # Clean up metadata from notes
  if [ -n "$start_day" ]; then
    cleanup_file="$HOME/Documents/Brain dump/Päivän suunnittelu/$start_day.md"
    if [ -n "$end_day" ]; then
      cleanup_file="$HOME/Documents/Brain dump/Päivän suunnittelu/${start_day}-${end_day} (useampi päivä).md"
    fi
    source ${SCRIPTS_LOCATION}/tasks/cleanup-notes.sh
    cleanup_notes "$cleanup_file"
  fi
}

# Run the batch function
batch
