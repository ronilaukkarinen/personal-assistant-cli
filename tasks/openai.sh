get_priorities() {
  local tasks="$1"
  local days_to_process="$2"
  local start_day="$3"

  # If we enable debugging, the debug messages print out to the notes and prompts
  local DEBUG=false

  the_prompt=""

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

    # macOS version and Linux version of date +%Y-%m-%d
    if [[ "$(uname)" == "Darwin" ]]; then
      compare_day=$(gdate "+%Y-%m-%d")
    else
      compare_day=$(date "+%Y-%m-%d")
    fi

    # THE PROMPT
    the_prompt="\
    Tässä lista tehtävistä:\n\n${tasks}\n\nTässä lista kalenteritapahtumista:\n\n${all_events}\n\n
    Taustatiedot: Olen teknologiayrittäjä ja perustaja 15 henkilön yrityksessä. Yrityksessä priorisoimme asiat, joista saa rahaa nopeasti, seuraavaksi asiat, joista saa rahaa tulevaisuudessa ja vasta sitten kaikki muu. Vapaa-ajalla arvostan rentoutumista.\n\n

    Pyydän, että priorisoit ja aikataulutat nämä tehtävät seuraavasti:
    1. Kaikille tehtäville lisätään tai päivitetään metadatariville \"duration\" ja \"datetime\" kentät.\n
    2. Kunkin tehtävän muoto on: Tehtävän nimi (Kategoria 1, Kategoria 2) (Metadata: id: \"1234567890\", priority: \"1-4\", duration: \"0-999\", datetime: \"YYYY-MM-DDTHH:MM:SS\").\n\n
    3. Älä aikatauluta tehtäviä klo 00-10 tai 18-00 välille (paitsi \"(Kotiasiat)\" tehtävät klo 18-22).\n
    4. Lykkää jonnekin kuukauden päähän ne tehtävät, joissa mainitaan \"Backlog\", \"Lowprio\" tai \"Ei tärkeä\".\n
    5. Jos tälle päivälle on liikaa tekemistä, lykkää loput tehtävistä seuraaville päiville.\n
    6. Tehtävälistan tulee olla yhtenäinen, ja kaikki tehtävät tulee sisällyttää, vaikka aikataulua muokataan.

    Anna aikataululista yhtenä kokonaisuutena ja lisää lopuksi muistiinpanot valinnoista. Käytä vain pieniä kirjaimia paitsi otsikoissa. Käytä seuraavia otsikoita: \"Tärkeimmät tehtävät tänään\", \"Lykätyt tehtävät\" ja \"Yhteenveto\"."

    # Check for weekend or holiday
    if is_weekend "$current_day"; then
      the_prompt+="\n\nMuista, että nyt on viikonloppu, joten vältä työasioiden ajoittamista.\n"
    fi

    if is_holiday "$current_day"; then
      the_prompt+="\n\nOta huomioon, että tänään on loma, eikä työasioita tulisi tehdä.\n"
    fi
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
    echo -e "${BOLD}${CYAN}the_prompt:${RESET}\n$the_prompt"
  fi

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
  echo "$response" | jq -r '.choices[0].message.content // "Ei tuloksia"'
}
