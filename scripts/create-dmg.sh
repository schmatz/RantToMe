#!/bin/bash
set -e

# Configuration
APP_NAME="RantToMe"
APP_PATH="$1"
DMG_NAME="${APP_NAME}.dmg"
VOLUME_NAME="${APP_NAME}"
DMG_TEMP="temp_${DMG_NAME}"
DMG_FINAL="${DMG_NAME}"

if [ -z "$APP_PATH" ]; then
    echo "Usage: $0 /path/to/App.app"
    exit 1
fi

if [ ! -d "$APP_PATH" ]; then
    echo "Error: App not found at $APP_PATH"
    exit 1
fi

echo "Creating DMG for ${APP_NAME}..."

# Clean up any previous attempts
rm -f "${DMG_TEMP}" "${DMG_FINAL}" 2>/dev/null || true

# Get app size and add buffer for Applications symlink
APP_SIZE=$(du -sm "$APP_PATH" | cut -f1)
DMG_SIZE=$((APP_SIZE + 20))

echo "App size: ${APP_SIZE}MB, DMG size: ${DMG_SIZE}MB"

# Create a temporary DMG
hdiutil create -srcfolder "$APP_PATH" -volname "${VOLUME_NAME}" -fs HFS+ \
    -fsargs "-c c=64,a=16,e=16" -format UDRW -size ${DMG_SIZE}m "${DMG_TEMP}"

# Mount the DMG
DEVICE=$(hdiutil attach -readwrite -noverify "${DMG_TEMP}" | egrep '^/dev/' | sed 1q | awk '{print $1}')
MOUNT_POINT="/Volumes/${VOLUME_NAME}"

echo "Mounted at ${MOUNT_POINT}"

# Wait for mount
sleep 2

# Create Applications alias (preserves icon, unlike symlink)
osascript <<ALIAS_EOF
tell application "Finder"
    make new alias file at POSIX file "${MOUNT_POINT}" to POSIX file "/Applications"
    set name of result to "Applications"
end tell
ALIAS_EOF

# Use AppleScript to set up the DMG window appearance
echo "Configuring DMG appearance..."
osascript <<EOF
tell application "Finder"
    tell disk "${VOLUME_NAME}"
        open
        set current view of container window to icon view
        set toolbar visible of container window to false
        set statusbar visible of container window to false
        set the bounds of container window to {100, 100, 640, 400}
        set theViewOptions to the icon view options of container window
        set arrangement of theViewOptions to not arranged
        set icon size of theViewOptions to 80
        set background color of theViewOptions to {65535, 65535, 65535}

        -- Position the app icon on the left
        set position of item "${APP_NAME}.app" of container window to {140, 150}

        -- Position Applications folder on the right
        set position of item "Applications" of container window to {400, 150}

        close
        open
        update without registering applications
        delay 2
    end tell
end tell
EOF

# Give Finder time to update
sync
sleep 3

# Unmount
hdiutil detach "${DEVICE}"

# Convert to compressed read-only DMG
echo "Compressing DMG..."
hdiutil convert "${DMG_TEMP}" -format UDZO -imagekey zlib-level=9 -o "${DMG_FINAL}"

# Clean up temp DMG
rm -f "${DMG_TEMP}"

# Set the DMG icon to match the app icon
APP_ICON="${APP_PATH}/Contents/Resources/AppIcon.icns"
if [ -f "$APP_ICON" ]; then
    echo "Setting DMG icon..."
    osascript << ICON_EOF
use framework "Cocoa"
set theImage to current application's NSImage's alloc()'s initWithContentsOfFile:"${APP_ICON}"
current application's NSWorkspace's sharedWorkspace()'s setIcon:theImage forFile:"$(pwd)/${DMG_FINAL}" options:0
ICON_EOF
fi

echo ""
echo "Successfully created: ${DMG_FINAL}"
ls -lh "${DMG_FINAL}"
