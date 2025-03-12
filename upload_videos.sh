#!/bin/bash

# Set your Google Drive folder ID
# You can find your folder ID in the URL of your Google Drive folder
# Example: https://drive.google.com/drive/folders/1aBcDEfGh12345
GOOGLE_DRIVE_FOLDER_ID="https://drive.google.com/drive/folders/1KKbBMfQnLuM4uU8wwQERihbBy7RJnAdi"
# Set your email for daily upload summaries
EMAIL="tiling-garlic-94@icloud.com"

# Set a temporary folder to stage files
TEMP_FOLDER="/Users/$USER/Desktop/PixelVideos"
LOG_FILE="/Users/$USER/Desktop/PixelVideos/upload_log.txt"
DJI_LOG_FILE="/Users/$USER/Desktop/PixelVideos/dji_upload_log.txt"

# Ensure the temp folder exists
mkdir -p "$TEMP_FOLDER"

# Ensure ADB is installed
if ! command -v adb &> /dev/null
then
    echo "ADB (Android Debug Bridge) not found. Installing it via Homebrew..."
    brew install android-platform-tools
fi

# Restart ADB server
adb kill-server
adb start-server

# Check if device is connected
adb wait-for-device

# Paths on the phone
PHONE_VIDEO_PATH="/sdcard/DCIM/Camera"
DJI_ALBUM_PATH="/sdcard/DCIM/DJI Album"
DJI_EXPORT_PATH="/sdcard/DCIM/DJI Export"

# Function to pull and upload videos with progress bar
function upload_videos() {
    local folder_path="$1"
    local log_file="$2"
    local drive_subfolder="$3"

    # Pull large videos from phone to temp folder
    adb shell find "$folder_path" -type f -size +500M \
        -name '*.mp4' -o -name '*.mov' -o -name '*.mkv' \
        -mtime +30 -exec adb pull {} "$TEMP_FOLDER" \;

    # Upload videos to Google Drive with a progress bar
    for file in "$TEMP_FOLDER"/*; do
        if [[ -f "$file" ]]; then
            file_date=$(date -r "$file" +"%Y/%B")
            gdrive_folder=$(gdrive mkdir --parent "$GOOGLE_DRIVE_FOLDER_ID" "$drive_subfolder/$file_date" | awk '{print $2}')
            echo "Uploading $file to Google Drive..."
            gdrive files upload --parent "$gdrive_folder" "$file" --progress

            if [ $? -eq 0 ]; then
                echo -n "["; for i in {1..50}; do echo -n "#"; sleep 0.1; done; echo "] 100%"
                echo "$(date) - Uploaded: $file to $drive_subfolder/$file_date" >> "$log_file"
                rm "$file"
            else
                echo "$(date) - Failed upload: $file" >> "$log_file"
            fi
        fi
    done

    # Delete videos from the phone
    echo "Deleting large files from phone..."
    adb shell find "$folder_path" -type f -size +500M -mtime +30 -delete
}

# Upload regular phone videos
upload_videos "$PHONE_VIDEO_PATH" "$LOG_FILE" "Phone Videos"

# Upload DJI Album videos
upload_videos "$DJI_ALBUM_PATH" "$DJI_LOG_FILE" "DJI Footage"

# Upload DJI Export videos
upload_videos "$DJI_EXPORT_PATH" "$DJI_LOG_FILE" "DJI Footage"

# Clean up
rmdir "$TEMP_FOLDER"

# Send a macOS notification
osascript -e 'display notification "All large videos (including DJI) have been uploaded." with title "Upload Complete"'

# Send email summary
mail -s "Daily Video Upload Summary" "$EMAIL" < "$LOG_FILE"
mail -s "Daily DJI Upload Summary" "$EMAIL" < "$DJI_LOG_FILE"

# Final log message
echo "$(date) - Upload complete." >> "$LOG_FILE"
echo "$(date) - DJI Upload complete." >> "$DJI_LOG_FILE"

echo "✅ All large videos have been uploaded, including DJI footage."

# Set up LaunchAgent to auto-run when device is connected
PLIST_PATH="$HOME/Library/LaunchAgents/com.user.pixelvideos.plist"
echo "<?xml version='1.0' encoding='UTF-8'?>
<!DOCTYPE plist PUBLIC '-//Apple//DTD PLIST 1.0//EN' 'http://www.apple.com/DTDs/PropertyList-1.0.dtd'>
<plist version='1.0'>
<dict>
    <key>Label</key>
    <string>com.user.pixelvideos</string>
    <key>ProgramArguments</key>
    <array>
        <string>/bin/bash</string>
        <string>$HOME/Desktop/Move Videos To Drive</string>
    </array>
    <key>WatchPaths</key>
    <array>
        <string>/dev</string>
    </array>
    <key>RunAtLoad</key>
    <true/>
</dict>
</plist>" > "$PLIST_PATH"

# Load the LaunchAgent
launchctl load "$PLIST_PATH"
echo "✅ The script is now automated and will run when the phone is connected."

# Provide real-time feedback
while ps -p $! > /dev/null; do
    echo -n "."; sleep 2
done

echo "✅ All uploads and cleanups are complete."
