#!/bin/bash

# Ensure a command is provided
if [ "$#" -eq 0 ]; then
    echo "Usage: $0 <command>"
    exit 1
fi

# Create log directory if it doesn't exist
LOG_DIR="$HOME/Documents/nohup_logs"
mkdir -p "$LOG_DIR"

# Generate a timestamped log file
TIMESTAMP=$(date +"%Y%m%d_%H%M%S")
LOG_FILE="$LOG_DIR/nohup_$TIMESTAMP.log"

# Run the command in the background
nohup "$@" > "$LOG_FILE" 2>&1 &

echo "Command is running in the background."
echo "Logs: $LOG_FILE"
