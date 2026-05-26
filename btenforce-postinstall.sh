#!/bin/bash

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

VERSION="2.2.1"
SCRIPT_DIR="$( cd "$( dirname "$0" )" && pwd )"
SCRIPT_PATH="${SCRIPT_DIR}/$(basename "$0")"
TODAY=$( date +%Y-%m-%d )

# ======================================
# Jamf Pro parameters (positions 4 - 11)
# ======================================
DEBUG="${4:-false}"
BTENFORCE_START_TIME="${5:-07:00}"
BTENFORCE_STOP_TIME="${6:-15:00}"
BLUETOOTH_CONTROL="${7:-enforce}"
SAFARI_CONTROL="${8:-allow}"
SAFARI_CONTROL_METHOD="${9:-pgrep}"
TIME_CONSTRAINT_OVERRIDE="${10:-false}"
LOGIN_ITEM_CONTROL="${11:-allow}"
BTENFORCE_DOMAIN="yourdomain.com"
BTENFORCE_LOG_DIR="/var/log/btenforce"
BTENFORCE_LOG_FILE="${BTENFORCE_LOG_DIR}/btenforce-postinstall.log"
BTENFORCE_ACTIVE="true"
LOG_RETENTION="180"
BTENFORCE_INTERVAL="5"

# An older version of blueutil was provided and installed in /usr/local/share/blueutil
# To overwrite blueutil in /usr/local/bin, change OVERWRITE_BLUEUTIL to true.
OVERWRITE_BLUEUTIL="false"

# ===============================================================
# If using Mosyle or another MDM, either adjust the parameters or
# leave the default values as they are. 
# ===============================================================            

# Add the date and time stamp to the log file.
append_log () {
    local message="$1"

    # Check if the log directory exists and create it if it does not.
    if [[ ! -d "$BTENFORCE_LOG_DIR" ]]; then
        mkdir -p "$BTENFORCE_LOG_DIR"
        chmod 755 "$BTENFORCE_LOG_DIR"
    fi
	
    # Strip ANSI color codes AND leading newlines for the log files.
    # The sed pipeline removes ANSI escape sequences and deletes the first line if it is empty.
    local clean_text
	clean_text="$( echo -e "$message" | sed 's/\x1b\[[0-9;]*m//g' | sed '1{/^$/d;}' )"
    
    local date_stamp
	date_stamp="$( date +"%Y-%m-%d %H:%M:%S" )"

	local file_log_msg
	file_log_msg="[POSTINSTALL]${date_stamp} -- ${clean_text}"
	
	local syslog_msg
	syslog_msg="version ${VERSION} -- ${clean_text}"

    # If stdout is a terminal (interactive session), keep the colors.
    if [[ -t 1 ]]; then
        # Echo the message with the ANSI color codes to the terminal.
        echo -e "$message"
    fi

    # Append clean message to the persistent log file
    echo "$file_log_msg" >> "$BTENFORCE_LOG_FILE"
    
    # Log to syslog without echoing to stderr again
    logger -i -t btenforce "$syslog_msg"
}

add_leading_zero() {
    local time="$1"
	local hour="${time%%:*}"
	local minute="${time##*:}"

	# Strip any existing leading zeros to avoid double padding
	hour="${hour#"${hour%%[!0]*}"}"
	minute="${minute#"${minute%%[!0]*}"}"
	
	# If they were entirely zeros (e.g. "00"), they become empty. Default to 0.
	hour="${hour:-0}"
	minute="${minute:-0}"

	printf "%02d:%02d\n" "$hour" "$minute"
}

check_time_integer() {
    local time="$1"
    local time_regex='^([0-9]|0[0-9]|1[0-9]|2[0-3]):[0-5][0-9]$'

    if [[ ! "$time" =~ $time_regex ]]; then
        return 1
	fi

	local hour="${time%%:*}"
	local minute="${time##*:}"

	# Using 10# forces base-10 evaluation, avoiding octal errors with 08 or 09.
	if (( 10#$hour >= 0 && 10#$hour <= 23 )) && (( 10#$minute >= 0 && 10#$minute <= 59 )); then
		return 0
	fi
    return 1
}

check_config_values() {

	# Verify that the required configuration variables are set.
	if [[ "$BTENFORCE_ACTIVE" = "true" ]]; then
		append_log "BTENFORCE_ACTIVE is set to ${BTENFORCE_ACTIVE}"
	elif [[ "$BTENFORCE_ACTIVE" = "false" ]]; then
		append_log "BTENFORCE_ACTIVE is set to ${BTENFORCE_ACTIVE}"
	else
		append_log "⚠️ ${BTENFORCE_ACTIVE} is not a valid value. Using default of true."
		BTENFORCE_ACTIVE="true"
	fi

	interval_regex='^([1-9]|[1-9][0-9]{1,2}|[1-2][0-9]{3}|3[0-5][0-9]{2}|3600)$'
	if [[ -z "$BTENFORCE_INTERVAL" ]]; then
		BTENFORCE_INTERVAL="5"
		append_log "⚠️ Interval was not set. Defaulting to ${BTENFORCE_INTERVAL}."
	else
		# Check against regex.
		if [[ "$BTENFORCE_INTERVAL" =~ $interval_regex ]]; then
			if [[ "$BTENFORCE_INTERVAL" -le 4 ]]; then
				append_log "⚠️ An interval of less than 5 seconds may be too short! 5 is optimal."
			elif [[ "$BTENFORCE_INTERVAL" -ge 60 ]]; then
				append_log "⚠️ An interval of a full minute or longer may be too long! 5 seconds is optimal."
			fi
			append_log "Interval set to: ${BTENFORCE_INTERVAL}."
		else
			append_log "❌ Invalid value entered: ${BTENFORCE_INTERVAL} - Defaulting to 5."
			BTENFORCE_INTERVAL="5"
		fi
	fi

	# Check whether the Bluetooth control method is set.
	if [[ -n "$BLUETOOTH_CONTROL" ]]; then
		if [[ "$BLUETOOTH_CONTROL" = "enforce" ]] || [[ "$BLUETOOTH_CONTROL" = "allow" ]]; then
			append_log "BLUETOOTH_CONTROL is set to ${BLUETOOTH_CONTROL}"
		else
			append_log "⚠️ ${BLUETOOTH_CONTROL} is not a valid value for BLUETOOTH_CONTROL. Defaulting to enforce."
			BLUETOOTH_CONTROL="enforce"
		fi
	else
		append_log "⚠️ BLUETOOTH_CONTROL is not set. Defaulting to enforce."
		BLUETOOTH_CONTROL="enforce"
	fi

	# Check whether the login item control is set.
	if [[ -n "$LOGIN_ITEM_CONTROL" ]]; then
		if [[ "$LOGIN_ITEM_CONTROL" = "enforce" ]] || [[ "$LOGIN_ITEM_CONTROL" = "allow" ]]; then
			append_log "LOGIN_ITEM_CONTROL is set to ${LOGIN_ITEM_CONTROL}"
		else
			append_log "⚠️ ${LOGIN_ITEM_CONTROL} is not a valid value for LOGIN_ITEM_CONTROL. Defaulting to allow."
			LOGIN_ITEM_CONTROL="allow"
		fi
	else
		append_log "⚠️ LOGIN_ITEM_CONTROL is not set. Defaulting to allow."
		LOGIN_ITEM_CONTROL="allow"
	fi

	# Check whether the time constraint override is set.
	if [[ -n "$TIME_CONSTRAINT_OVERRIDE" ]]; then
		if [[ "$TIME_CONSTRAINT_OVERRIDE" = "true" ]] || [[ "$TIME_CONSTRAINT_OVERRIDE" = "false" ]]; then
			append_log "TIME_CONSTRAINT_OVERRIDE is set to ${TIME_CONSTRAINT_OVERRIDE}"
		else
			append_log "⚠️ ${TIME_CONSTRAINT_OVERRIDE} is not a valid value. Defaulting to false."
			TIME_CONSTRAINT_OVERRIDE="false"
		fi
	else
		append_log "⚠️ TIME_CONSTRAINT_OVERRIDE is not set. Defaulting to false."
		TIME_CONSTRAINT_OVERRIDE="false"
	fi

	# Check whether the domain is set.
	if [[ -n "$BTENFORCE_DOMAIN" ]]; then
		append_log "BTENFORCE_DOMAIN is set to ${BTENFORCE_DOMAIN}"
	else
		append_log "⚠️ BTENFORCE_DOMAIN is not set. Defaulting to NOT SET."
		BTENFORCE_DOMAIN="NOT SET"
	fi

	# Check whether the Safari control method is set.
	if [[ -n "$SAFARI_CONTROL_METHOD" ]]; then
		if [[ "$SAFARI_CONTROL_METHOD" = "osascript" ]] || [[ "$SAFARI_CONTROL_METHOD" = "pgrep" ]]; then
			append_log "SAFARI_CONTROL_METHOD is set to ${SAFARI_CONTROL_METHOD}"
		else
			append_log "⚠️ ${SAFARI_CONTROL_METHOD} is not a valid value for SAFARI_CONTROL_METHOD. Defaulting to pgrep."
			SAFARI_CONTROL_METHOD="pgrep"
		fi
	else
		append_log "⚠️ SAFARI_CONTROL_METHOD is not set. Defaulting to pgrep."
		SAFARI_CONTROL_METHOD="pgrep"
	fi

	if [[ -n "$BTENFORCE_START_TIME" ]]; then
		BTENFORCE_START_TIME=$( add_leading_zero "$BTENFORCE_START_TIME" )

		if check_time_integer "$BTENFORCE_START_TIME"; then
			append_log "BTENFORCE_START_TIME is set to ${BTENFORCE_START_TIME}"
		else
			append_log "⚠️ ${BTENFORCE_START_TIME} is not a valid value. Defaulting to 07:45."
			BTENFORCE_START_TIME="07:45"
		fi
	else
		append_log "⚠️ BTENFORCE_START_TIME is not set. Defaulting to 07:45."
		BTENFORCE_START_TIME="07:45"
	fi

	if [[ -n "$BTENFORCE_STOP_TIME" ]]; then
		BTENFORCE_STOP_TIME=$( add_leading_zero "$BTENFORCE_STOP_TIME" )
		
		if check_time_integer "$BTENFORCE_STOP_TIME"; then
			append_log "BTENFORCE_STOP_TIME is set to ${BTENFORCE_STOP_TIME}"
		else
			append_log "⚠️ ${BTENFORCE_STOP_TIME} is not a valid value. Defaulting to 15:00."
			BTENFORCE_STOP_TIME="15:00"
		fi
	else
		append_log "⚠️ BTENFORCE_STOP_TIME is not set. Defaulting to 15:00."
		BTENFORCE_STOP_TIME="15:00"
	fi

	# Check whether the log retention period is set.
	log_retention_regex='^([1-9][0-9]{0,2}|10[0-8][0-9]|109[0-5])$'
	if [[ -n "$LOG_RETENTION" ]]; then
		if [[ "$LOG_RETENTION" =~ $log_retention_regex ]]; then
			append_log "LOG_RETENTION is set to ${LOG_RETENTION} days."
		else
			append_log "⚠️ ${LOG_RETENTION} is not a valid value for LOG_RETENTION. Max: 1095. Defaulting to 180 days."
			LOG_RETENTION="180"
		fi
	else
		append_log "⚠️ LOG_RETENTION is not set. Defaulting to 180 days."
		LOG_RETENTION="180"
	fi

	# Check whether the log file path is set.
	if [[ -n "$BTENFORCE_LOG_DIR" ]]; then
		append_log "BTENFORCE_LOG_DIR is set to ${BTENFORCE_LOG_DIR}"
	else
		append_log "⚠️ BTENFORCE_LOG_DIR was not set. Using /var/log/btenforce"
		BTENFORCE_LOG_DIR="/var/log/btenforce"
	fi

	return 0
}

enable_bluetooth() {
	if [[ "$NO_BLUEUTIL" = "true" ]]; then
		append_log "⚠️ Skipped enabling bluetooth. Unable to locate blueutil."
		return 1
	fi

	export BLUEUTIL_ALLOW_ROOT=1

	# Get the currently logged-in user and their UID.
	local loggedInUser
	loggedInUser=$( echo "show State:/Users/ConsoleUser" | scutil | awk '/Name :/ && ! /loginwindow/ { print $3 }' )
	
	local uid=""
	if [[ -n "$loggedInUser" ]]; then
		uid=$(id -u "$loggedInUser")
	fi

	# Check if a user is logged in.
	if [[ -z "$loggedInUser" ]] || [[ -z "$uid" ]]; then
		append_log "Either nobody is logged on, or the user ID could not be determined. Skipping turning on Bluetooth."
	else
		# Turn on Bluetooth for the logged in user to force the allow prompt. Needed if the config profile isn't installed.
		launchctl asuser "$uid" sudo -u "$loggedInUser" "$BLUEUTIL" -p 0 || true
		sleep 1
		launchctl asuser "$uid" sudo -u "$loggedInUser" "$BLUEUTIL" -p 1 || true
	fi
	
	return 0
}

copy_file() {
	local src="$1"
	local dest="$2"
	
	# Validate arguments and check whether the source exists.
	if [[ -z "$src" ]] || [[ -z "$dest" ]]; then
		append_log "❌ Source and/or destination arguments were missing."
		return 1
	elif [[ ! -f "$src" ]]; then
		append_log "❌ ${src} was not found."
		return 1
	fi
	
	# Back up the existing file if it exists.
	if [[ -f "$dest" ]]; then
		
		if mv "$dest" "${dest}.bak"; then
			append_log "Moved ${dest} to ${dest}.bak as a back up."
		else
			append_log "❌ Backup of ${dest} to ${dest}.bak failed."
			return 1
		fi
	else
		append_log "${dest} did not exist. Skipped backup."
	fi
	
	# Copy the source to the destination.
	if cp "$src" "$dest"; then
		append_log "Copied ${src} to ${dest}"
	else
		append_log "Failed to copy ${src} to ${dest}."
		return 1
	fi
	
	# Set ownership and permissions on the moved file.
	if ! chmod 755 "$dest"; then
		append_log "❌ Failed to set permissions for ${dest}"
		return 1
	fi
		
	if ! chown root:wheel "$dest"; then
		append_log "❌ Failed to set ownership for ${dest}"
		return 1
	fi

	xattr -dr com.apple.quarantine "$dest"
	append_log "Successfully copied ${src} to ${dest}."
	
	return 0
}

debug_info() {
	missing_files=0
	append_log "====================[ Debug mode has been enabled ] ===================="
	append_log "VERSION:                  ${VERSION}"
	append_log "SCRIPT_PATH:              ${SCRIPT_PATH}"
	append_log "SCRIPT_DIR:               ${SCRIPT_DIR}"
	append_log "BTENFORCE_ACTIVE:         ${BTENFORCE_ACTIVE}"
	append_log "BTENFORCE_START_TIME:     ${BTENFORCE_START_TIME}"
	append_log "BTENFORCE_STOP_TIME:      ${BTENFORCE_STOP_TIME}"
	append_log "BLUETOOTH_CONTROL:        ${BLUETOOTH_CONTROL}"
	append_log "SAFARI_CONTROL:           ${SAFARI_CONTROL}"
	append_log "SAFARI_CONTROL_METHOD:    ${SAFARI_CONTROL_METHOD}"
	append_log "BTENFORCE_DOMAIN:         ${BTENFORCE_DOMAIN}"
	append_log "LOGIN_ITEM_CONTROL:       ${LOGIN_ITEM_CONTROL}"
	append_log "TIME_CONSTRAINT_OVERRIDE: ${TIME_CONSTRAINT_OVERRIDE}"
	append_log "LOG_RETENTION:            ${LOG_RETENTION}"
	append_log "BTENFORCE_INTERVAL:       ${BTENFORCE_INTERVAL}"
	append_log "OVERWRITE_BLUEUTIL:       ${OVERWRITE_BLUEUTIL}"
	append_log "NO_BLUEUTIL:              ${NO_BLUEUTIL}"
	append_log "CONFIG_DIR:               ${CONFIG_DIR}"
	
	
	files=("$BTENFORCE_CONFIG" "$PLIST" "$BTENFORCE" "$BLUEUTIL" "$BTENFORCE_LOG_FILE")
	for file in "${files[@]}"; do
		if [[ -f "$file" ]]; then
			append_log "✅ File exists:           ${file}"
		else
			append_log "❌ File is missing:       ${file}"
			((missing_files++))
		fi
	done
	
	if [[ "$missing_files" -gt 0 ]]; then
		append_log "Missing file count:       ${missing_files}"
	fi
	
			
		append_log "========================================================================="
}

start_daemon() {
	launchctl bootstrap system "$PLIST"
	sleep 3
	local daemon_status=$( launchctl list | grep "com.itech.btenforce" || true )
	if [[ -n "$daemon_status" ]]; then
		append_log "✅ LaunchDaemon installed."
		return 0
	else
		launchctl bootstrap system "$PLIST"
		sleep 3
		local daemon_status=$( launchctl list | grep "com.itech.btenforce" || true )
		if [[ -n "$daemon_status" ]]; then
			append_log "✅ LaunchDaemon installed."
			return 0
		else
			append_log "❌ LaunchDaemon has failed to install."
		fi
	fi
	
	return 1
}

stop_daemon() {
	launchctl bootout system/com.itech.btenforce 2>/dev/null
	sleep 1
	local daemon_status=$( launchctl list | grep "com.itech.btenforce" || true )

	if [[ -n "$daemon_status" ]]; then
		launchctl bootout system/com.itech.btenforce 2>/dev/null
		sleep 1
		local daemon_status=$( launchctl list | grep "com.itech.btenforce" || true )
		
		if [[ -n "$daemon_status" ]]; then
			append_log "⚠️ LaunchDaemon still running."
			return 1
		else
			append_log "✅ LaunchDaemon has been stopped."
		fi
	else
		append_log "✅ The LaunchDaemon has been stopped."
	fi
	
	return 0
}

# ══════════╣ MAIN SCRIPT ╠═══════════

CONFIG_DIR="/Library/Application Support/i-Tech"
BTENFORCE_CONFIG="${CONFIG_DIR}/btenforce.env"
PLIST="/Library/LaunchDaemons/com.itech.btenforce.plist"
BTENFORCE="/usr/local/bin/btenforce"
BLUEUTIL="/usr/local/bin/blueutil"
NO_BLUEUTIL="false"

if [[ "$DEBUG" = "true" ]]; then
	debug_info
	trap 'echo "❌ Error on line $LINENO: $(sed -n ${LINENO}p "$0")" >> "$BTENFORCE_LOG_FILE"' ERR
	set -x
else
	set +x
fi

if [[ ! -f "$BTENFORCE" ]]; then
	append_log "❌ Cannot find ${BTENFORCE}"
	exit 1
fi

## Create the configuration directory.
if [[ ! -d "$CONFIG_DIR" ]]; then
	mkdir -p "$CONFIG_DIR"
	append_log "Created ${CONFIG_DIR}"
fi

# Back up existing config if it exists.
if [[ -f "$BTENFORCE_CONFIG" ]]; then
	if mv "$BTENFORCE_CONFIG" "${BTENFORCE_CONFIG}.bak"; then
		append_log "Backed up existing configuration file to ${BTENFORCE_CONFIG}.bak"
	else
		append_log "⚠️ Failed to back up existing configuration file."
	fi
fi

cat << EOF > "$BTENFORCE_CONFIG"

## ╔═════════════════════════════╗ 
## ║  _     _____         _      ║ 
## ║ (_)   |_   _|__  ___| |___  ║ 
## ║ | |_____| |/ _ \/ __| '_  \ ║ 
## ║ | |_____| |  __/ (__| | | | ║ 
## ║ |_|     |_|\___|\___|_| |_| ║ 
## ║                             ║ 
## ║ Author: Keith Myers, i-Tech ║ 
## ║ (C) 2026 i-Tech Support Inc ║ 
## ╚═════════════════════════════╝ 

# Version: ${VERSION}
# Configured on: $( date +"%Y-%m-%d %H:%M:%S" ) | via btenforce-postinstall.sh
# Postinstall script path: "${SCRIPT_PATH}"

# Enable/disable the daemon as a whole with 'true' or 'false'
BTENFORCE_ACTIVE="${BTENFORCE_ACTIVE}"

# Interval between checks in seconds (1-3600).
BTENFORCE_INTERVAL="${BTENFORCE_INTERVAL}"

# School start time in 24-hour clock. (HH:MM).
BTENFORCE_START_TIME="${BTENFORCE_START_TIME}"

# School stop time in 24-hour clock. (HH:MM).
BTENFORCE_STOP_TIME="${BTENFORCE_STOP_TIME}"

# Bluetooth option. 'enforce' or 'allow'
BLUETOOTH_CONTROL="${BLUETOOTH_CONTROL}"

# Login item controls. 'enforce' or 'allow'
LOGIN_ITEM_CONTROL="${LOGIN_ITEM_CONTROL}"

# Safari option. 'enforce' or 'allow'
SAFARI_CONTROL="${SAFARI_CONTROL}"

# Email domain.
BTENFORCE_DOMAIN="${BTENFORCE_DOMAIN}"

# Safari blocking option. 'osascript', 'pgrep'
SAFARI_CONTROL_METHOD="${SAFARI_CONTROL_METHOD}"

# Log file path (directory only - a new file is created each day with the date in the filename).
BTENFORCE_LOG_DIR="${BTENFORCE_LOG_DIR}"

# Time constraint override.
TIME_CONSTRAINT_OVERRIDE="${TIME_CONSTRAINT_OVERRIDE}"

# Log retention period.
LOG_RETENTION="${LOG_RETENTION}"
EOF

append_log "Created configuration file: ${BTENFORCE_CONFIG}"

# Reset variables so that we can test that we can source them from the file for testing purposes.
BTENFORCE_ACTIVE=""
BTENFORCE_START_TIME=""
BTENFORCE_STOP_TIME=""
BLUETOOTH_CONTROL=""
LOGIN_ITEM_CONTROL=""
SAFARI_CONTROL=""
BTENFORCE_DOMAIN=""
SAFARI_CONTROL_METHOD=""
TIME_CONSTRAINT_OVERRIDE=""
LOG_RETENTION=""
append_log "Unset initial variables."

# Check if the configuration file exists.
if [[ ! -f "$BTENFORCE_CONFIG" ]]; then
	append_log "❌ $BTENFORCE_CONFIG is not found."
	exit 1
fi

# Configure read only permissions for the config file.
chmod 644 "$BTENFORCE_CONFIG"
chown root:wheel "$BTENFORCE_CONFIG"
append_log "Set permissions and ownership for ${BTENFORCE_CONFIG}."

# Source the config file
if source "$BTENFORCE_CONFIG"; then
	append_log "Sourced ${BTENFORCE_CONFIG}."
else
	append_log "❌ Failed to source ${BTENFORCE_CONFIG}."
	exit 1
fi

# Check if the configuration file is valid.
if check_config_values; then
	append_log "Configuration file is valid."
else
	append_log "❌ Configuration file is not valid. Exiting."
	exit 1
fi

if [[ ! -f "$BLUEUTIL" ]] || [[ "$OVERWRITE_BLUEUTIL" = "true" ]]; then
	if ! copy_file "/usr/local/share/blueutil" "${BLUEUTIL}"; then
		NO_BLUEUTIL="true"
	fi
elif [[ -f "$BLUEUTIL" ]] && [[ "$OVERWRITE_BLUEUTIL" = "false" ]]; then
	append_log "OVERWRITE_BLUEUTIL is set to false. Skipping blueutil copy." 
fi

if [[ -f "$BLUEUTIL" ]] && [[ ! -x "$BLUEUTIL" ]]; then
	chmod +x "$BLUEUTIL"
	append_log "Set ${BLUEUTIL} executable flag."
fi

# Check whether the daemon is running.
daemon_status=$( launchctl list | grep "com.itech.btenforce" || true )

# If the daemon isn't running, start it.
if [[ -z "$daemon_status" ]]; then
	if ! start_daemon; then
		append_log "❌ The LaunchDaemon has failed to start."
		exit 1
	else
		append_log "✅ The LaunchDaemon has been started."
	fi
else
	append_log "Daemon is already running."
fi

if [[ "$BLUETOOTH_CONTROL" == "enforce" ]]; then
	enable_bluetooth
fi

exit 0