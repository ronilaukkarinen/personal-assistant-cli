# Add file to the root directory
LAST_RUN_FILE=".last_run"

# Aikaraja minuuteissa (esim. 10 minuuttia)
TIME_LIMIT_MINUTES=5
TIME_LIMIT_SECONDS=$((TIME_LIMIT_MINUTES * 60))

# Tarkista, onko viimeisin ajo tehty liian äskettäin
check_last_run_time() {
  if [ -f "$LAST_RUN_FILE" ]; then
    last_run_time=$(cat "$LAST_RUN_FILE")
    current_time=$(date +%s)

    time_since_last_run=$((current_time - last_run_time))

    if [ "$time_since_last_run" -lt "$TIME_LIMIT_SECONDS" ]; then
      time_left=$((TIME_LIMIT_SECONDS - time_since_last_run))
      echo -e "${BOLD}${RED}Application has been run recently. Please wait $((time_left / 60)) more minutes and $(($time_left % 60)) seconds to re-run.${RESET}"
      echo -e ""
      exit 1
    fi
  fi
}

update_last_run_time() {
  date +%s > "$LAST_RUN_FILE"
}

check_last_run_time
update_last_run_time
echo -e "${BOLD}${YELLOW}Running app...${RESET}"
echo -e ""
