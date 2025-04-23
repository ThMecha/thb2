# Plan: Remove assets/credentials.json from an Older Commit

**Goal:** Remove the file `assets/credentials.json` from the commit made 3 steps ago (HEAD~3) without affecting other changes in that commit or subsequent commits.

**Warning:** This involves rewriting Git history. If this repository is shared, coordinate with collaborators as they will need to update their local copies after you force-push.

**Steps:**

1.  **Abort Current Rebase (if active):** Since we might have left the editor open, ensure any active rebase is stopped.
    ```bash
    git rebase --abort 
    ```
    *(Will run this command if necessary based on `git status`)*

2.  **Start Interactive Rebase:** Begin an interactive rebase starting from the commit *before* the one we want to change (HEAD~4).
    ```bash
    git rebase -i HEAD~4
    ```
    *(Will run this command)*

3.  **Mark Commit for Editing:** In the text editor that opens:
    *   Find the line for the commit 3 steps ago (usually the second line).
    *   Change `pick` to `edit` (or `e`) at the beginning of that line.
    *   Save the file and close the editor (e.g., `:wq` in vim, `Ctrl+X -> Y -> Enter` in nano).
    *   Git will pause at this commit.

4.  **Remove the File from the Commit:** Once the rebase pauses at the target commit:
    *   Remove the specific file *from the Git index* (but keep it in your working directory if it exists there now).
      ```bash
      git rm --cached assets/credentials.json
      ```
      *(Will run this command)*
    *   Check `git status` to confirm the file is staged for removal.

5.  **Amend the Commit:** Update the commit to reflect the removal of the file, keeping the original commit message.
    ```bash
    git commit --amend --no-edit
    ```
    *(Will run this command)*

6.  **Continue the Rebase:** Tell Git to proceed with applying the rest of the commits.
    ```bash
    git rebase --continue
    ```
    *(Will run this command)*
    *   Git will re-apply the subsequent commits (HEAD~2, HEAD~1) on top of the amended commit.
    *   *Conflict Handling:* If conflicts arise (unlikely for just removing a file, but possible), Git will pause again. Resolve the conflicts, `git add` the resolved files, and run `git rebase --continue` again.

7.  **Verify History (Optional but Recommended):** After the rebase completes, check the history.
    ```bash
    git log --stat HEAD~4..HEAD 
    ```
    *(Can run this if requested)*
    *   Confirm `assets/credentials.json` is NOT listed in the "create" or "add" operations for the amended commit (HEAD~3).
    *   Confirm the file *is* present in the commit before it (HEAD~4), if it was added there.

8.  **Update Remote Repository (If Necessary):** If you need to update a remote repository (like on GitHub/GitLab):
    ```bash
    git push --force-with-lease origin <your-branch-name> 
    ```
    *(Replace `<your-branch-name>` with your actual branch, e.g., `main` or `master`. Use `--force-with-lease` instead of `--force` for safety).*