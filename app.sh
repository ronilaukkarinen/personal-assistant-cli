#!/bin/bash
# Script version
export SCRIPT_VERSION="1.4.5"

# Vars needed for this file to function globally
SCRIPTS_LOCATION="$( cd "$( dirname "${BASH_SOURCE[0]}" )" && pwd )"

# Import required tasks
source ${SCRIPTS_LOCATION}/tasks/imports.sh
