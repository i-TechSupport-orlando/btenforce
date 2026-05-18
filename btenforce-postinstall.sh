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

VERSION="2.1"
SCRIPT_PATH="${0:A}"

# ======================================================================
# Jamf Pro parameters. Comment this block out if running post install
# script directly or using Mosyle or no MDM.
#
BTENFORCE_ACTIVE="${4:-true}"
BTENFORCE_START_TIME="${5}"
BTENFORCE_STOP_TIME="${6}"
BLUETOOTH_CONTROL="${7:-enforce}"
SAFARI_CONTROL="${8:-enforce}"
SAFARI_CONTROL_METHOD="${9:-pgrep}"
BTENFORCE_DOMAIN="${10}"
LOGIN_ITEM_CONTROL="${11:-enforce}"
BTENFORCE_DEBUG_MODE="${12:-false}"
BTENFORCE_LOG_FILE="${13:-/var/log/btenforce.log}"
TIME_CONSTRAINT_OVERRIDE="${14:-false}"
LOG_RETENTION="${15:-180}"
MDM_TYPE="Jamf Pro"
# ======================================================================


# ======================================================================
# Mosyle (or no MDM) parameters. Uncomment this block if using Mosyle
# OR no MDM. Replace values as needed.
#
# BTENFORCE_ACTIVE="true"             # true or false
# BTENFORCE_START_TIME="08:00"        # Start time in 24-hour format
# BTENFORCE_STOP_TIME="15:30"         # Stop time in 24-hour format
# BLUETOOTH_CONTROL="allow"           # allow or enforce
# SAFARI_CONTROL="enforce"            # allow or enforce
# SAFARI_CONTROL_METHOD="pgrep"       # osascript or pgrep
# BTENFORCE_DOMAIN="<domain>"         # domain to enforce
# LOGIN_ITEM_CONTROL="enforce"        # allow or enforce
# BTENFORCE_DEBUG_MODE="false"        # true or false
# BTENFORCE_LOG_FILE="/var/log/btenforce.log"
# TIME_CONSTRAINT_OVERRIDE="false"    # true or false
# LOG_RETENTION="180"                 # Integer number of days to keep log files
# MDM_TYPE="Mosyle/Other"
# =====================================================================

# Do not edit below this line.


# Add the date and time stamp to the log file.
append_log () {
    local message="$1"
    
    # Strip ANSI color codes AND leading newlines for the log files.
    # The sed pipeline removes ANSI escape sequences and deletes the first line if it is empty.
    local clean_text="$( echo -e "$message" | sed 's/\x1b\[[0-9;]*m//g' | sed '1{/^$/d;}' )"
    
    local date_stamp="$( date +"%Y-%m-%d %H:%M:%S" )"
    local file_log_msg="${date_stamp} -- ${clean_text}"
    local syslog_msg="version ${VERSION} -- ${clean_text}"

    # If stdout is a terminal (interactive session), keep the colors.
    if [[ -t 1 ]]; then
        # Echo the message with the ANSI color codes to the terminal.
        echo -e "$message"
    else
        # In MDM or redirected log files, strip ANSI color codes.
        echo "$clean_text"
    fi

    # Append clean message to the persistent log file
    echo "$file_log_msg" >> "$BTENFORCE_LOG_FILE"
    
    # Log to syslog without echoing to stderr again
    logger -i -t btenforce "$syslog_msg"
}

add_leading_zero() {
    local time="$1"
	local time_array=(${(s/:/)time})
	local hour="${time_array[1]}"
	local minute="${time_array[2]}"

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

	# Split the string on the colon character into an array.
	local time_array=(${(s/:/)time})

	local hour="${time_array[1]}"
	local minute="${time_array[2]}"

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
		append_log "BTENFORCE_ACTIVE is set to ${BTENFORCE_ACTIVE} which is not a valid value."
		append_log "Rerun this script with the parameters set, or configure the daemon manually with -configure."
		return 1
	fi

	if [[ -n "$BTENFORCE_START_TIME" ]]; then
		BTENFORCE_START_TIME=$( add_leading_zero "$BTENFORCE_START_TIME" )

		if check_time_integer "$BTENFORCE_START_TIME"; then
			append_log "BTENFORCE_START_TIME is set to ${BTENFORCE_START_TIME}"
		else
			append_log "BTENFORCE_START_TIME is set to ${BTENFORCE_START_TIME} which is not a valid value."
			append_log "Rerun this script with the parameters set, or configure the daemon manually with -configure."
			return 1
		fi
	else
		append_log "BTENFORCE_START_TIME is not set."
		return 1
	fi

	if [[ -n "$BTENFORCE_STOP_TIME" ]]; then
		BTENFORCE_STOP_TIME=$( add_leading_zero "$BTENFORCE_STOP_TIME" )
		
		if check_time_integer "$BTENFORCE_STOP_TIME"; then
			append_log "BTENFORCE_STOP_TIME is set to ${BTENFORCE_STOP_TIME}"
		else
			append_log "BTENFORCE_STOP_TIME is set to ${BTENFORCE_STOP_TIME} which is not a valid value."
			append_log "Rerun this script with the parameters set, or configure the daemon manually with -configure."
			return 1
		fi
	else
		append_log "BTENFORCE_STOP_TIME is not set."
		return 1
	fi

	# Check whether the Safari control method is set.
	if [[ -n "$SAFARI_CONTROL_METHOD" ]]; then
		if [[ "$SAFARI_CONTROL_METHOD" = "osascript" ]] || [[ "$SAFARI_CONTROL_METHOD" = "pgrep" ]]; then
			append_log "SAFARI_CONTROL_METHOD is set to ${SAFARI_CONTROL_METHOD}"
		else
			append_log "SAFARI_CONTROL_METHOD is set to ${SAFARI_CONTROL_METHOD} which is not a valid value."
			append_log "Rerun this script with the parameters set, or configure the daemon manually with -configure."
			return 1
		fi
	else
		append_log "SAFARI_CONTROL_METHOD is not set."
		return 1
	fi

	# Check whether the Bluetooth control method is set.
	if [[ -n "$BLUETOOTH_CONTROL" ]]; then
		if [[ "$BLUETOOTH_CONTROL" = "enforce" ]] || [[ "$BLUETOOTH_CONTROL" = "allow" ]]; then
			append_log "BLUETOOTH_CONTROL is set to ${BLUETOOTH_CONTROL}"
		else
			append_log "BLUETOOTH_CONTROL is set to ${BLUETOOTH_CONTROL} which is not a valid value."
			append_log "Rerun this script with the parameters set, or configure the daemon manually with -configure."
			return 1
		fi
	else
		append_log "BLUETOOTH_CONTROL is not set."
		return 1
	fi

	# Check whether the login item control is set.
	if [[ -n "$LOGIN_ITEM_CONTROL" ]]; then
		if [[ "$LOGIN_ITEM_CONTROL" = "enforce" ]] || [[ "$LOGIN_ITEM_CONTROL" = "allow" ]]; then
			append_log "LOGIN_ITEM_CONTROL is set to ${LOGIN_ITEM_CONTROL}"
		else
			append_log "LOGIN_ITEM_CONTROL is set to ${LOGIN_ITEM_CONTROL} which is not a valid value."
			append_log "Rerun this script with the parameters set, or configure the daemon manually with -configure."
			return 1
		fi
	else
		append_log "LOGIN_ITEM_CONTROL is not set."
		return 1
	fi

	# Check whether the domain is set.
	if [[ -n "$BTENFORCE_DOMAIN" ]]; then
		append_log "BTENFORCE_DOMAIN is set to ${BTENFORCE_DOMAIN}"
	else
		append_log "BTENFORCE_DOMAIN is not set."
		return 1
	fi

	# Check whether the debug mode is set.
	if [[ -n "$BTENFORCE_DEBUG_MODE" ]]; then
		if [[ "$BTENFORCE_DEBUG_MODE" = "true" ]] || [[ "$BTENFORCE_DEBUG_MODE" = "false" ]]; then
			append_log "BTENFORCE_DEBUG_MODE is set to ${BTENFORCE_DEBUG_MODE}"
		else
			append_log "BTENFORCE_DEBUG_MODE is set to ${BTENFORCE_DEBUG_MODE} which is not a valid value."
			append_log "Rerun this script with the parameters set, or configure the daemon manually with sudo btenforce -configure."
			return 1
		fi
	else
		append_log "BTENFORCE_DEBUG_MODE is not set."
		return 1
	fi

	# Check whether the log file path is set.
	if [[ -n "$BTENFORCE_LOG_FILE" ]]; then
		append_log "BTENFORCE_LOG_FILE is set to ${BTENFORCE_LOG_FILE}"
	else
		append_log "BTENFORCE_LOG_FILE is not set."
		return 1
	fi

	# Check whether the time constraint override is set.
	if [[ -n "$TIME_CONSTRAINT_OVERRIDE" ]]; then
		if [[ "$TIME_CONSTRAINT_OVERRIDE" = "true" ]] || [[ "$TIME_CONSTRAINT_OVERRIDE" = "false" ]]; then
			append_log "TIME_CONSTRAINT_OVERRIDE is set to ${TIME_CONSTRAINT_OVERRIDE}"
		else
			append_log "TIME_CONSTRAINT_OVERRIDE is set to ${TIME_CONSTRAINT_OVERRIDE} which is not a valid value."
			append_log "Rerun this script with the parameters set, or configure the daemon manually with -configure."
			return 1
		fi
	else
		append_log "TIME_CONSTRAINT_OVERRIDE is not set."
		return 1
	fi

	# Check whether the log retention period is set.
	if [[ -n "$LOG_RETENTION" ]]; then
		if [[ "$LOG_RETENTION" =~ ^[0-9]+$ ]]; then
			append_log "LOG_RETENTION is set to ${LOG_RETENTION}"
		else
			append_log "LOG_RETENTION is set to ${LOG_RETENTION} which is not a valid value."
			append_log "Rerun this script with the parameters set, or configure the daemon manually with -configure."
			return 1
		fi
	else
		append_log "LOG_RETENTION is not set."
		return 1
	fi

	return 0
}

enable_bluetooth() {
	if [[ ! -f "$butil" ]]; then
		if [[ -f /usr/local/share/blueutil ]]; then
			cp "/usr/local/share/blueutil" "$butil"
			chmod 755 "$butil"
			chown root:wheel "$butil"
		else
			append_log "Blueutil not found at either ${butil} or /usr/local/share/blueutil. Skipping turning on Bluetooth."
			return 1
		fi
	fi

	export BLUEUTIL_ALLOW_ROOT=1

	if [[ -z "$loggedInUser" ]] || [[ -z "$uid" ]]; then
		append_log "Either nobody is logged on, or the user ID could not be determined. Skipping turning on Bluetooth."
	else
		# Turn on Bluetooth for the logged in user to force the allow prompt.
		launchctl asuser "$uid" sudo -u "$loggedInUser" "$butil" -p 0
		sleep 1
		launchctl asuser "$uid" sudo -u "$loggedInUser" "$butil" -p 1
	fi
	
	return 0
}

# Main Script
CONFIG_DIR="/Library/Application Support/i-Tech"
CONFIG_FILE="${CONFIG_DIR}/btenforce.env"
PLIST="/Library/LaunchDaemons/com.itech.btenforce.plist"

btenforce="/usr/local/bin/btenforce"
butil="/usr/local/bin/blueutil"

# Username of the user currently logged on and their ID.
loggedInUser=$( echo "show State:/Users/ConsoleUser" | scutil | awk '/Name :/ && ! /loginwindow/ { print $3 }' )

if [[ -n "$loggedInUser" ]]; then
	uid=$(id -u "$loggedInUser")
else
	uid=""
fi

# Required to run as root.
export BLUEUTIL_ALLOW_ROOT=1


trap 'echo "❌ Error on line $LINENO: $(sed -n ${LINENO}p "$0")" >> "$BTENFORCE_LOG_FILE"' ERR
append_log "Started installation"

## Create the configuration directory.
if [[ ! -d "$CONFIG_DIR" ]]; then
	mkdir -p "$CONFIG_DIR"
	append_log "Created ${CONFIG_DIR}"
fi

cat << EOF > "$CONFIG_FILE"

## ╔══════════════════════════════╗
## ║ btenforce Configuration File ║
## ║  _     _____         _       ║
## ║ (_)   |_   _|__  ___| |__.   ║
## ║ | |_____| |/ _ \/ __| '_  \  ║
## ║ | |_____| |  __/ (__| | | |  ║
## ║ |_|     |_|\___|\___|_| |_|  ║
## ║                              ║
## ║ ▶︎ https://i-techsupport.com  ║
## ║ ☎ (407) 265-2000 option: #1  ║
## ║ ✉ support@i-techsupport.com  ║
## ║ Author: Keith Myers, i-Tech  ║
## ║ (C) 2026 i-Tech Support Inc  ║
## ╚══════════════════════════════╝

# Version: ${VERSION}
# Configured on: $( date +"%Y-%m-%d %H:%M:%S" ) | via ${MDM_TYPE}
# Postinstall script path: "${SCRIPT_PATH}"

# Enable/disable the daemon as a whole with 'true' or 'false'
BTENFORCE_ACTIVE="${BTENFORCE_ACTIVE}"

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

# Debug mode
BTENFORCE_DEBUG_MODE="${BTENFORCE_DEBUG_MODE}"

# Log file path.
BTENFORCE_LOG_FILE="${BTENFORCE_LOG_FILE}"

# Time constraint override.
TIME_CONSTRAINT_OVERRIDE="${TIME_CONSTRAINT_OVERRIDE}"

# Log retention period.
LOG_RETENTION="${LOG_RETENTION}"
EOF

echo "Created configuration file: ${CONFIG_FILE}"

# Reset variables so that we can test that we can source them from the file for testing purposes.
BTENFORCE_ACTIVE=""
BTENFORCE_START_TIME=""
BTENFORCE_STOP_TIME=""
BLUETOOTH_CONTROL=""
LOGIN_ITEM_CONTROL=""
SAFARI_CONTROL=""
BTENFORCE_DOMAIN=""
SAFARI_CONTROL_METHOD=""
BTENFORCE_DEBUG_MODE=""
TIME_CONSTRAINT_OVERRIDE=""
LOG_RETENTION=""
append_log "Unset initial variables."

# Check if the configuration file exists.
if [[ ! -f "$CONFIG_FILE" ]]; then
	append_log "$CONFIG_FILE is not found."
	exit 1
fi

# Configure read only permissions for the config file for non-root users.
chmod 644 "$CONFIG_FILE"
append_log "Made ${CONFIG_FILE} read-only."

# Source the config file
source "$CONFIG_FILE"
append_log "Sourced ${CONFIG_FILE}."

# Check if the configuration file is valid.
if check_config_values; then
	append_log "Configuration file is valid."
else
	append_log "Configuration file is not valid. Exiting."
	exit 1
fi

# Check whether the source files exist.
if [[ ! -x "$butil" ]]; then
	append_log "WARNING: ${butil} is not executable or missing. Bluetooth control will not work."
	append_log "Install blueutil from https://github.com/toy/blueutil to fix this."
fi

if [[ -f "$btenforce" ]]; then
	append_log "Found ${btenforce}"

	# Remove the quarantine attribute and set execute permission for ${btenforce}
	xattr -dr com.apple.quarantine "$btenforce"
	chmod +x "$btenforce"
	append_log "Removed quarantine attribute and set execute permission for ${btenforce}"
else
	append_log "Cannot find ${btenforce}"
	exit 1
fi

if [[ -z "$loggedInUser" ]] || [[ -z "$uid" ]]; then
	append_log "Either nobody is logged on, or the user ID could not be determined. Skipping turning on Bluetooth."
else
	# Turn on Bluetooth for the logged in user to force the allow prompt.
	launchctl asuser "$uid" sudo -u "$loggedInUser" /usr/local/bin/blueutil -p 0
	sleep 1
	launchctl asuser "$uid" sudo -u "$loggedInUser" /usr/local/bin/blueutil -p 1
fi

# Check whether the daemon is running.
daemon_status=$( launchctl list | grep "com.itech.btenforce" || true )

# Already running. Unload and reload.
if [[ -n "$daemon_status" ]]; then
	launchctl bootout system/com.itech.btenforce
	sleep 3
	launchctl bootstrap system "$PLIST"
	sleep 3
	daemon_status=$( launchctl list | grep "com.itech.btenforce" || true )
	if [[ -n "$daemon_status" ]]; then
		append_log "LaunchDaemon installed and reloaded."
		enable_bluetooth
		exit 0
	else
		launchctl bootstrap system "$PLIST"
		sleep 3
		daemon_status=$( launchctl list | grep "com.itech.btenforce" || true )
		if [[ -n "$daemon_status" ]]; then
			append_log "LaunchDaemon installed and reloaded."
			enable_bluetooth
			exit 0
		else
			append_log "The daemon failed to reload."
			exit 1
		fi
	fi
else
	append_log "Installing new LaunchDaemon..."
fi

# Start the daemon.
launchctl bootstrap system "$PLIST"

sleep 3

daemon_status=$( launchctl list | grep "com.itech.btenforce" || true )

if [[ -n "$daemon_status" ]]; then
	append_log "LaunchDaemon installed and loaded."
	enable_bluetooth
	append_log "Finished installation"
	exit 0
else
	append_log "The daemon failed to start."
	append_log "Full output: ${daemon_status}"
	append_log "Installation failure."
	exit 1
fi

