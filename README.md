# blocking_bad

A simple Bash script for Debian-based systems (like Debian, Ubuntu, Mint) to help block undesirable domains (including ads, malware, phishing, porn, fraud, etc.) by managing the `/etc/hosts` file. Designed for easy execution via a command-line alias.

---

> **⚠️ CRITICAL WARNING: Limitations** ⚠️
>
> This script modifies the `/etc/hosts` file. This method **WILL NOT** block traffic from applications specifically designed to bypass system name resolution. This includes:
>
> *   **Tor Browser:** Tor Browser resolves DNS requests through the Tor network, completely ignoring `/etc/hosts`.
> *   **Browsers using DNS-over-HTTPS (DoH) / Secure DNS:** If your browser (like Firefox or Chrome) is configured to use DoH directly (often enabled by default in some regions or configurations), it will bypass the system's `/etc/hosts` file for DNS lookups.
> *   **Direct IP Connections:** Accessing sites via their direct IP address will bypass this block.
>
> **This script provides a significant hurdle for *standard* applications respecting the system's hosts file, but it is NOT a foolproof solution against determined users or circumvention tools.**

---

## Features

*   Uses the `/etc/hosts` file for system-wide blocking (for applications that respect it).
*   Fetches and combines blocklists from reputable public sources (StevenBlack, blocklistproject).
*   Focuses on lists covering ads, malware, phishing, scams, fraud, and adult content.
*   Standardizes blocked entries to `0.0.0.0` for quick connection refusal.
*   Efficiently deduplicates entries from combined lists.
*   Automatically creates timestamped backups of your `/etc/hosts` file in `/etc/hosts.backups.blocking_bad/` before making changes.
*   Attempts to flush common DNS caches (systemd-resolved, nscd) after updates.
*   Designed for simple setup and execution via a single `bb` alias.
*   Provides informative logging during execution.

## How it Works

The primary intended use is via the `bb` alias:

1.  You run `bb` in your terminal.
2.  The alias executes a command string that:
    *   Navigates to your `$HOME` directory.
    *   Defines the script name (`blocking_bad.sh`) and the URL to fetch it from (`https://raw.githubusercontent.com/melans/blocking_bad/main/blocking_bad.sh`).
    *   Downloads the latest version of `blocking_bad.sh` from the repository using `curl`, overwriting any existing local copy in `$HOME`.
    *   Makes the downloaded script executable (`chmod +x`).
    *   Runs the script using `sudo` (root privileges are required to modify `/etc/hosts`).
3.  The `blocking_bad.sh` script then executes:
    *   Performs pre-flight checks (root user, required commands like `curl`, `awk`, `sed`, `sort`).
    *   Creates a backup of the current `/etc/hosts`.
    *   Downloads the blocklists defined in its `BLOCKLIST_URLS` array.
    *   Filters, combines, standardizes, and deduplicates the domain entries.
    *   Removes the previous `blocking_bad` block from `/etc/hosts` (identified by specific marker lines).
    *   Appends the newly generated blocklist between the markers in `/etc/hosts`.
    *   Attempts to flush the system DNS cache.
    *   Cleans up temporary files and exits.

## Installation / Setup

1.  **Add the `bb` Alias:** Add the main `bb` alias definition to your shell's startup file (e.g., `~/.bashrc`, `~/.zshrc`, `~/.mr`).

    ```sh
    alias bb='cd "$HOME" && SCRIPT="blocking_bad.sh"; URL="https://raw.githubusercontent.com/melans/blocking_bad/main/blocking_bad.sh"; echo "[bb] Ensuring latest $SCRIPT..."; curl -sfLo "$SCRIPT" "$URL" && chmod +x "$SCRIPT" && echo "[bb] Running $SCRIPT with sudo..." && sudo "$HOME/$SCRIPT" "$@" || echo "[bb] ERROR: Failed to download, prepare, or run $SCRIPT."'
    ```

2.  **(Optional) Add the `bbx` Reversal Alias:** If you want a quick command to undo the changes, you can add the `bbx` alias to the *same* startup file. See the "Restoring / Uninstalling" section below for details and alternative reversal methods.

3.  **Activate Aliases:** Either close and reopen your terminal, or manually source the startup file:
    ```bash
    source ~/.bashrc
    # or source ~/.zshrc, source ~/.mr, etc.
    ```

4.  **Dependencies:** The script requires standard command-line tools. Most should be pre-installed on Debian-based systems. The alias requires `curl`. The script explicitly checks for: `curl`, `grep`, `sort`, `awk`, `sed`, `mktemp`, `wc`, `date`, `basename`, `printf`. If any are missing, install them using `sudo apt update && sudo apt install <package_name>`. (`coreutils` provides many of these).

## Usage

Once the `bb` alias is set up and activated:

1.  Open your terminal.
2.  Run the alias:
    ```bash
    bb
    ```
3.  You will likely be prompted for your `sudo` password as the script needs root privileges to modify `/etc/hosts`.
4.  The alias will download the latest script, make it executable, and run it. Follow the on-screen logs.

To reverse the changes, use one of the methods described in "Restoring / Uninstalling".

## Configuration

The list of blocklist URLs (`BLOCKLIST_URLS` array) is currently hardcoded within the `blocking_bad.sh` script itself. To change the lists used, you would need to:

1.  Fork this repository.
2.  Edit the `blocking_bad.sh` file in your fork to modify the `BLOCKLIST_URLS`.
3.  Update the `URL` variable within the `bb` alias definition in your shell startup file to point to the *Raw* URL of the script in **your fork**.

## Troubleshooting

*   **Permission Denied / Requires Root:** The script *must* be run with `sudo`. The `bb` and `bbx` aliases handle this, but ensure you can use `sudo`.
*   **`sed: unterminated address regex` (During `bbx`):** This error indicates a problem with the complex quoting/escaping within the `bbx` alias definition. This can sometimes be shell-dependent. If you encounter this, consider using the Manual Removal or Restore Backup methods described below, or setting up the alternative `reverse_blocking_bad.sh` script (see [here](link_to_conversation_or_gist_if_available) for details on that approach).
*   **Command not found (curl, awk, etc.):** Install the missing command using `sudo apt install <command_name>`.
*   **Site Still Accessible (After `bb`):**
    *   **Confirm Tor/DoH:** Are you using Tor Browser or is DNS-over-HTTPS active in your regular browser? This script cannot block those (see Warning section).
    *   **Check Lists:** The specific domain might not be included in the public blocklists used.
    *   **DNS Cache:** While the script attempts to flush the cache, it might not work on all systems/configurations. Try manually restarting your browser, or even your computer.
    *   **Syntax Error:** Check `/etc/hosts` for any obvious syntax errors manually.

## Restoring / Uninstalling

To remove the blocks added by this script, choose one of the following methods:

**Method 1: Using the `bbx` Alias (If Added and Working)**

1.  Ensure you have added the `bbx` alias (see step 2 in Installation) to your shell startup file and activated it (e.g., `source ~/.mr`).
2.  Run the alias:
    ```bash
    bbx
    ```
3.  This command will attempt to directly remove the managed block from `/etc/hosts` using `sed`, flush DNS caches, and remove the local `~/blocking_bad.sh` script.
4.  **The `bbx` alias definition is:**
    ```sh
    # Alias to reverse blocking_bad changes directly (use with caution - complex quoting)
    alias bbx='echo "[bbx] Reversing blocking_bad changes..."; ( sudo sed -i "/^# BEGIN MANAGED BLOCKLIST (blocking_bad\\.sh v1\\.2) ### DO NOT EDIT MANUALLY BELOW ###$/,/^# END MANAGED BLOCKLIST (blocking_bad\\.sh v1\\.2) ### Run '\''bb'\'' to update ###$/d" /etc/hosts && echo "[bbx] Block removed from /etc/hosts." && echo "[bbx] Attempting to flush DNS cache..." && (sudo resolvectl flush-caches 2>/dev/null || sudo systemd-resolve --flush-caches 2>/dev/null || sudo systemctl restart nscd 2>/dev/null) && echo "[bbx] DNS flush attempted." || echo "[bbx] DNS flush command failed or no suitable service found." && echo "[bbx] Reversal action complete. Backups are in /etc/hosts.backups.blocking_bad/." && \rm -f "$HOME/blocking_bad.sh" && echo "[bbx] Removed local script ~/blocking_bad.sh." ) || { echo "[bbx] ERROR: Failed to remove block from /etc/hosts (check markers manually or use backup). sed exit code: $?" >&2; }'
    ```
    *Note: Complex aliases like this can sometimes be sensitive to shell environments. If `bbx` gives errors (like `sed: unterminated address regex`), use Method 2 or 3.*

**Method 2: Manual Removal**

1.  Edit the hosts file with root privileges: `sudo nano /etc/hosts`
2.  Locate the block managed by this script. It starts with the line (check version number if script updated):
    `# BEGIN MANAGED BLOCKLIST (blocking_bad.sh v1.2) ### DO NOT EDIT MANUALLY BELOW ###`
3.  It ends with the line:
    `# END MANAGED BLOCKLIST (blocking_bad.sh v1.2) ### Run 'bb' to update ###`
4.  Delete all lines between and including these two markers.
5.  Save the file (Ctrl+O, Enter in `nano`) and exit (Ctrl+X).
6.  Flush DNS cache / restart browser if needed.

**Method 3: Restore Backup**

1.  List the available backups: `ls -l /etc/hosts.backups.blocking_bad/`
2.  Identify a backup file from before you ran the script or before issues started (e.g., `hosts.backup.YYYYMMDD_HHMMSS`).
3.  Restore it (replace `BACKUP_FILENAME` with the actual filename):
    ```bash
    sudo cp /etc/hosts.backups.blocking_bad/BACKUP_FILENAME /etc/hosts
    ```
4.  Flush DNS cache / restart browser if needed.

**To remove the aliases:** Simply delete the `alias bb=...` and/or `alias bbx=...` lines from your shell startup file (`~/.bashrc`, `~/.mr`, etc.) and restart your shell or re-source the file. If you are not using `bbx`, you might also want to delete the potentially downloaded script: `rm -f ~/blocking_bad.sh`.

## Contributing

Contributions are welcome and appreciated! If you have suggestions, find bugs, or want to add features:

1.  Check the [Issues](https://github.com/melans/blocking_bad/issues) page to see if your idea or bug has already been discussed.
2.  If not, feel free to open a new issue to discuss it.
3.  To contribute code:
    *   Fork the repository.
    *   Create a new branch for your changes (`git checkout -b feature/your-feature-name`).
    *   Make your changes and commit them with clear messages.
    *   Push your branch to your fork (`git push origin feature/your-feature-name`).
    *   Open a Pull Request back to the main `melans/blocking_bad` repository.

Please try to follow the existing coding style and add comments where necessary.

## License

This project is licensed under the **MIT License**. See the [LICENSE](LICENSE) file for full details.
