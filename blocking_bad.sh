# Alias bb: Downloads and runs the blocking_bad hosts update script
# Usage: bb
# Project: blocking_bad
alias bb='_run_blocking_bad_updater'

# Helper function for the 'bb' alias
_run_blocking_bad_updater() {
  # --- Configuration ---
  # !!! ---> REPLACE THIS URL with the *RAW* URL of your blocking_bad.sh on GitHub <--- !!!
  local SCRIPT_URL="https://raw.githubusercontent.com/YOUR_USERNAME/blocking_bad/main/blocking_bad.sh" # EXAMPLE URL - CHANGE IT!
  local SCRIPT_DIR="$HOME/scripts/blocking_bad"
  local SCRIPT_PATH="$SCRIPT_DIR/blocking_bad.sh"
  local TEMP_SCRIPT_PATH="/tmp/blocking_bad_download.$$.sh"
  # --- End Configuration ---

  echo "--- [bb Alias] Initializing blocking_bad update ---"

  # 1. Ensure local script directory exists
  echo "[bb Alias] Ensuring script directory exists: $SCRIPT_DIR"
  if ! mkdir -p "$SCRIPT_DIR"; then
      echo "[bb Alias] ERROR: Failed to create script directory '$SCRIPT_DIR'. Check permissions." >&2
      return 1
  fi

  # 2. Download the latest script from GitHub
  echo "[bb Alias] Downloading latest script from $SCRIPT_URL..."
  # curl options: -s (silent), -f (fail fast on server errors), -L (follow redirects), -o (output file)
  if curl -sfLo "$TEMP_SCRIPT_PATH" "$SCRIPT_URL"; then
    echo "[bb Alias] Download successful."

    # Basic check: Ensure downloaded file is not empty
    if [ ! -s "$TEMP_SCRIPT_PATH" ]; then
        echo "[bb Alias] ERROR: Downloaded script is empty. Check URL or network." >&2
        rm -f "$TEMP_SCRIPT_PATH"
        # Fallback to existing script if download failed properly
        if [ -x "$SCRIPT_PATH" ]; then
            echo "[bb Alias] Attempting to run existing local script: $SCRIPT_PATH"
            # Proceed to execution step below
        else
             echo "[bb Alias] ERROR: Download failed and no executable local script found at $SCRIPT_PATH." >&2
             return 1
        fi
    else
        # 3. Replace old script and set permissions
        echo "[bb Alias] Replacing local script with downloaded version."
        if ! mv "$TEMP_SCRIPT_PATH" "$SCRIPT_PATH"; then
            echo "[bb Alias] ERROR: Failed to move downloaded script to $SCRIPT_PATH." >&2
            rm -f "$TEMP_SCRIPT_PATH" # Clean up temp file
            return 1
        fi

        echo "[bb Alias] Making script executable: $SCRIPT_PATH"
        if ! chmod +x "$SCRIPT_PATH"; then
            echo "[bb Alias] ERROR: Failed to make script $SCRIPT_PATH executable." >&2
            # Attempt to continue if script was already there and maybe executable
            if [ ! -x "$SCRIPT_PATH" ]; then
                return 1
            fi
        fi
    fi # End check for non-empty download
  else
    # Curl failed
    echo "[bb Alias] ERROR: Failed to download script from $SCRIPT_URL (curl exit code: $?)." >&2
    rm -f "$TEMP_SCRIPT_PATH" # Clean up potentially incomplete temp file

    if [ -x "$SCRIPT_PATH" ]; then
      echo "[bb Alias] Download failed. Attempting to run existing local script: $SCRIPT_PATH"
      # Proceed to execution step below
    else
      echo "[bb Alias] ERROR: Download failed and no executable local script found at $SCRIPT_PATH. Aborting." >&2
      return 1
    fi
  fi

  # 4. Execute the script using sudo
  echo "[bb Alias] Executing script with sudo: $SCRIPT_PATH"
  echo "--- [bb Alias] Handing over to blocking_bad.sh ---"
  # Pass any arguments originally given to 'bb' to the script
  sudo "$SCRIPT_PATH" "$@"

  local exit_code=$?
  echo "--- [bb Alias] blocking_bad.sh finished (Exit Code: $exit_code) ---"
  return $exit_code
}

# Ensure helper function is exported if needed, though direct alias use is typical
# export -f _run_blocking_bad_updater # Generally not needed for aliases in .bashrc
