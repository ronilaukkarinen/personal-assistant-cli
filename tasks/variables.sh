# Ensure cron stuff
SHELL=/bin/bash
export TZ=Europe/Helsinki
export LANG=fi_FI.UTF-8

# Get absolute path of the script
script_path=$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)

# Eliminate possible /tasks from the path if running from the tasks directory
script_path=${script_path%/tasks}

# Load the .env file dynamically, regardless of where the script is run from
if [ -f "${script_path}/.env" ]; then
  source "${script_path}/.env"
else
  echo "Error: .env file not found!"
  exit 1
fi

# .env
TODOIST_API_KEY=${TODOIST_API_KEY}
OPENAI_API_KEY=${OPENAI_API_KEY}
GOOGLE_CLIENT_ID=${GOOGLE_CLIENT_ID}
GOOGLE_CLIENT_SECRET=${GOOGLE_CLIENT_SECRET}
OURA_ACCESS_TOKEN=${OURA_ACCESS_TOKEN}
GENERAL_PROMPT=${GENERAL_PROMPT}

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
elif is_holiday; then
  SELECTED_PROJECT=""
  PROMPT_BGINFO=${LEISURE_PROMPT_BGINFO}
  PROMPT=${LEISURE_PROMPT}
else
  SELECTED_PROJECT="Todo"
  PROMPT_BGINFO=${WORK_PROMPT_BGINFO}
  PROMPT=${WORK_PROMPT}
fi
