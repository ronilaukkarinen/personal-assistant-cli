get_priorities() {
  local tasks="$1"
  local days_to_process="$2"
  local start_day="$3"

  # If we enable debugging, the debug messages print out to the notes and prompts
  local DEBUG=false

  combined_message=""

  for i in $(seq 0 $((days_to_process-1))); do

    # Debug remaining hours
    if [ "$DEBUG" = true ]; then
      echo -e "${BOLD}${CYAN}remaining_hours:${RESET} $remaining_hours"
    fi

    # Check if macOS is used
    if [[ "$(uname)" == "Darwin" ]]; then
      current_day=$(gdate -d "$start_day + $i days" "+%Y-%m-%d")
      current_time=$(gdate "+%H:%M")
    else
      current_day=$(date -d "$start_day + $i days" "+%Y-%m-%d")
      current_time=$(date "+%H:%M")
    fi

    # Day of the week in Finnish for the current day
    # Check if macOS is used
    if [[ "$(uname)" == "Darwin" ]]; then
      day_of_week=$(gdate -d "$current_day" +%A)
      # Date in Finnish for the current day
      date_today=$(gdate -d "$current_day" "+%d.%m.%Y")
    else
      day_of_week=$(date -d "$current_day" +%A)
      # Date in Finnish for the current day
      date_today=$(date -d "$current_day" "+%d.%m.%Y")
    fi

    # Check for weekend or holiday
    if is_weekend "$current_day"; then
      combined_message+="Ota myös huomioon että nyt on viikonloppu, eikä silloin tehdä työasioita.\n"
    fi

    if is_holiday "$current_day"; then
      combined_message+="Ota myös huomioon että nyt on loma, eikä silloin tehdä työasioita.\n"
    fi

    # macOS version and Linux version of date +%Y-%m-%d
    if [[ "$(uname)" == "Darwin" ]]; then
      compare_day=$(gdate "+%Y-%m-%d")
    else
      compare_day=$(date "+%Y-%m-%d")
    fi

    # Note instructions prompt
    note_instructions='Tehtävät eivät ole tärkeysjärjestyksessä. Sinun tulee priorisoida nämä tehtävät ja päivitettävä uusi aikataulu metadataan. Käy jokainen tehtävä yksitellen läpi, älä jätä yhtäkään tehtävää pois. Esitysmuoto on seuraava (jokaisella tehtävällä on metadata, joka tulee täydentää):\n\n1. Tehtävän nimi (Kategoria 1, Kategoria 2) (Metadata: id: "1234567890", priority: "1-4", duration: "0-999", datetime: "YYYY-MM-DDTHH:MM:SS")\n\n*JOKAISEN tehtävän metadataan on päivitettävä* "duration" ja "datetime" kentät. Muokkaa jokaiselle tehtävälle kesto, jos se on 0 tai puuttuu. Muokkaa jokaiselle tehtävälle datetime, jos tälle päivälle on liikaa tekemistä. Jaksan tehdä max 1-2 isoa tehtävää per päivä, useamman pienemmän. HUOM! Jos tehtävässä mainitaan "Backlog" tai "Lowprio" tai "Ei tärkeä", lykkää nämä aina eteenpäin.\n\nAikataulut: Älä ajoita tehtäviä välille 00-10. Työaikani on 10-18. Ne tehtävät, joissa on mainittu "(Kotiasiat)" voin tehdä 18-22, mutta muuten ÄLÄ aikatauluta tehtäviä 18-00 välille. Tänään on $day_of_week, $date_today ja kello on $current_time, älä aikatauluta mitään menneisyyteen.\n\nAnna tehtävälista yhtenä kokonaisuutena, varmistaen että kaikki tehtävät ovat mukana muuttamattomina, lukuun ottamatta pyydettyjä muutoksia metadatariveillä. Ne tehtävät, jotka eivät mahdu päivän aikatauluun, vaihda metadatan "datetime" vähintään seuraavalle päivälle.\n\nKun olet valmis, tee muistiinpanot priorisointisi perusteista ja aikataulutusstrategiastasi. Voit korostaa tehtäviin kuluvia aikoja, tärkeimpiä tehtäviä, niiden perusteluja sekä syitä priorisoinnille. Käytä isoja alkukirjaimia vain otsikoiden alussa, suomen kielen tyylin mukaan joka sana EI tule isolla alkukirjaimella. Markdown-h2-otsikot voisivat olla "Tärkeimmät tehtävät tänään", "Lykätyt tehtävät" ja "Yhteenveto".\n'

    # The actual prompt
    combined_message+="${PROMPT_BGINFO}\n\nTässä lista tehtävistä:\n\n${tasks}\n\nTässä lista kalenteritapahtumista:\n\n${all_events}${PROMPT}\n\n$note_instructions"
  done

  # Debug
  if [ "$DEBUG" = true ]; then
    # Print all data
    echo -e "${BOLD}${CYAN}all_events:${RESET}\n$all_events"
    echo -e "${BOLD}${CYAN}current_day:${RESET} $current_day"
    echo -e "${BOLD}${CYAN}current_time:${RESET} $current_time"
    echo -e "${BOLD}${CYAN}remaining_hours:${RESET} $remaining_hours"
    echo -e "${BOLD}${CYAN}day_of_week:${RESET} $day_of_week"
    echo -e "${BOLD}${CYAN}date_today:${RESET} $date_today"
    echo -e "${BOLD}${CYAN}compare_day:${RESET} $compare_day"
    echo -e "${BOLD}${CYAN}combined_message (the prompt):${RESET}\n$combined_message"
  fi

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
  echo "$response" | jq -r '.choices[0].message.content // "Ei tuloksia"'
}
