#!/bin/bash

# Check if UPLOAD_DIR is set in the environment
if [[ -z "$UPLOAD_DIR" ]]; then
    echo "Error: The UPLOAD_DIR environment variable is not set. Exiting."
    exit 1
fi

# Validate UPLOAD_DIR
if [[ ! -d "$UPLOAD_DIR" ]]; then
    echo "Error: The directory '$UPLOAD_DIR' does not exist. Exiting."
    exit 1
fi

# Validate and set the alert URL from the environment variable
if [[ -z "$ALERT_URL" ]]; then
    echo "Error: ALERT_URL environment variable is not set."
    exit 1
fi

# Define variables
CURRENT_DATE=$(date +"%Y%m%d")
CURRENT_READABLE_DATE=$(date +"%Y-%m-%d")
HOUR=$(date +"%H")
MINUTE=$(date +"%M")
CHECK_HOUR=""
BATCH_NUMBER=""

# Function to send alert via curl
send_alert() {
    echo "Sending alert to $ALERT_URL"
    curl -s "$ALERT_URL"
}

# Determine which hour to check based on current time           
case $HOUR in
    10) CHECK_HOUR="10" ; BATCH_NUMBER="1" ;;
    14) CHECK_HOUR="14" ; BATCH_NUMBER="2" ;;
    16) CHECK_HOUR="16" ; BATCH_NUMBER="3" ;;
    17) CHECK_HOUR="17" ; BATCH_NUMBER="4" ;;
esac

# Construct expected file name patterns
BQRUPI_FILE_PATTERN="EZETAP_H2H_SETTLEMENT_BQRUPI_${CURRENT_DATE}_*.csv"
CARD_FILE_PATTERN="EZETAP_H2H_SETTLEMENT_${CURRENT_DATE}_*.csv"

# Check for files created from the start of the hour to the current time
FOUND_BQRUPI_FILES=($(find "${UPLOAD_DIR}" -name "${BQRUPI_FILE_PATTERN}" -newermt "${CURRENT_READABLE_DATE} ${CHECK_HOUR}:00" ! -newermt "${CURRENT_READABLE_DATE} ${CHECK_HOUR}:${MINUTE}"))
FOUND_CARD_FILES=($(find "${UPLOAD_DIR}" -name "${CARD_FILE_PATTERN}" -newermt "${CURRENT_READABLE_DATE} ${CHECK_HOUR}:00" ! -newermt "${CURRENT_READABLE_DATE} ${CHECK_HOUR}:${MINUTE}"))

# Validate files
BQRUPI_FILE_FOUND=false
CARD_FILE_FOUND=false

if [[ ${#FOUND_BQRUPI_FILES[@]} -gt 0 ]]; then
    echo "BQRUPI Settlement files found: ${FOUND_BQRUPI_FILES[@]}"
    BQRUPI_FILE_FOUND=true
else
    echo "BQRUPI Settlement file is missing: ${BQRUPI_FILE_PATTERN}"
fi

if [[ ${#FOUND_CARD_FILES[@]} -gt 0 ]]; then
    echo "CARD settlement files found: ${FOUND_CARD_FILES[@]}"
    CARD_FILE_FOUND=true
else
    echo "CARD settlement file is missing: ${CARD_FILE_PATTERN}"
fi

# Check if both files are found    
if ! $BQRUPI_FILE_FOUND && ! $CARD_FILE_FOUND; then
    echo "All files are missing for batch ${BATCH_NUMBER}."
    send_alert
elif ! $BQRUPI_FILE_FOUND || ! $CARD_FILE_FOUND; then
    echo "Some files are missing for batch ${BATCH_NUMBER}."
    send_alert
else
    echo "Both files are present for batch ${BATCH_NUMBER}."
fi




# Command to run the script
# 50 10,14,16,17 * * * UPLOAD_DIR="/home/ezetap/sftp/AXIS/atossettlementarchive" ALERT_URL="Zenduty.com" /path/to/EmsPosting.sh

