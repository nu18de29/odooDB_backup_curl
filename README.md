# Odoo Database Backup Script (with Telegram Notification)

This shell script automates the backup process for an **Odoo Database** by using `curl` to call the Odoo Web Database Manager endpoint.  
It is designed to run as a scheduled **Cron job** on a separate Linux server (e.g., Ubuntu 24.04 LTS), ensuring that backups are taken reliably, old files are purged, and the administrator is notified of the result via **Telegram**.

---

## Table of Contents
- [Features](#features)
- [Prerequisites](#prerequisites)
- [1. Setup and Configuration](#1-setup-and-configuration)
  - [1.1 Save the Script](#11-save-the-script)
  - [1.2 Update Configuration](#12-update-configuration)
  - [1.3 Set Permissions](#13-set-permissions)
- [2. Scheduling the Backup (Cron Job)](#2-scheduling-the-backup-cron-job)
  - [2.1 Open Crontab](#21-open-crontab)
  - [2.2 Add Cron Entry](#22-add-cron-entry)
- [How It Works (High Level)](#how-it-works-high-level)
- [Restore from the ZIP Backup](#restore-from-the-zip-backup)
- [Security Recommendations](#security-recommendations)
- [Troubleshooting](#troubleshooting)
- [File Structure](#file-structure)
- [License](#license)

---

## ✨ Features

- **Reliable Backup**: Bypasses web browser timeout issues by performing the backup via `curl`.
- **Complete Backup**: Generates a full `.zip` file (Database Dump + Filestore) compatible with the Odoo Web Database Manager for easy restoration.
- **Disk Management**: Automatically deletes backup files older than a specified number of days to prevent disk space exhaustion.
- **Telegram Notifications**: Sends detailed success or failure messages, including file size and backup duration, to a designated Telegram group/chat.
- **Duration Formatting**: Reports the backup time in `MMm SSs` format for easy reading.

---

## 🛠️ Prerequisites

To successfully deploy and run this script, ensure you have the following prerequisites:

- **Backup Server**: A Linux server (e.g., Ubuntu 24.04 LTS) with `curl`, `bash`, and (optional) PostgreSQL client utilities installed.
- **Network Access**: The Backup Server must be able to reach the Odoo Server via the configured IP and Port.
- **Telegram Bot**: A configured Telegram Bot Token and the Chat ID of the group/user for notifications.

---

## ⚙️ 1. Setup and Configuration

### 1.1 Save the Script
Save the provided script content into a file named `odoo_backup.sh` on your backup server, e.g.:

```bash
mkdir -p /home/scripts
nano /home/scripts/odoo_backup.sh
```

Paste the script content inside this file.

---

### 1.2 Update Configuration
Edit the `odoo_backup.sh` file and update the variables in the **CONFIGURATION START** section with your specific details:

| Variable              | Description                                                                 | Example Value          |
|-----------------------|-----------------------------------------------------------------------------|------------------------|
| `ODOO_HOST`           | IP address or hostname of your Odoo server                                  | `192.x.x.x`       |
| `ODOO_PORT` *(opt.)*  | Odoo HTTP port (default: `8069`)                                            | `8069`                 |
| `ODOO_MASTER_PWD`     | The Master Password configured in your Odoo server                          | `SuperAdmin12345`      |
| `ODOO_DB_NAME`        | The exact name of the Odoo database to back up                              | `Production_DB_2025`   |
| `BACKUP_DIR`          | Local path on the backup server to store the ZIP files (ensure write perms) | `/home/backups` |
| `RETENTION_DAYS`      | Number of days to keep backups (cleanup removes older files on success)     | `7`                    |
| `TELEGRAM_BOT_TOKEN`  | Your Telegram Bot's API token                                               | `123456789:AABBCC...`  |
| `TELEGRAM_CHAT_ID`    | The ID of the Telegram group/chat for notifications                         | `-1001234567890`       |

> **Note:** If your Odoo is behind HTTPS/Proxy, ensure the script’s URL scheme and host/port settings match your deployment.

---

### 1.3 Set Permissions
Make the script executable:

```bash
chmod +x /home/scripts/odoo_backup.sh
```

(Optional) Run once manually to verify output and Telegram notification:

```bash
/home/scripts/odoo_backup.sh
```

---

## ⏰ 2. Scheduling the Backup (Cron Job)

The script is designed to run automatically using **Cron** (under the same user that owns the script, e.g. `autoadmin`).

### 2.1 Open Crontab
Login as the user who owns the script and edit crontab:

```bash
crontab -e
```

### 2.2 Add Cron Entry
Add the following line to schedule the script to run **daily at 01:00 AM**:

```bash
# M H  D M W  CMD
# Run Odoo backup every day at 01:00 AM
0 1 * * * /home/scripts/odoo_backup.sh
```

> Tip: If you want to capture script output to a log file, you can redirect it in cron:
>
> ```bash
> 0 1 * * * /home/scripts/odoo_backup.sh >> /home/backups/backup.log 2>&1
> ```

---

## 🧠 How It Works (High Level)

1. The script calls Odoo’s Web Database Manager backup endpoint using `curl` with the configured **`ODOO_DB_NAME`** and **`ODOO_MASTER_PWD`**.
2. The HTTP response stream is saved as a `.zip` file into **`BACKUP_DIR`**, typically named with a timestamp.
3. On success, the script calculates the file size and elapsed time, sends a Telegram message, and removes old backups older than **`RETENTION_DAYS`**.
4. On failure, it sends a Telegram alert with the return code and skips cleanup to preserve any artifacts for diagnosis.

---

## ♻️ Restore from the ZIP Backup

The resulting `.zip` file is **compatible with Odoo’s Web Database Manager**:

1. Open your Odoo instance in a browser.
2. Go to **/web/database/manager** (Database Manager).
3. Choose **Restore** and provide the `.zip` file.
4. Enter the **Master Password** when prompted and follow the on-screen steps.

---

## 🔐 Security Recommendations

- Restrict file permissions: `chmod 700 /home/scripts` and `chmod 600 /home/scripts/odoo_backup.sh`.
- Store secrets securely (e.g., root-only file, environment variables, or a secrets manager).
- Limit network access between the Backup Server and Odoo to required ports only.
- Avoid committing credentials into version control.
- Ensure Telegram Bot access is limited to the target group/chat.

---

## 🐞 Troubleshooting

Before submitting a new issue, please verify the following common points:

| Issue               | Potential Cause(s)                                         | Solution                                                                 |
|---------------------|------------------------------------------------------------|--------------------------------------------------------------------------|
| **Backup FAILED**   | `curl` exit code (e.g., **6** or **7**)                    | Check Odoo server IP/Port (`ODOO_HOST`, `ODOO_PORT`). Verify connectivity.|
| **Backup FAILED**   | Large file size, no output, or `curl` exit code **22**     | Double-check `ODOO_MASTER_PWD` and `ODOO_DB_NAME` (Odoo returns error if incorrect). |
| **No Telegram msg** | Bot/Chat ID error                                          | Verify `TELEGRAM_BOT_TOKEN` and `TELEGRAM_CHAT_ID`. Ensure bot is in group and can post. |
| **No Cleanup**      | Cleanup logic runs only on success                         | Check the log file. If the backup failed, the cleanup step is skipped.    |

---

## 📂 File Structure

```
/home/scripts/
 └── odoo_backup.sh        # Backup script
/home/backups/
 ├── *.zip                 # Generated Odoo backups
 └── backup.log            # (Optional) Cron redirect log
```

---

