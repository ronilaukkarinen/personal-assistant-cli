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
