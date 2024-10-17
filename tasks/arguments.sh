# Defaults
DEBUG=false
KILLSWITCH=false
FORCE=false

DEBUG=false
KILLSWITCH=false
FORCE=false

# Usage
usage() {
  echo "Usage: $0 [--days <number>] [--debug]"
  echo "  --days <number>  Process the next <number> of days"
  echo "  --debug          Enable debug mode"
  echo "  --killswitch     Exit immediately in the defined position for debugging"
  echo "  --force          Force the script to run even if the schedule has already been made for the day"
  echo "  --start-day      Start processing tasks from a specific day (format: YYYY-MM-DD)"
  echo "  --one-batch      Process all days in one batch, requires --days and --start-day"
  exit 1
}

# Parse command-line arguments
while [[ "$#" -gt 0 ]]; do
  case "$1" in
    --debug)
      DEBUG=true
      ;;
    --killswitch)
      KILLSWITCH=true
      ;;
    --force)
      FORCE=true
      ;;
    --help)
      usage
      ;;
    --start-day)
      shift
      if [[ "$1" =~ ^[0-9]{4}-[0-9]{2}-[0-9]{2}$ ]]; then
        start_day="$1"
      else
        echo "Error: --start-day argument requires a valid date in the format YYYY-MM-DD."
        exit 1
      fi
      ;;
    --one-batch)
      shift
      if [[ -n "$days_to_process" && -n "$start_day" ]]; then
        mode="batch"
      else
        echo "Error: --one-batch argument requires --days and --start-day."
        exit 1
      fi
      ;;
    --days)
      shift
      if [[ "$1" =~ ^[0-9]+$ ]]; then
        days_to_process="$1"
        mode="days"
      else
        echo "Error: --days argument requires a valid number."
        exit 1
      fi
      ;;
    *)
      echo "Unknown argument: $1"
      usage
      exit 1
      ;;
  esac
  shift
done

# Debug modes set
if [ "$DEBUG" = true ]; then
  echo -e "${BOLD}${CYAN}Debug: $DEBUG.${RESET}"
  echo -e "${BOLD}${CYAN}Killswitch: $KILLSWITCH${RESET}"
  echo -e "${BOLD}${CYAN}Force: $FORCE${RESET}"
  echo -e "${BOLD}${CYAN}Mode: $mode${RESET}"
fi

if [ "$KILLSWITCH" = true ]; then
  echo -e "${BOLD}${RED}Killswitch enabled, exiting immediately...${RESET}"
  exit 1
fi

# If mode is batch, process only these functions and skip the rest
if [ "$mode" = "batch" ]; then
  source "${SCRIPTS_LOCATION}/tasks/batch.sh"
  exit 0
fi
