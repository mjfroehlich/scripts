#!/bin/zsh

# ==============================================================================
# Resolve and Zip
#
# Description:
#   Recursively resolves macOS Finder Aliases within a target directory and
#   creates a clean ZIP archive of the resolved structure.
#
#   - If a folder contains a Finder Alias, the script resolves it to its original
#     source path.
#   - If the alias points to a file, the file is copied.
#   - If the alias points to a folder, the folder's contents are processed recursively.
#   - Regular files and directories are copied as-is.
#
# Usage:
#   ./resolve-and-zip.sh <path_to_folder>
#
#   Example:
#     ./resolve-and-zip.sh ~/Desktop/MyFolder
#     -> Creates MyFolder.zip in the current directory.
# ==============================================================================

# 1. Validation
if [[ -z "$1" ]]; then
    echo "Usage: $0 <path_to_folder_with_aliases>"
    exit 1
fi

# 2. Setup Paths
# Get the absolute path of the target to avoid relative path issues
TARGET_DIR=$(realpath "$1")
FOLDER_NAME=$(basename "$TARGET_DIR")
TEMP_WORK_DIR=$(mktemp -d /tmp/zip_resolve_XXXXXX)
# Save ZIP in the current directory where you run the script
ARCHIVE_PATH="$(pwd)/${FOLDER_NAME}.zip"

echo "Starting recursive resolution for: $FOLDER_NAME"

# 3. Recursive Function
process_items() {
    local src_dir="$1"
    local dest_dir="$2"

    mkdir -p "$dest_dir"

    # Use (N) to avoid errors if folder is empty, (D) to include hidden files if desired
    for item in "$src_dir"/*(N); do
        local item_name=$(basename "$item")

        # Check if item is a Finder Alias using 'file' command
        # This prevents folders and regular files from being misidentified as aliases
        if [[ "$(file -b "$item")" == *"Alias file"* ]]; then
            # Resolve the alias using a more robust AppleScript
            local original_path=$(osascript <<EOF
                tell application "Finder"
                    set theItem to (item (POSIX file "$item") as alias)
                    set originalItem to original item of theItem
                    return POSIX path of (originalItem as alias)
                end tell
EOF
            )

            if [[ -d "$original_path" ]]; then
                echo "  -> Resolving Folder Alias: $item_name"
                # If it's a folder alias, recurse into the ORIGINAL source
                process_items "$original_path" "$dest_dir/$item_name"
            else
                echo "  -> Resolving File Alias: $item_name"
                cp "$original_path" "$dest_dir/"
            fi
        elif [[ -d "$item" ]]; then
            # Regular folder: recurse
            process_items "$item" "$dest_dir/$item_name"
        else
            # Regular file: copy
            cp "$item" "$dest_dir/"
        fi
    done
}

# 4. Execute
process_items "$TARGET_DIR" "$TEMP_WORK_DIR"

echo "Creating archive: ${FOLDER_NAME}.zip"
(cd "$TEMP_WORK_DIR" && zip -r "$ARCHIVE_PATH" . -x "*.DS_Store")

# 5. Cleanup
rm -rf "$TEMP_WORK_DIR"
echo "Done! Archive saved to: $ARCHIVE_PATH"
