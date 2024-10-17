# Batch process tasks
function batch() {
  echo -e "${BOLD}${YELLOW}Processing tasks from $start_day for the next $days_to_process days...${RESET}"

  # Killswitch for debugging
  if [ "$KILLSWITH" = true ]; then
    echo -e "${BOLD}${RED}Killswitch enabled, exiting immediately...${RESET}"
    exit 1
  fi
}

batch
