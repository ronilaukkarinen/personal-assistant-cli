# Load API keys from `.env` file
source .env

# .env
TODOIST_API_KEY=${TODOIST_API_KEY}
OPENAI_API_KEY=${OPENAI_API_KEY}
GOOGLE_CLIENT_ID=${GOOGLE_CLIENT_ID}
GOOGLE_CLIENT_SECRET=${GOOGLE_CLIENT_SECRET}

# Define color codes for formatting
BOLD=$(tput bold)
RESET=$(tput sgr0)
GREEN=$(tput setaf 2)
YELLOW=$(tput setaf 3)
RED=$(tput setaf 1)
CYAN=$(tput setaf 6)
PURPLE=$(tput setaf 5)

# Leave empty if all tasks should be fetched
if is_leisure_time; then
  SELECTED_PROJECT=""
  PROMPT_BGINFO=${LEISURE_PROMPT_BGINFO}
  PROMPT=${LEISURE_PROMPT}
else
  SELECTED_PROJECT="Todo"
  PROMPT_BGINFO=${WORK_PROMPT_BGINFO}
  PROMPT=${WORK_PROMPT}
fi

# Usage
usage() {
  echo "Usage: $0 [--days <number>] [--debug]"
  echo "  --days <number>  Process the next <number> of days"
  echo "  --debug          Enable debug mode"
  echo "  --killswitch     Exit immediately in the defined position for debugging"
  exit 1
}

# Show usage with --help
if [ "$1" = "--help" ]; then
  usage
fi

# Make it possible to use --debug in any position
if [ "$1" = "--debug" ]; then
  DEBUG=true
  shift
else
  DEBUG=false
fi

# Add --killswitch flag
if [ "$1" = "--killswitch" ]; then
  KILLSWITH=true
fi

# Parse command-line arguments
while [[ $# -gt 0 ]]; do
  case $1 in
    --days)
      days_to_process="$2"
      shift # shift past --days
      shift # shift past the value of --days
      ;;
    --debug)
      DEBUG=true
      shift # shift past --debug
      ;;
    --killswitch)
      KILLSWITH=true
      shift # shift past --killswitch
      ;;
    *)
      usage
      ;;
  esac
done
