#!/bin/bash
# Load API keys from `.env` file
source .env

TODOIST_API_KEY=${TODOIST_API_KEY}
OPENAI_API_KEY=${OPENAI_API_KEY}

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

# Function: Fetch today's tasks from Todoist
fetch_tasks() {
  local today
  today=$(date +%Y-%m-%d)  # Get today's date in YYYY-MM-DD format

  # Fetch tasks and filter those due today using jq
  curl -s --request GET \
    --url "https://api.todoist.com/rest/v2/tasks" \
    --header "Authorization: Bearer ${TODOIST_API_KEY}" \
    | jq -r --arg today "$today" '.[] | select(.due.date == $today) | "- " + .content'
}

# Function: Send task list to OpenAI and get prioritized tasks using the chat model
get_priorities() {
  local tasks="$1"

  # Escape the tasks string for JSON format using jq
  escaped_tasks=$(echo "$tasks" | jq -Rs .)

  # Create a message structure for OpenAI's chat model
  message_content="Olen liiketoimintalähtöinen teknologiajohtaja, yrittäjä ja perustaja 15 henkilön yrityksessä. Yrityksemme on WordPress-digitoimisto ja päätuotteemme ovat WordPress-verkkosivut, WooCommerce-verkkokaupat, WordPress-ylläpito ja visuaalinen käyttöliittymäsuunnittelu. Teemme mm. kokonaisia projekteja, sivustouudistuksia, jatkokehitystä ja niin edelleen. Olen super kiireinen ja tehtävälistani on usein täynnä. Yrityksessämme on lisäkseni 1 toimitusjohtaja, 1 projektipäällikkö, 10 koodaria, 2 suunnittelijaa ja 1 harjoittelija. Mitkä ovat tärkeimmät tehtävät, joita minun tulisi tehdä tänään, top 5? Ehdota myös tehtävät lykättäväksi myöhemmäksi. Muotoile lista markdown-muodossa ja arvioi jokaiselle tehtävälle aika. Työaikani on noin 8h päivässä, mutta voin venyä. Tässä on lista tämänpäiväisistä tehtävistäni:\n$tasks"

  # Create the JSON payload correctly for the chat model
  json_payload=$(jq -n --arg content "$message_content" '{
      "model": "gpt-4",
      "messages": [{"role": "system", "content": "Sinä olet tehtävien priorisoija."},
                   {"role": "user", "content": $content}],
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
    echo -e "${BOLD}${YELLOW}Vastaus jatkuu, haetaan lisää...${RESET}"
    
    # Create new prompt with the previous content to continue from where it stopped
    json_payload=$(jq -n --arg content "$content_part" '{
        "model": "gpt-4",
        "messages": [{"role": "user", "content": $content}],
        "max_tokens": 500,
        "temperature": 0.5
      }')
    
    # Make a new API call to continue the conversation
    response=$(curl -s --request POST \
      --url "https://api.openai.com/v1/chat/completions" \
      --header "Content-Type: application/json" \
      --header "Authorization: Bearer ${OPENAI_API_KEY}" \
      --data "$json_payload")

    # Append the new content to the previous part
    new_content=$(echo "$response" | jq -r '.choices[0].message.content // ""')
    content_part+="$new_content"
    finish_reason=$(echo "$response" | jq -r '.choices[0].finish_reason // ""')
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

  if [ -z "$tasks" ]; then
    echo -e "${BOLD}${RED}Ei tämänpäiväisiä tehtäviä Todoistissa.${RESET}"
    exit 1
  fi

  echo -e "${BOLD}${GREEN}Tämänpäiväiset tehtävät:${RESET}\n$tasks\n"
  
  echo -e "${BOLD}${YELLOW}Priorisoidaan tehtävät OpenAI:n avulla...${RESET}"
  priorities=$(get_priorities "$tasks")

  echo -e "${BOLD}${GREEN}Priorisoidut tehtävät:${RESET}\n$priorities\n"
}

# Run the script
main "$@"