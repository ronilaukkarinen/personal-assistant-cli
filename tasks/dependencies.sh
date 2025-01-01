# If not debian based or macOS, exit
if [ "$(uname)" != "Darwin" ] && [ "$(uname)" != "Linux" ]; then
  echo "This script only supports macOS and debian based Linux."
  exit 1
fi

# Check if jq is installed, install it for the user if not
if ! command -v jq &> /dev/null; then
  echo "Installing jq..."
  # If macOS
  if [ "$(uname)" == "Darwin" ]; then
    brew install jq
  else
    # If Linux
    sudo apt-get update
    sudo apt-get install -y jq
  fi
fi

# Check if curl is installed, install it for the user if not
if ! command -v curl &> /dev/null; then
  # If macOS
  if [ "$(uname)" == "Darwin" ]; then
    brew install curl
  else
    # If Linux
    sudo apt-get install curl
  fi
fi

# Install Finnish locale if not present
if ! locale -a | grep -i "fi_FI.utf8" > /dev/null; then
  echo "Installing Finnish locale..."
  if [ "$(uname)" == "Darwin" ]; then
    # macOS handles locales differently, no action needed
    :
  else
    # For Linux
    sudo apt-get update
    sudo apt-get install -y locales
    sudo locale-gen fi_FI.UTF-8
    sudo update-locale
  fi
fi
