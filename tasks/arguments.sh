# Parse command-line arguments
while [[ "$#" -gt 0 ]]; do
  case "$1" in
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
      # Check if $days_to_process and $start_day are set correctly
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
    --debug)
      DEBUG=true
      ;;
    --killswitch)
      KILLSWITH=true
      ;;
    --force)
      FORCE=true
      ;;
    --help)
      usage
      ;;
    *)
      echo "Unknown argument: $1"
      usage
      exit 1
      ;;
  esac
  shift
done

# If mode is batch, process only these functions and skip the rest
if [ "$mode" = "batch" ]; then
  source "${SCRIPTS_LOCATION}/tasks/batch.sh"
  exit 0
fi
