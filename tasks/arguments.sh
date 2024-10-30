#!/bin/bash

# Default values for options
DEBUG=false
KILLSWITCH=false
FORCE=false
mode=""
start_day=""
days_to_process=""

# Usage function
usage() {
  echo "Usage: $0 [--days <number>] [--debug] [--killswitch] [--force] [--start-day YYYY-MM-DD] [--one-batch]"
  echo "  --days <number>     Process the next <number> of days"
  echo "  --debug             Enable debug mode"
  echo "  --killswitch        Exit immediately in the defined position for debugging"
  echo "  --force             Force the script to run even if the schedule has already been made for the day"
  echo "  --start-day         Start processing tasks from a specific day (format: YYYY-MM-DD)"
  echo "  --one-batch         Process all days in one batch, requires --days and --start-day"
  exit 1
}

# Print all arguments (for debugging purposes)
if [ "$DEBUG" = true ]; then
  echo "All arguments: $@"
fi

# Exit early if no arguments are passed
if [ "$#" -eq 0 ]; then
  usage
fi

# Parse command-line arguments
while [[ "$#" -gt 0 ]]; do
  case "$1" in
    --debug)
      DEBUG=true
      shift
      ;;
    --killswitch)
      KILLSWITCH=true
      shift
      ;;
    --force)
      FORCE=true
      shift
      ;;
    --help)
      usage
      ;;
    --start-day)
      shift
      if [[ "$1" =~ ^[0-9]{4}-[0-9]{2}-[0-9]{2}$ ]]; then
        start_day="$1"
        if [ "$DEBUG" = true ]; then
          echo "${CYAN}Parsed start day: $start_day${RESET}"
        fi
      else
        echo "Error: --start-day argument requires a valid date in the format YYYY-MM-DD."
        exit 1
      fi
      shift
      ;;
    --one-batch)
      if [[ -n "$days_to_process" && -n "$start_day" ]]; then
        mode="batch"
      else
        echo "Error: --one-batch argument requires --days and --start-day."
        exit 1
      fi
      shift
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
      shift
      ;;
    *)
      echo "Unknown argument: $1"
      usage
      exit 1
      ;;
  esac
done

# Debug output if debug mode is enabled
if [ "$DEBUG" = true ]; then
  echo "Debug Mode: $DEBUG"
  echo "Killswitch: $KILLSWITCH"
  echo "Force: $FORCE"
  echo "Start Day: $start_day"
  echo "Days to Process: $days_to_process"
  echo "Mode: $mode"
fi

# Activate killswitch if set
if [ "$KILLSWITCH" = true ]; then
  echo "Killswitch enabled, exiting immediately."
  exit 1
fi

# Batch processing check
if [ "$mode" = "batch" ]; then
  source "${SCRIPTS_LOCATION}/tasks/batch.sh"
  exit 0
fi
