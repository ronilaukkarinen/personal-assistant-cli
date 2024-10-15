#!/bin/bash
source ../.env

OURA_ACCESS_TOKEN=${OURA_ACCESS_TOKEN}

# Colors
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[0;33m'
CYAN='\033[0;36m'
RESET='\033[0m'

# Function to get readiness score from Oura API
get_readiness_score() {
    local today=$(date +%Y-%m-%d)

    # Fetch readiness data using Oura API
    response=$(curl -s --request GET \
      --url "https://api.ouraring.com/v2/usercollection/readiness?start_date=$today&end_date=$today" \
      --header "Host: api.ouraring.com" \
      --header "Authorization: Bearer $OURA_ACCESS_TOKEN")

    # Debug response
    echo -e "${CYAN}Response:${RESET}\n$response\n"

    # Extract readiness score from the response
    readiness_score=$(echo "$response" | jq -r '.data[0].score')

    # Check if readiness score was found
    if [[ "$readiness_score" == "null" ]]; then
        echo "No readiness data available for today."
    else
        echo "Today's readiness score: $readiness_score"
    fi
}

# Run the function to get readiness score
get_readiness_score
