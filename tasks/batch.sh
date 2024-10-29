# Get dependencies
source ${SCRIPTS_LOCATION}/tasks/schedule.sh
source ${SCRIPTS_LOCATION}/tasks/postpone.sh

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
    " (Metadata: id: \"\(.id)\", priority: \"\(.priority // "none")\", duration: \"\(.duration.amount // "undefined")\", datetime: \"\(.due.datetime // "undefined")\")"
  ')

  # Debug
  echo -e "${BOLD}${CYAN}Tasks between $start_day and $end_day:\n$days_tasks${RESET}"

  # Instruct AI to prioritize tasks
  # Note instructions prompt
  note_instructions='Ohjeistus muistiipanolle, johon kirjoitat priorisoinnit (noudata tarkkaan!):\n
    - Muotoile listat markdown-muodossa. Muista rivinvaihto otsikon jälkeen.\n
    - Ensimmäinen lista, h2-otsikko: "Tärkeimmät tehtävät päivien '$start_day' - '$end_day' välillä" (Top X)". Ole hyvä ja arvioi, miksi tehtävä on tärkeä, milloin minun tulisi suorittaa kukin tehtävä ja kuinka kauan ne kestävät, kerro selkokielisessä muodossa eli erottele tunnit ja minuutit. Tehtävän nimi listan ensimmäiselle riville, perustelu toiselle riville ja metadata kolmannelle riville. Perustele huolellisesti. Tehtävän nimessä ei tarvitse olla ID:tä, mutta metadata ja ID on oltava viimeisenä tehtävän tietojen jälkeen omalla rivillään, kaikki samalla rivillä.\n
    - Toinen lista, h2-otsikko: "Tehtävät, jotka voidaan lykätä myöhempään". Laita tähän listaan KAIKKI muut tehtävät, jotka eivät mahdu realistisesti näiden päivien aikaikkunaan. Tehtävän nimi listan ensimmäiselle riville, perustelu toiselle riville ja metadata ja ID kolmannelle riville. Perustele huolellisesti.\n
    - Huom, tärkeä: Jokaisen tehtävän perään Metadata tässä muodossa, omalle rivilleen, huom. "siirretty myöhemmälle" VAIN jos kyseessä on lykättävä tehtävä, ei muutoin. Nämä ovat ehdottoman tärkeitä tietoja, jotta muu koodini osaa parseroida listaa. Esimerkki metadatatiedosta, jollaisessa muodossa metadata on sisällytettävä tehtävään listassa, Metadata aina sulkuihin ja ID aina sulkuihin: (Metadata: "duration": 60, "datetime": "YYYY-MM-DDTHH:MM:SS") (12345678901, siirretty myöhemmälle).\n
    - Kerro listojen lopuksi omat huomiosi. Älä unohda, että olen iltavirkku, heräisin mielelläni klo 9-10, minun on nukuttava vähintään 8 tuntia 15 minuuttia, ajoita tehtäviä sen mukaan. Älä ajoita tehtäviä välille 00-10.\n'

  combined_message+="${PROMPT_BGINFO}\n\n${PROMPT}\n\nTässä ovat päivien '$start_day' - '$end_day' väliset tehtävät (mukana ID:t):\n$days_tasks\n\n$note_instructions\n\nOle hyvä ja arvioi kullekin tehtävälle suoritusaika ja kesto, ja merkitse lykkäämisen tarve. Ota mukaan kaikki alkuperäisen listan tehtävät, älä tiivistä niin että tehtäviä jää pois. Jokainen on tärkeä mainita ja huomioida."

  # Create the JSON payload - no debug info is included in the payload
  json_payload=$(jq -n --arg combined_message "$combined_message" '{
      "model": "gpt-4o-mini",
      "messages": [
          {"role": "system", "content": "Sinä olet tehtävien priorisoija."},
          {"role": "user", "content": $combined_message}
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
      if [[ "$(uname)" == "Darwin" ]]; then
        metadata_line=$(echo "$priorities" | ggrep -P "Metadata:.*\"duration\":\s*[0-9]+.*\"datetime\":\s*\"[0-9T:.Z-]+\".*$task_id")
      else
        metadata_line=$(echo "$priorities" | grep -P "Metadata:.*\"duration\":\s*[0-9]+.*\"datetime\":\s*\"[0-9T:.Z-]+\".*$task_id")
      fi

      if [[ -n "$metadata_line" ]]; then
        if [[ "$(uname)" == "Darwin" ]]; then
          task_duration=$(echo "$metadata_line" | ggrep -oP '(?<=duration":\s)[0-9]+')
          task_datetime=$(echo "$metadata_line" | ggrep -oP '(?<=datetime":\s")[^"]+')
        else
          task_duration=$(echo "$metadata_line" | grep -oP '(?<=duration":\s)[0-9]+')
          task_datetime=$(echo "$metadata_line" | grep -oP '(?<=datetime":\s")[^"]+')
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

  echo -e "${BOLD}${YELLOW}Postponing tasks to the possible day (a day after end day of the batch)...${RESET}"

  # macOS and Linux compatible version
  if [[ "$(uname)" == "Darwin" ]]; then
    task_ids_to_postpone=$(echo "$priorities" | ggrep -oP '\b\d{5,}\b(?=.*siirretty myöhemmälle)')
  else
    task_ids_to_postpone=$(echo "$priorities" | grep -oP '\b\d{5,}\b(?=.*siirretty myöhemmälle)')
  fi

  # Debugging to see the extracted task IDs
  if [ "$DEBUG" = true ]; then
    echo -e "${BOLD}${CYAN}Postponed task IDs:${RESET} $task_ids_to_postpone"
  fi

  # Moving those tasks to the next day that AI suggested
  if [[ -n "$task_ids_to_postpone" ]]; then
    echo -e "${BOLD}${YELLOW}Postponing tasks suggested by AI to the next possible day...${RESET}"

    for postpone_task_id in $task_ids_to_postpone; do
      postpone_task "$postpone_task_id" "$end_day"
    done
  else
    echo -e "${BOLD}${CYAN}AI did not suggest postponing any tasks or task IDs were not found.${RESET}"
  fi

  # Clean up metadata from notes
  source ${SCRIPTS_LOCATION}/tasks/cleanup-notes.sh
  cleanup_notes "$HOME/Documents/Brain dump/Päivän suunnittelu/${start_day}-${end_day} (useampi päivä).md"
}

# Run the batch function
batch
