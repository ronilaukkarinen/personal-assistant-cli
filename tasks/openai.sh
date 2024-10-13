get_priorities() {
  local tasks="$1"
  local events="$2"
  local days_to_process="$3"
  local start_day="$4"

  combined_message=""

  for i in $(seq 0 $((days_to_process-1))); do

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

    # If day is today
    if [ "$current_day" == "$compare_day" ]; then
      combined_message+="${PROMPT_BGINFO}\n\n${PROMPT_NOTES}\n\nPyydän sinua arvioimaan tehtäville kellonajat ja kestot. Tässä ovat tämänpäiväiset tehtävät (mukana ID:t):\n${tasks}\n\nTässä ovat päivän kalenteritapahtumat:\n${events}\n\nArvioi kullekin tehtävälle suoritusaika ja kesto, ja merkitse lykkäämisen tarve. Tänään on $date_today, $day_of_week. Kello on $current_time. Päivää on jäljellä noin $remaining_hours tuntia. Klo 22 jälkeen yritän rauhoittua nukkumaan, älä ajoita sinne enää tehtäviä.\n\n$time_msg"
    else
      combined_message+="${PROMPT_BGINFO}\n\n${PROMPT_NOTES}\n\nTässä ovat $date_today päivän tehtävät (mukana ID:t):\n${tasks}\n\nTässä ovat päivän kalenteritapahtumat:\n${events}\n\nArvioi kullekin tehtävälle suoritusaika ja kesto, ja merkitse lykkäämisen tarve.\n\n"
    fi
  done

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
