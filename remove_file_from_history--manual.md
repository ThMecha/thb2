
**How to Use:**

1.  **Save:** Save the code above into a file named `remove_file_from_history.sh`.
2.  **Edit:** Open the script and **change the `FILE_TO_REMOVE=""` line** to specify the exact path to the file you need to remove (e.g., `FILE_TO_REMOVE="credentials.json"`).
3.  **Make Executable:** `chmod +x remove_file_from_history.sh`
4.  **Run from Repo Root:** Navigate to the top-level directory of your Git repository in your terminal.
5.  **Checkout Branch:** Make sure you are on the branch you want to clean: `git checkout your-branch-name`
6.  **Run:** Execute the script: `./remove_file_from_history.sh`
7.  **Confirm:** Read the warning and type `y` if you are sure.
8.  **Follow Instructions:** After the script finishes, carefully follow the "IMPORTANT NEXT STEPS" printed in the output, especially verifying the result and using `git push --force-with-lease`.



➡️ **[https://github.com/newren/git-filter-repo/#installation](https://github.com/newren/git-filter-repo/#installation)** ⬅️

The installation method depends on your operating system and preferences. Common methods include:

1.  **Using Package Managers (Recommended if available):**
    *   **Debian/Ubuntu:** `sudo apt update && sudo apt install git-filter-repo`
    *   **Fedora/CentOS/RHEL:** `sudo dnf install git-filter-repo`
    *   **macOS (Homebrew):** `brew install git-filter-repo`
    *   **Arch Linux:** `sudo pacman -S git-filter-repo`
    *   *(Check the documentation for other package managers like Conda, Nix, etc.)*

2.  **Using pip (Python's package installer):**
    *   If you have Python and pip installed: `pip install git-filter-repo`
    *   You might need `pip3` depending on your setup: `pip3 install git-filter-repo`

**After Installation:**

1.  **Verify Installation:** Open a *new* terminal window (or run `hash -r` in your current one to reset the command path cache) and try running:
    ```bash
    git filter-repo --version
    ```
    If it prints a version number, the installation was successful and it's in your PATH.
    