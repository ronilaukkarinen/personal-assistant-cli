# Check if it's leisure time
source ${SCRIPTS_LOCATION}/tasks/check-leisure.sh

# Calculate remaining hours in the day
source ${SCRIPTS_LOCATION}/tasks/calculate-remaining-hours.sh

# Import required variables
source ${SCRIPTS_LOCATION}/tasks/variables.sh

# Check dependencies
source ${SCRIPTS_LOCATION}/tasks/dependencies.sh

# Fetch tasks from Todoist
source ${SCRIPTS_LOCATION}/tasks/todoist.sh

# Fetch events from Google Calendar
source ${SCRIPTS_LOCATION}/tasks/gcal.sh

# Postpone tasks
source ${SCRIPTS_LOCATION}/tasks/postpone.sh

# Prioritize with OpenAI
source ${SCRIPTS_LOCATION}/tasks/openai.sh

# Main function
source ${SCRIPTS_LOCATION}/tasks/main.sh
