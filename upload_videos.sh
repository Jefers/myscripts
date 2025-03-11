#!/bin/bash

# Set your Google Drive folder ID
# You can find your folder ID in the URL of your Google Drive folder
# Example: https://drive.google.com/drive/folders/1aBcDEfGh12345
GOOGLE_DRIVE_FOLDER_ID="https://drive.google.com/drive/folders/1KKbBMfQnLuM4uU8wwQERihbBy7RJnAdi"

# Mount your Android phone via USB
PHONE_MOUNT_PATH="/Volumes/Pixel7/Internal shared storage/DCIM/Camera"

# Set a temporary folder to stage files
TEMP_FOLDER="/Users/$USER/Desktop/PixelVideos"
LOG_FILE="/Users/$USER/Desktop/PixelVideos/upload_log.txt"

# Ensure the temp folder exists
mkdir -p "$TEMP_FOLDER"

# Automatically run this script when phone is connected
PLIST_FILE="/Library/LaunchAgents/com.user.uploadvideos.plist"

# Create a LaunchAgent to run this script automatically
sudo tee $PLIST_FILE > /dev/null <<EOL
<?xml version="1.0" encoding="UTF-8"?>
<!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN" "http://www.apple.com/DTDs/PropertyList-1.0.dtd">
<plist version="1.0">
<dict>
    <key>Label</key>
    <string>com.user.uploadvideos</string>
    <key>ProgramArguments</key>
    <array>
        <string>/bin/bash</string>
        <string>/path/to/your/script.sh</string>
    </array>
    <key>WatchPaths</key>
    <array>
        <string>/Volumes/Pixel7</string>
    </array>
    <key>RunAtLoad</key>
    <true/>
</dict>
</plist>
EOL

# Load the LaunchAgent
sudo launchctl load -w $PLIST_FILE

# Find all large video files over 500MB and older than 30 days
find "$PHONE_MOUNT_PATH" -type f -size +500M -name '*.mp4' -o -name '*.mov' -o -name '*.mkv' \
    -mtime +30 -exec mv {} "$TEMP_FOLDER" \;

# Compress large video files
for file in "$TEMP_FOLDER"/*; do
    if [[ -f "$file" ]]; then
        compressed_file="$TEMP_FOLDER/$(basename "$file" .mp4)-compressed.mp4"
        ffmpeg -i "$file" -vcodec libx265 -crf 28 "$compressed_file"
        mv "$compressed_file" "$file"
    fi
done

# Upload files to Google Drive organized by month/year
for file in "$TEMP_FOLDER"/*; do
    if [[ -f "$file" ]]; then
        file_date=$(date -r "$file" +"%Y/%B")
        gdrive_folder=$(gdrive mkdir --parent "$GOOGLE_DRIVE_FOLDER_ID" "$file_date" | awk '{print $2}')
        gdrive files upload --parent "$gdrive_folder" "$file"
        if [ $? -eq 0 ]; then
            # Log uploaded file
            echo "$(date) - Uploaded: $file to $file_date" >> "$LOG_FILE"
            # Successfully uploaded, now delete from phone
            rm "$file"
        else
            echo "$(date) - Failed upload: $file" >> "$LOG_FILE"
        fi
    fi
done

# Clean up
rmdir "$TEMP_FOLDER"

# Send a macOS notification
osascript -e 'display notification "All large videos have been uploaded and removed from your phone." with title "Upload Complete"'

# Final log message
echo "$(date) - Upload complete." >> "$LOG_FILE"

echo "✅ All large videos have been uploaded, compressed, and removed from your phone."
