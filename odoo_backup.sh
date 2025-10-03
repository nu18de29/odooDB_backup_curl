#!/bin/bash

# ==============================================================================
# ODOO BACKUP & TELEGRAM NOTIFICATION SCRIPT
# Run by: Inbox Inc
# Target OS: Ubuntu 24.04LTS (Backup Server)
# ==============================================================================

# ----------------- CONFIGURATION START -----------------
# Odoo Server Details
ODOO_HOST="192.x.x.x"       #IP Host server Odoo
ODOO_PORT="8069"            #Port web database manager
ODOO_MASTER_PWD="SuperAdmin12345"       #Master PASSWORD
ODOO_DB_NAME="Database_Odoo"    #Database name.

# Backup Storage Details
BACKUP_DIR="/home/backups" #Folder for store file backup.
DAYS_TO_KEEP=7      #Delete files in a directory older then 7 days.

# Telegram Notification Details
TELEGRAM_BOT_TOKEN="xxxxxxxx:xxxxxxxxxxxxxxxxxxxxxxxxxxxx"  #Telegram Token.
TELEGRAM_CHAT_ID="-xxxxxxxx"                                #Telegram Group/Chart ID

# Log & Timestamp
TIMESTAMP=$(date +"%Y%m%d_%H%M%S")
BACKUP_FILENAME="${ODOO_DB_NAME}_${TIMESTAMP}.zip"
LOG_FILE="${BACKUP_DIR}/backup_log_${TIMESTAMP}.log"
# ----------------- CONFIGURATION END -----------------


# --- FUNCTION: TELEGRAM NOTIFICATION ---
send_telegram_notification() {
    local MESSAGE=$1
    curl -s -X POST \
         -d chat_id="${TELEGRAM_CHAT_ID}" \
         -d text="${MESSAGE}" \
         "https://api.telegram.org/bot${TELEGRAM_BOT_TOKEN}/sendMessage" > /dev/null
}


# --- SCRIPT START ---
echo "[${TIMESTAMP}] Starting Odoo Backup for database: ${ODOO_DB_NAME}" >> ${LOG_FILE}

# 1. Prepare Environment
mkdir -p ${BACKUP_DIR}

# 2. Start Backup Process using CURL
BACKUP_START_TIME=$(date +%s)
BACKUP_STATUS=$(
    curl -s -X POST \
        -F "master_pwd=${ODOO_MASTER_PWD}" \
        -F "name=${ODOO_DB_NAME}" \
        -F "backup_format=zip" \
        -o "${BACKUP_DIR}/${BACKUP_FILENAME}" \
        http://${ODOO_HOST}:${ODOO_PORT}/web/database/backup
    echo $?
)
BACKUP_END_TIME=$(date +%s)
BACKUP_DURATION=$((BACKUP_END_TIME - BACKUP_START_TIME))

# 3. Check Backup Status
if [ "$BACKUP_STATUS" -eq 0 ] && [ -f "${BACKUP_DIR}/${BACKUP_FILENAME}" ] && [ $(stat -c%s "${BACKUP_DIR}/${BACKUP_FILENAME}") -gt 1024 ]; then
    MINUTES=$((BACKUP_DURATION / 60))
    REMAINING_SECONDS=$((BACKUP_DURATION % 60))
    FORMATTED_DURATION="${MINUTES}m ${REMAINING_SECONDS}s"
    
    FILE_SIZE=$(du -h "${BACKUP_DIR}/${BACKUP_FILENAME}" | awk '{print $1}')
    
    SUCCESS_MESSAGE="✅ Odoo Backup Success! (DB: ${ODOO_DB_NAME})"
    SUCCESS_MESSAGE+=$'\n'"Server: ${ODOO_HOST}"
    SUCCESS_MESSAGE+=$'\n'"Filename: ${BACKUP_FILENAME}"
    SUCCESS_MESSAGE+=$'\n'"Size: ${FILE_SIZE}"
    SUCCESS_MESSAGE+=$'\n'"Duration: ${FORMATTED_DURATION}"
    
    echo "[${TIMESTAMP}] Backup successful. File: ${BACKUP_FILENAME}, Size: ${FILE_SIZE}, Duration: ${BACKUP_DURATION}s" >> ${LOG_FILE}
    send_telegram_notification "${SUCCESS_MESSAGE}"

    # 4. Clean up Old Backups (Only run if backup was successful)
    echo "[${TIMESTAMP}] Starting cleanup: Deleting files older than ${DAYS_TO_KEEP} days..." >> ${LOG_FILE}
    
    FIND_OUTPUT=$(find "${BACKUP_DIR}" -type f -mtime +"${DAYS_TO_KEEP}" -name "*.zip" -print)
    
    if [ -z "$FIND_OUTPUT" ]; then
        echo "[${TIMESTAMP}] No old backup files found to delete." >> ${LOG_FILE}
    else
        echo -e "Files deleted:\n${FIND_OUTPUT}" >> ${LOG_FILE}
        find "${BACKUP_DIR}" -type f -mtime +"${DAYS_TO_KEEP}" -name "*.zip" -delete
        send_telegram_notification "🗑️ Cleanup Complete: Deleted old Odoo backups from ${ODOO_HOST}."
    fi

else
    ERROR_MESSAGE="❌ Odoo Backup FAILED! (DB: ${ODOO_DB_NAME})"
    ERROR_MESSAGE+=$'\n'"Server: ${ODOO_HOST}"
    ERROR_MESSAGE+=$'\n'"Error Code: ${BACKUP_STATUS}"
    
    echo "[${TIMESTAMP}] Backup FAILED. CURL exit code: ${BACKUP_STATUS}" >> ${LOG_FILE}
    send_telegram_notification "${ERROR_MESSAGE}"
fi

echo "[${TIMESTAMP}] Script finished." >> ${LOG_FILE}

# --- SCRIPT END ---
