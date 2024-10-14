get_priorities() {
  local tasks="$1"
  local days_to_process="$2"
  local start_day="$3"

  combined_message=""

  for i in $(seq 0 $((days_to_process-1))); do

    # Exit if a file matching this day exists
    if [[ "$(uname)" == "Darwin" ]]; then
      file=$(find "$HOME/Documents/Brain dump/Päivän suunnittelu" -name "$(gdate -d "$start_day + $i days" "+%Y-%m-%d")*.md" -print -quit)
    else
      file=$(find "$HOME/Documents/Brain dump/Päivän suunnittelu" -name "$(date -d "$start_day + $i days" "+%Y-%m-%d")*.md" -print -quit)
    fi

    # If a file exists and force is not enabled, exit
    if [[ -n "$file" && "$FORCE" = false ]]; then
      echo -e "${BOLD}${RED}Error: The schedule has already been made for this day (file: $file).${RESET}"
      exit 1
    fi

    # Check if macOS is used
    if [[ "$(uname)" == "Darwin" ]]; then
      current_day=$(gdate -d "$start_day + $i days" "+%Y-%m-%d")
      current_time=$(gdate "+%H:%M")
    else
      current_day=$(date -d "$start_day + $i days" "+%Y-%m-%d")
      current_time=$(date "+%H:%M")
    fi

    remaining_hours=$(calculate_remaining_hours "$current_time")

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
    note_instructions='Ohjeistus muistiipanolle, johon kirjoitat priorisoinnit (noudata tarkkaan!):\n
      - Muotoile listat markdown-muodossa. Muista rivinvaihto otsikon jälkeen.\n
      - Ensimmäinen lista, h2-otsikko: "Tärkeimmät tehtävät tänään (Top X)", arvioi itse määrä. Ole hyvä ja arvioi, miksi tehtävä on tärkeä, milloin minun tulisi suorittaa kukin tehtävä ja kuinka kauan ne kestävät. Tehtävän nimessä ei tarvitse olla ID:tä, mutta metadata on oltava viimeisenä tehtävän tietojen jälkeen omalla rivillään, kaikki samalla rivillä.\n
      - Toinen lista, h2-otsikko: "Tehtävät, jotka voidaan lykätä myöhempään". Laita tähän listaan ne tehtävät, jotka eivät mahdu realistisesti päivääni, älä jätä yhtään tehtävää listaamatta.\n
      - Huom, tärkeä: Jokaisen tehtävän perään Metadata tässä muodossa, omalle rivilleen, huom. "siirretty seuraavalle päivälle" VAIN jos kyseessä on lykättävä tehtävä, ei muutoin. Nämä ovat ehdottoman tärkeitä tietoja, jotta muu koodini osaa parseroida listaa. Esimerkki metadatatiedosta, jollaisessa muodossa metadata on sisällytettävä tehtävään listassa: (Metadata: "duration": 60, "datetime": "YYYY-MM-DDTHH:MM:SS.000000Z") (12345678901, siirretty seuraavalle päivälle).'

    # If day is today
    if [ "$current_day" == "$compare_day" ]; then
      combined_message+="${PROMPT_BGINFO}\n\n${PROMPT}\n\nTässä ovat tämänpäiväiset tehtävät (mukana ID:t):\n${tasks}\n\n$note_instructions\n\nOle hyvä ja arvioi kullekin tehtävälle suoritusaika ja kesto, ja merkitse lykkäämisen tarve. Tänään on $date_today, $day_of_week. Kello on $current_time. Päivää on jäljellä noin $remaining_hours tuntia. Älä ajoita tehtäviä välille 00-10.\n\n$time_msg"
    else
      combined_message+="${PROMPT_BGINFO}\n\n${PROMPT}\n\n$note_instructions\n\nTässä ovat $date_today päivän tehtävät (mukana ID:t):\n${tasks}\n\nArvioi kullekin tehtävälle suoritusaika ja kesto, ja merkitse lykkäämisen tarve.\n\n"
    fi
  done

  # Debug
  if [ "$DEBUG" = true ]; then
    # Print all data
    echo -e "${BOLD}${CYAN}current_day:${RESET} $current_day"
    echo -e "${BOLD}${CYAN}current_time:${RESET} $current_time"
    echo -e "${BOLD}${CYAN}remaining_hours:${RESET} $remaining_hours"
    echo -e "${BOLD}${CYAN}day_of_week:${RESET} $day_of_week"
    echo -e "${BOLD}${CYAN}date_today:${RESET} $date_today"
    echo -e "${BOLD}${CYAN}compare_day:${RESET} $compare_day"
    echo -e "${BOLD}${CYAN}combined_message:${RESET}\n$combined_message"
  fi

  # Killswitch for debugging
  if [ "$KILLSWITH" = true ]; then
    exit 1
  fi

  # Create the JSON payload - no debug info is included in the payload
  json_payload=$(jq -n --arg combined_message "$combined_message" '{
      "model": "gpt-4",
      "messages": [
          {"role": "system", "content": "Sinä olet tehtävien priorisoija."},
          {"role": "user", "content": $combined_message}
      ],
      "max_tokens": 5000,
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
