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

1.  **Add the Alias:** You need to add the `bb` alias definition to your shell's startup file. Common files are:
    *   For Bash: `~/.bashrc`
    *   For Zsh: `~/.zshrc`
    *   Or your custom alias file (like `~/.mr` as used by the author).

    Paste the following **single line** into your chosen startup file:

    ```sh
    alias bb='cd "$HOME" && SCRIPT="blocking_bad.sh"; URL="https://raw.githubusercontent.com/melans/blocking_bad/main/blocking_bad.sh"; echo "[bb] Ensuring latest $SCRIPT..."; curl -sfLo "$SCRIPT" "$URL" && chmod +x "$SCRIPT" && echo "[bb] Running $SCRIPT with sudo..." && sudo "$HOME/$SCRIPT" "$@" || echo "[bb] ERROR: Failed to download, prepare, or run $SCRIPT."'
    ```

2.  **Activate the Alias:** Either close and reopen your terminal, or manually source the startup file, for example:
    ```bash
    source ~/.bashrc
    # or source ~/.zshrc, source ~/.mr, etc.
    ```

3.  **Dependencies:** The script requires standard command-line tools. Most should be pre-installed on Debian-based systems. The alias requires `curl`. The script explicitly checks for: `curl`, `grep`, `sort`, `awk`, `sed`, `mktemp`, `wc`, `date`, `basename`, `printf`. If any are missing, install them using `sudo apt update && sudo apt install <package_name>`. (`coreutils` provides many of these).

## Usage

Once the alias is set up and activated:

1.  Open your terminal.
2.  Run the alias:
    ```bash
    bb
    ```
3.  You will likely be prompted for your `sudo` password as the script needs root privileges to modify `/etc/hosts`.
4.  The alias will download the latest script, make it executable, and run it. Follow the on-screen logs.

## Configuration

The list of blocklist URLs (`BLOCKLIST_URLS` array) is currently hardcoded within the `blocking_bad.sh` script itself. To change the lists used, you would need to:

1.  Fork this repository.
2.  Edit the `blocking_bad.sh` file in your fork to modify the `BLOCKLIST_URLS`.
3.  Update the `URL` variable within the `bb` alias definition in your shell startup file to point to the *Raw* URL of the script in **your fork**.

## Troubleshooting

*   **Permission Denied / Requires Root:** The script *must* be run with `sudo` because it modifies `/etc/hosts`. The alias handles this, but ensure you can use `sudo`.
*   **`sed: unterminated address regex`:** This error should be fixed as of v1.2.2. Ensure the `bb` alias is downloading the latest version (the alias provided forces this). If it persists, there might be extremely unusual characters in `/etc/hosts` interfering.
*   **Command not found (curl, awk, etc.):** Install the missing command using `sudo apt install <command_name>`.
*   **Site Still Accessible:**
    *   **Confirm Tor/DoH:** Are you using Tor Browser or is DNS-over-HTTPS active in your regular browser? This script cannot block those (see Warning section).
    *   **Check Lists:** The specific domain might not be included in the public blocklists used.
    *   **DNS Cache:** While the script attempts to flush the cache, it might not work on all systems/configurations. Try manually restarting your browser, or even your computer. You can also try manual cache flushing commands specific to your setup if you know them.
    *   **Syntax Error:** Check `/etc/hosts` for any obvious syntax errors manually (though the script aims to prevent this). Look for lines not matching `IP_ADDRESS domain_name`.

## Restoring / Uninstalling

To remove the blocks added by this script:

**Method 1: Manual Removal**

1.  Edit the hosts file with root privileges: `sudo nano /etc/hosts`
2.  Locate the block managed by this script. It starts with the line:
    `# BEGIN MANAGED BLOCKLIST (blocking_bad.sh ...`
3.  It ends with the line:
    `# END MANAGED BLOCKLIST (blocking_bad.sh ...`
4.  Delete all lines between and including these two markers.
5.  Save the file (Ctrl+O, Enter in `nano`) and exit (Ctrl+X).
6.  Flush DNS cache / restart browser if needed.

**Method 2: Restore Backup**

1.  List the available backups: `ls -l /etc/hosts.backups.blocking_bad/`
2.  Identify a backup file from before you ran the script or before issues started (e.g., `hosts.backup.YYYYMMDD_HHMMSS`).
3.  Restore it (replace `BACKUP_FILENAME` with the actual filename):
    ```bash
    sudo cp /etc/hosts.backups.blocking_bad/BACKUP_FILENAME /etc/hosts
    ```
4.  Flush DNS cache / restart browser if needed.

**To remove the alias:** Simply delete the `alias bb='...'` line from your shell startup file (`~/.bashrc`, `~/.mr`, etc.) and restart your shell or re-source the file. You can also delete the downloaded script: `rm ~/blocking_bad.sh`.

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

