#!/bin/zsh

## ╔═════════════════════════════════════════════════════════════════╗
## ║         Installs i-Tech btenforce Bluetooth Enforcement       	 ║
## ║   Author: Keith Myers, i-Tech | keith.myers@i-techsupport.com   ║
## ╚═════════════════════════════════════════════════════════════════╝
## 
## 7/24/2025: Released 
##  
## Installs the software and activates the LaunchDaemon. The app is 
## configured via /Library/Application Support/i-Tech/btenforce.env
##
## (C) i-Tech Support Inc.
##
## Dependencies: blueutil (https://github.com/toy/blueutil) must be installed first.

version="1.6"

# Username of the user currently logged on and their ID.
loggedInUser=$( echo "show State:/Users/ConsoleUser" | scutil | awk '/Name :/ && ! /loginwindow/ { print $3 }' )

if [[ -n "$loggedInUser" ]]; then
	uid=$(id -u "$loggedInUser")
else
	uid=""
fi

# Required to run as root.
export BLUEUTIL_ALLOW_ROOT=1

BTENFORCE_ACTIVE="${4:-true}"
BTENFORCE_START_TIME="${5}"
BTENFORCE_STOP_TIME="${6}"
BLUETOOTH_CONTROL="${7:-enforce}"
SAFARI_CONTROL="${8:-enforce}"
SAFARI_CONTROL_METHOD="${9:-osascript}"
BTENFORCE_DOMAIN="${10}"
LOGIN_ITEM_CONTROL="${11:-enforce}"
BTENFORCE_DEBUG_MODE="${12:-false}"
BTENFORCE_LOG_FILE="${13:-/var/log/btenforce.log}"

CONFIG_DIR="/Library/Application Support/i-Tech"
CONFIG_FILE="${CONFIG_DIR}/btenforce.env"
APP_BUNDLE="/Applications/.i-Tech/btenforce.app"
PLIST="/Library/LaunchDaemons/com.itech.btenforce.plist"

btenforce="/usr/local/bin/btenforce"
butil="/usr/local/bin/blueutil"

# Add the date and time stamp to the log file.
append_log () {
    local message="$1"
    full_msg="btenforce version ${version} -- ${message}"
    logger -is -t btenforce "$full_msg" >> "$BTENFORCE_LOG_FILE"
}

trap 'echo "❌ Error on line $LINENO: $(sed -n ${LINENO}p "$0")" >> "$BTENFORCE_LOG_FILE"' ERR
append_log "Started installation"

## Create the configuration directory.
if [[ ! -d "$CONFIG_DIR" ]]; then
	mkdir -p "$CONFIG_DIR"
	append_log "Created ${CONFIG_DIR}"
fi

cat << EOF > "$CONFIG_FILE"
##                   btenforce Configuration File               
##   Author: Keith Myers, i-Tech | keith.myers@i-techsupport.com 
##                                                                                                
##   https://www.i-techsupport.com | (407) 265-2000
##   (C) 2026 i-Tech Support Inc.

# Version
version="${version}"
# Configured: $(date)

# Enable/disable the daemon as a whole with 'true' or 'false'
BTENFORCE_ACTIVE="${4:-true}"

# School start time in 24-hour clock. (HH:MM).
BTENFORCE_START_TIME="${5}"

# School stop time in 24-hour clock. (HH:MM).
BTENFORCE_STOP_TIME="${6}"

# Bluetooth option. 'enforce' or 'allow'
BLUETOOTH_CONTROL="${7:-enforce}"

# Login item controls. 'enforce' or 'allow'
LOGIN_ITEM_CONTROL="${8:-enforce}"

# Safari option. 'enforce' or 'allow'
SAFARI_CONTROL="${9:-enforce}"

# Email domain.
BTENFORCE_DOMAIN="${10}"

# Safari blocking option. 'osascript', 'pgrep'
SAFARI_CONTROL_METHOD="${11:-osascript}"

# Debug mode
BTENFORCE_DEBUG_MODE="${12:-false}"

# Log file path.
BTENFORCE_LOG_FILE="${13:-/var/log/btenforce.log}"

# Time constraint override.
TIME_CONSTRAINT_OVERRIDE="false"
EOF

echo "Created configuration file: ${CONFIG_FILE}"

# Reset variables.
BTENFORCE_ACTIVE=""
BTENFORCE_START_TIME=""
BTENFORCE_STOP_TIME=""

# Check for errors in the envfile.
source "$CONFIG_FILE"

if [[ -z "$BTENFORCE_ACTIVE" ]]; then
	append_log "BTENFORCE_ACTIVE is not set."
	exit 1
fi

if [[ -z "$BTENFORCE_START_TIME" ]]; then
	append_log "BTENFORCE_START_TIME is not set."
	exit 1
fi

if [[ -z "$BTENFORCE_STOP_TIME" ]]; then
	append_log "BTENFORCE_STOP_TIME is not set."
	exit 1
fi

append_log "There were no errors in the environment file."

# Check whether the source files exist.
if [[ ! -x "$butil" ]]; then
	append_log "WARNING: ${butil} is not executable. Bluetooth control will not work."
fi

if [[ -f "$btenforce" ]]; then
	append_log "Found ${btenforce}"
	xattr -dr com.apple.quarantine "$btenforce"
	chmod +x "$btenforce"
	echo "Removed quarantine attribute and set execute permission for ${btenforce}"
else
	append_log "Cannot find ${btenforce}"
	exit 1
fi

# Turn on Bluetooth for the logged in user to force the allow prompt.
if [[ -n "$uid" ]]; then
	launchctl asuser "$uid" sudo -u "$loggedInUser" /usr/local/bin/blueutil -p 0
	launchctl asuser "$uid" sudo -u "$loggedInUser" /usr/local/bin/blueutil -p 1
fi

# Check whether the daemon is running.
daemon_status=$( launchctl list | grep "com.itech.btenforce" || true )

# Already running. Unload and reload.
if [[ -n "$daemon_status" ]]; then
	launchctl bootout system/com.itech.btenforce
	sleep 1
	launchctl bootstrap system "$PLIST"
	sleep 1
	daemon_status=$( launchctl list | grep "com.itech.btenforce" || true )
	if [[ -n "$daemon_status" ]]; then
		append_log "LaunchDaemon installed and reloaded."
		exit 0
	else
		append_log "The daemon failed to reload."
		exit 1
	fi
else
	append_log "Installing new LaunchDaemon..."
fi

# If it's not running, start it.
launchctl bootstrap system "$plist_dest"

sleep 1

daemon_status=$( launchctl list | grep "com.itech.btenforce" || true )

if [[ -n "$daemon_status" ]]; then
	append_log "LaunchDaemon installed and loaded."
	append_log "Finished installation"
	exit 0
else
	append_log "The daemon failed to start."
	append_log "Installation failure."
	exit 1
fi

