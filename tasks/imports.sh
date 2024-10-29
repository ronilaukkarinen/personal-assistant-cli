# Check if it's leisure time
source ${SCRIPTS_LOCATION}/tasks/check-leisure.sh

# Calculate remaining hours in the day
source ${SCRIPTS_LOCATION}/tasks/calculate-remaining-hours.sh

# Import required variables
source ${SCRIPTS_LOCATION}/tasks/variables.sh

# Command line arguments
source ${SCRIPTS_LOCATION}/tasks/arguments.sh

# Print header
source ${SCRIPTS_LOCATION}/tasks/header.sh

# Check dependencies
source ${SCRIPTS_LOCATION}/tasks/dependencies.sh

# Add events as Todoist tasks
source ${SCRIPTS_LOCATION}/tasks/sync-google-calendar-to-todoist.sh

# Fetch tasks from Todoist
source ${SCRIPTS_LOCATION}/tasks/todoist.sh

# Schedule tasks
source ${SCRIPTS_LOCATION}/tasks/schedule.sh

# Prioritize with OpenAI
source ${SCRIPTS_LOCATION}/tasks/openai.sh

# Get timezone
source ${SCRIPTS_LOCATION}/tasks/timezone.sh

# Main function
source ${SCRIPTS_LOCATION}/tasks/main.sh

# Clean ups
source ${SCRIPTS_LOCATION}/tasks/cleanup-notes.sh
