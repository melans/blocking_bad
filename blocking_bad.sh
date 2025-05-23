#!/bin/bash

# ==============================================================================
# blocking_bad.sh - Hosts File Updater for Blocking Undesirable Content
# Project: blocking_bad
#
# Description: Downloads, combines, de-duplicates, and installs blocklists
#              (including adult, malware, ads, etc.) into /etc/hosts.
#              Designed for simplicity and portability on Debian-based systems.
#
# Usage:       Run via 'bb' alias (recommended) or directly: sudo ./blocking_bad.sh
#              The 'bb' alias handles downloading the latest version first.
#
# CRITICAL WARNING:
#              This script modifies the /etc/hosts file. It WILL NOT block
#              traffic from applications DESIGNED TO BYPASS system name
#              resolution, such as:
#                  - Tor Browser
#                  - Browsers using DNS-over-HTTPS (DoH) / Secure DNS features
#                    if configured to bypass the OS resolver.
#              It provides a significant hurdle for standard applications only.
#
# Author:      [Your Name/Handle Here] / Adapted from common examples
# Version:     1.2.2 (Improved sed regex escaping)
# ==============================================================================

# --- Configuration ---
# Reputable blocklist sources (hosts file format: IP<space>DOMAIN)
# Using 0.0.0.0 is generally preferred for instant connection refusal.
declare -a BLOCKLIST_URLS=(
  # StevenBlack Unified Hosts (ads, malware, fake news, gambling, porn, social) - Base list
  "https://raw.githubusercontent.com/StevenBlack/hosts/master/hosts"

  # blocklistproject specific lists (good supplement)
  "https://raw.githubusercontent.com/blocklistproject/Lists/master/ads.txt"
  "https://raw.githubusercontent.com/blocklistproject/Lists/master/porn.txt"
  "https://raw.githubusercontent.com/blocklistproject/Lists/master/malware.txt"
  "https://raw.githubusercontent.com/blocklistproject/Lists/master/phishing.txt"
  "https://raw.githubusercontent.com/blocklistproject/Lists/master/scam.txt"
  "https://raw.githubusercontent.com/blocklistproject/Lists/master/fraud.txt"
  # Add more reputable URLs here if needed, one per line within the quotes.
  # Ensure they provide lists in "IP domain" format. Comments usually start with #.
)

# System file paths and markers
readonly HOSTS_FILE="/etc/hosts"
readonly BACKUP_DIR="/etc/hosts.backups.blocking_bad" # Dedicated backup location
readonly MARKER_BEGIN="# BEGIN MANAGED BLOCKLIST (blocking_bad.sh v1.2) ### DO NOT EDIT MANUALLY BELOW ###"
readonly MARKER_END="# END MANAGED BLOCKLIST (blocking_bad.sh v1.2) ### Run 'bb' to update ###"

# Temporary working directory
TEMP_DIR="" # Assigned by mktemp

# --- Script Setup ---
# Exit immediately if a command exits with a non-zero status.
set -e
# Treat unset variables as an error when substituting.
# set -u # Can be too strict if scripts expect optional vars; keep commented unless needed.
# Pipe commands return status of the last command to exit with non-zero status
set -o pipefail

# --- Functions ---
log_message() {
  # Simple logger prefixing messages with script name and timestamp
  echo "[blocking_bad] [$(date +'%Y-%m-%d %H:%M:%S')] $1"
}

cleanup() {
  local exit_status=$?
  set +e # Disable exit on error during cleanup

  if [ -n "$TEMP_DIR" ] && [ -d "$TEMP_DIR" ]; then
    log_message "Cleaning up temporary directory: $TEMP_DIR"
    rm -rf "$TEMP_DIR"
  fi
  log_message "Cleanup finished (Script exit code was: $exit_status)."
}

check_command() {
  # Checks if a command exists, exits if not.
  if ! command -v "$1" &> /dev/null; then
    log_message "ERROR: Required command '$1' not found. Please install it."
    log_message "       (Example: sudo apt update && sudo apt install $1)"
    exit 1
  fi
}

# *** NEW/IMPROVED FUNCTION ***
escape_sed_regex() {
    # Escape characters special to sed's regex patterns: . * [ ] \ ^ $ ( ) /
    # Using printf for potentially safer handling than <<< with sed
    printf '%s' "$1" | sed -e 's/[]\/$*.^()[]/\\&/g'
}


# --- Pre-execution Checks ---
log_message "--- Starting blocking_bad Hosts Update ---"

# 1. Root Check
if [ "$(id -u)" -ne 0 ]; then
  log_message "ERROR: This script must be run as root (use sudo)." >&2
  exit 1
fi

# 2. Required Commands Check
check_command "curl"
check_command "grep"
check_command "sort"
check_command "awk"
check_command "sed"
check_command "mktemp"
check_command "wc"
check_command "date"
check_command "basename"
check_command "printf" # For the escape function

# 3. Create Temporary Directory and Register Cleanup
TEMP_DIR=$(mktemp -d "/tmp/blocking_bad.XXXXXX")
trap cleanup EXIT INT TERM # Ensure cleanup runs on exit/interrupt
log_message "Using temporary directory: $TEMP_DIR"

# --- Main Execution ---

# 1. Backup Hosts File
log_message "Ensuring backup directory exists: $BACKUP_DIR"
mkdir -p "$BACKUP_DIR" # Create dir if not present
BACKUP_FILE="${BACKUP_DIR}/hosts.backup.$(date +%Y%m%d_%H%M%S)"
log_message "Backing up current hosts file to $BACKUP_FILE"
cp "$HOSTS_FILE" "$BACKUP_FILE"

# 2. Download and Combine Lists
COMBINED_RAW_LIST="$TEMP_DIR/combined_raw.txt"
log_message "Downloading blocklists..."
touch "$COMBINED_RAW_LIST"
download_success_count=0
download_error_count=0

for url in "${BLOCKLIST_URLS[@]}"; do
  safe_basename=$(basename "$url" | sed 's/[^a-zA-Z0-9._-]/_/g')
  TEMP_LIST_DL="$TEMP_DIR/dl_${safe_basename}.tmp"
  log_message " -> Downloading: $url"
  if curl -sfL --connect-timeout 15 --max-time 60 "$url" -o "$TEMP_LIST_DL"; then
    if [ -s "$TEMP_LIST_DL" ]; then
      awk 'NF >= 2 && $1 ~ /^(0\.0\.0\.0|127\.0\.0\.1)$/ && $2 !~ /^#|^$/ { print $1 " " $2 }' "$TEMP_LIST_DL" >> "$COMBINED_RAW_LIST"
      log_message " -> Downloaded $(wc -l < "$TEMP_LIST_DL") lines, filtered and added valid entries."
      download_success_count=$((download_success_count + 1))
    else
      log_message " -> WARNING: Downloaded file from $url is empty. Skipping."
      download_error_count=$((download_error_count + 1))
    fi
  else
    curl_exit_code=$?
    log_message " -> ERROR: Failed to download from $url (curl exit code $curl_exit_code). Skipping."
    download_error_count=$((download_error_count + 1))
  fi
  rm -f "$TEMP_LIST_DL"
done

if [ $download_success_count -eq 0 ]; then
  log_message "ERROR: Failed to download any blocklists. No changes made to hosts file."
  exit 1
fi
if [ $download_error_count -gt 0 ]; then
  log_message "WARNING: $download_error_count blocklist downloads failed. Proceeding with successfully downloaded lists."
fi

# 3. Process Combined List (Deduplicate, Standardize, Sort)
PROCESSED_LIST="$TEMP_DIR/processed_list.txt"
log_message "Processing combined list: Standardizing to 0.0.0.0, removing duplicates..."

if [ ! -s "$COMBINED_RAW_LIST" ]; then
    log_message "WARNING: No valid host entries found after downloading/filtering."
    touch "$PROCESSED_LIST" # Ensure file exists
    PROCESSED_COUNT=0
else
    awk '$2 != "" {print "0.0.0.0 " $2}' "$COMBINED_RAW_LIST" | sort -u > "$PROCESSED_LIST"
    PROCESSED_COUNT=$(wc -l < "$PROCESSED_LIST")
fi

log_message "Processing complete. Found $PROCESSED_COUNT unique block entries."

if [ "$PROCESSED_COUNT" -eq 0 ] && [ $download_success_count -gt 0 ]; then
    log_message "WARNING: All downloaded entries were filtered out or invalid. Check blocklist source formats."
fi

# 4. Update Hosts File
log_message "Updating $HOSTS_FILE..."

# *** USE THE NEW ESCAPE FUNCTION ***
ESCAPED_MARKER_BEGIN=$(escape_sed_regex "$MARKER_BEGIN")
ESCAPED_MARKER_END=$(escape_sed_regex "$MARKER_END")

# Remove existing block managed by this script
log_message " -> Removing old blocking_bad section (if exists)..."
# *** Use | as delimiter, ensure variables are quoted if needed (though should be safe) ***
sed -i "\|^${ESCAPED_MARKER_BEGIN}$|,\|^${ESCAPED_MARKER_END}$|d" "$HOSTS_FILE"


# Prepare the new block content
TEMP_APPEND="$TEMP_DIR/hosts_append.txt"
{
  echo "" # Ensure newline before block
  echo "$MARKER_BEGIN"
  echo "# Updated: $(date)"
  echo "# Entries: $PROCESSED_COUNT"
  cat "$PROCESSED_LIST" # Add processed list content
  echo "$MARKER_END"
  echo "" # Ensure newline after block
} > "$TEMP_APPEND"

# Append the new block to the hosts file
log_message " -> Adding new blocking_bad section ($PROCESSED_COUNT entries)..."
cat "$TEMP_APPEND" >> "$HOSTS_FILE"

log_message "Hosts file update complete."

# 5. Attempt to Flush DNS Cache (Best effort)
log_message "Attempting to flush DNS cache..."
cache_flushed=false
if command -v resolvectl &> /dev/null && systemctl is-active --quiet systemd-resolved; then
   if resolvectl flush-caches; then log_message " -> resolvectl cache flushed."; cache_flushed=true; else log_message " -> resolvectl flush failed."; fi
elif command -v systemd-resolve &> /dev/null && systemctl is-active --quiet systemd-resolved; then
  if systemd-resolve --flush-caches; then log_message " -> systemd-resolved cache flushed."; cache_flushed=true; else log_message " -> systemd-resolve flush failed."; fi
elif command -v nscd &> /dev/null && systemctl is-active --quiet nscd; then
  if systemctl restart nscd; then log_message " -> nscd service restarted."; cache_flushed=true; else log_message " -> nscd restart failed."; fi
fi

if ! $cache_flushed; then
  log_message " -> Could not detect or flush common DNS cache automatically. Restart browser or network if needed."
fi

# --- Final Notes ---
log_message "Reminder: Tor Browser and DNS-over-HTTPS likely bypass these blocks."
log_message "Backup of previous hosts file is in: $BACKUP_FILE"

exit 0
