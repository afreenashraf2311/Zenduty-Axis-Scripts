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

# Validate ALERT_URL
if [[ -z "$ALERT_URL" ]]; then
    echo "Error: ALERT_URL environment variable is not set."
    exit 1
fi

# Validate upload slot hours are set in the environment
for i in {1..4}; do
    SLOT_VAR="UPLOAD_SLOT_$i"
    if [[ -z "${!SLOT_VAR}" ]]; then
        echo "Error: $SLOT_VAR environment variable is not set."
        exit 1
    fi
done

# Define variables
CURRENT_DATE=$(date +"%Y%m%d")
CURRENT_READABLE_DATE=$(date +"%Y-%m-%d")
HOUR=$(date +"%H")
MINUTE=$(date +"%M")
CHECK_HOUR=""
BATCH_NUMBER=""

# Function to trigger alert via curl
trigger_alert() {
    local summary="$1"
    local alert_type="$2"
    local message="$3"
    local entity_id="some_entity_id"

    # Check if EVENTS_API_KEY is set
    if [ -z "$EVENTS_API_KEY" ]; then
        echo "Error: EVENTS_API_KEY environment variable is not set."
        return 1
    fi

    # Construct the URL using the environment variable
    local url="https://events.zenduty.com/api/events/$EVENTS_API_KEY/"

    curl -X POST "$url" \
         -H "Content-Type: application/json" \
         -d "{\"alert_type\":\"$alert_type\", \"message\":\"$message\", \"summary\":\"$summary\", \"entity_id\":\"$entity_id\"}"
}

# Determine which hour to check based on current time and environment variables
case $HOUR in
    ${UPLOAD_SLOT_1}) CHECK_HOUR="${UPLOAD_SLOT_1}" ; BATCH_NUMBER="1" ;;
    ${UPLOAD_SLOT_2}) CHECK_HOUR="${UPLOAD_SLOT_2}" ; BATCH_NUMBER="2" ;;
    ${UPLOAD_SLOT_3}) CHECK_HOUR="${UPLOAD_SLOT_3}" ; BATCH_NUMBER="3" ;;
    ${UPLOAD_SLOT_4}) CHECK_HOUR="${UPLOAD_SLOT_4}" ; BATCH_NUMBER="4" ;;
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
    echo "All files are missing for upload slot ${BATCH_NUMBER}."
    trigger_alert "AXIS Settlement files are missing on EMS server $UPLOAD_DIR ." "critical" "AXIS Settlement Files Not Posted To EMS."
elif ! $BQRUPI_FILE_FOUND || ! $CARD_FILE_FOUND; then
    echo "Some files are missing for upload slot ${BATCH_NUMBER}."
    trigger_alert "AXIS Settlement files are missing on EMS server $UPLOAD_DIR ." "critical" "AXIS Settlement Files Not Posted To EMS."
else
    echo "Both files are present for upload slot ${BATCH_NUMBER}."
fi
