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

# Leave empty if all tasks should be fetched
if is_leisure_time; then
  SELECTED_PROJECT=""
  PROMPT_BGINFO=${LEISURE_PROMPT_BGINFO}
  PROMPT_NOTES=${LEISURE_PROMPT_NOTES}
else
  SELECTED_PROJECT="Todo"
  PROMPT_BGINFO=${WORK_PROMPT_BGINFO}
  PROMPT_NOTES=${WORK_PROMPT_NOTES}
fi
