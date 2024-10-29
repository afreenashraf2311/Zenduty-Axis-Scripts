#!/bin/bash

# Validate and set the log directory from the environment variable
if [[ -z "$LOG_DIR" ]]; then
    echo "Error: LOG_DIR environment variable is not set."
    exit 1
fi

# Validate and set the alert URL from the environment variable
if [[ -z "$ALERT_URL" ]]; then
    echo "Error: ALERT_URL environment variable is not set."
    exit 1
fi

# Validate and set batch times from environment variables
UPLOAD_SLOTS=("${UPLOAD_SLOT_1}" "${UPLOAD_SLOT_2}" "${UPLOAD_SLOT_3}" "${UPLOAD_SLOT_4}")

for batch in "${UPLOAD_SLOTS[@]}"; do
    if [[ -z "$batch" ]]; then
        echo "Error: One or more batch times (UPLOAD_SLOT_1, UPLOAD_SLOT_2, UPLOAD_SLOT_3, UPLOAD_SLOT_4) are not set."
        exit 1
    fi
done

# Get the current date in the format YYYYMMDD
CURRENT_DATE=$(date -u +"%Y%m%d")

# Get the current hour and minute in the format HHMM
CURRENT_TIME=$(date -u +"%H%M")

# Function to send alert via curl
send_alert() {
    echo "Sending alert to $ALERT_URL"
    curl -s "$ALERT_URL"
}

# Function to construct log file name based on batch time (5 minutes earlier)
construct_log_name() {
    local batch_time="$1"

    # Subtract 5 minutes
    local hour="${batch_time:0:2}"
    local minute="${batch_time:2:2}"

    # Adjust minutes and wrap around if necessary
    minute=$((10#$minute - 5))
    if [[ $minute -lt 0 ]]; then
        minute=55
        hour=$((10#$hour - 1))
        if [[ $hour -lt 0 ]]; then
            hour=23  # Wrap around to previous day if necessary
        fi
    fi

    # Format hour and minute to always be two digits
    printf -v hour "%02d" "$hour"
    printf -v minute "%02d" "$minute"

    echo "atostle_settlementfile_merge_${CURRENT_DATE}${hour}${minute}.log"
}

# Loop through the batch times to set the TARGET_LOG
for i in "${!UPLOAD_SLOTS[@]}"; do
    if [[ "$CURRENT_TIME" == "${UPLOAD_SLOTS[$i]}" ]]; then
        TARGET_LOG=$(construct_log_name "${UPLOAD_SLOTS[$i]}")
        break  
    fi
done

# Full path to the target log file
TARGET_LOG_PATH="$LOG_DIR/$TARGET_LOG"

# Check if the log file exists
if [[ ! -f "$TARGET_LOG_PATH" ]]; then
    echo "Log file $TARGET_LOG_PATH does not exist."
    send_alert
    exit 1                                                                
fi

# Check the last few lines of the log file
LAST_LINES=$(tail -n 10 "$TARGET_LOG_PATH")

# Validate the log content
if echo "$LAST_LINES" | grep -q "Transfer finished"; then
    echo "Transfer finished successfully."
else
    echo "Transfer not finished in file: $TARGET_LOG."
    send_alert
fi



# How to run the script
# 55 10,14,16,17 * * * LOG_DIR="/home/ezetap/sftp/AXIS/cronlogs" ALERT_URL="Zenduty.com" UPLOAD_SLOT_1="1055" UPLOAD_SLOT_2="1455" UPLOAD_SLOT_3="1655" UPLOAD_SLOT_4="1755" /path/to/SftpFileUpload.sh
