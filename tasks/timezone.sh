get_timezone() {
  if [[ "$(uname)" == "Darwin" ]]; then
    # macOS: Get the timezone from the system configuration
    readlink /etc/localtime | sed 's|.*/zoneinfo/||'
  else
    # Linux: Get the timezone from /etc/timezone
    cat /etc/timezone
  fi
}
