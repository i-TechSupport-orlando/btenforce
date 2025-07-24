#!/bin/zsh

## ╔══════════════════════════════════════════════════════════════════╗
## ║  App Bundle Script for KillSafari, BTEnforce, and remloginItems  ║
## ║    Author: Keith Myers, i-Tech | keith.myers@i-techsupport.com   ║
## ╚══════════════════════════════════════════════════════════════════╝
##
## This software is intended to run by schools to gain control over students'
## school-owned devices when it comes to Bluetooth, running Safari, and adding
## invalid or inappropriate applications to the automatic login items.
##
## Unified log entries can be retrieved with: 
##    log show --predicate 'eventMessage contains "Reactivated BT"' --info --debug
##    log show --predicate 'eventMessage contains "Killed Safari for"' --info --debug

## Application configuration file.
BTENFORCE_CONFIG="/Library/Application Support/i-Tech/btenforce.env"

## Location of AppBundle files.
APP_BUNDLE_DIR="$(cd "$(dirname "$0")/../.." && pwd)"
PLIST_SOURCE="$APP_BUNDLE_DIR/Contents/Resources/com.itech.btenforce.plist"
PLIST_DEST="/Library/LaunchDaemons/com.itech.btenforce.plist"

## Username of the user currently logged on.
loggedInUser=$( echo "show State:/Users/ConsoleUser" | scutil | awk '/Name :/ && ! /loginwindow/ { print $3 }' )
uid=$(id -u "$loggedInUser")


## Add the date and time stamp to the log file.
append_log () {
    local message="$1"
    dt=$( date +"%Y-%m-%d %H:%M:%S" )
    echo "${dt} -- ${message}" | tee -a "$BTENFORCE_LOG_FILE"
}

## Run the command as the logged in user. Needed for osascript.
runAsUser() {  
    if [ "$loggedInUser" != "loginwindow" ]; then
        launchctl asuser "$uid" sudo -u "$loggedInUser" "$@"
    else
        append_log "Not logged on"
    fi
}

## Install the LaunchDaemon if it doesn't exist. This is a falback measure. It should be installed by the MDM.
install_daemon () {
    if [[ ! -f "$PLIST_DEST" ]]; then
        cp "$PLIST_SOURCE" "$PLIST_DEST"
        chown root:wheel "$PLIST_DEST"
        chmod 644 "$PLIST_DEST"
        launchctl load "$PLIST_DEST"
        append_log "LaunchDaemon installed and loaded."
    fi
}

## Check whether Bluetooth is on or off.
check_bluetooth () {
    btutil="/usr/local/bin/blueutil"
    
    if [[ ! -f "$btutil" ]]; then
        append_log "Error: Could not find the Bluetooth utility. Exiting without action."
        logger -is -t BTEnforce "Couldn't find ${btutil}."
        return 1
    fi
    
    ## Required to run as root.
    export BLUEUTIL_ALLOW_ROOT=1
    
    ## Get the status of the Bluetooth adapter.
    bstatus=$(/usr/local/bin/blueutil | head -n 1 | awk -F':' '{print $NF}')
    
    ## If Bluetooth is off, turn it back on.
    if [[ "$bstatus" -eq 0 ]]; then
        /usr/local/bin/blueutil --power 1
        local msg="Reactivated BT. User: ${loggedInUser}"
        ## Write to the unified system log.  
        logger -is -t BTEnforce "$msg"
        append_log "$msg"
    fi
}

## Close Safari by killing the process if it's open.
check_safari () {
    
    if [[ "$SAFARI_CONTROL_METHOD" == "osascript" ]]; then
    
        safari_is_open=$( osascript <<EOF
tell application "System Events"
set safariRunning to (name of processes) contains "Safari"
end tell

if safariRunning then
    tell application "Safari"
        if (count of windows) > 0 then
            return "true"
        end if
    end tell
end if

return "false"
EOF
)
        if [[ "$safari_is_open" == "true" ]]; then
            killall Safari &> /dev/null
            local msg="Killed Safari PID: ${proc} for ${loggedInUser} via osascript."
            logger -is -t BTEnforce "$msg"
            append_log "$msg"
            return 0
        fi
    elif [[ "$SAFARI_CONTROL_METHOD" == "pgrep" ]]; then
            safariProcs=$( ps aux | pgrep Safari )
            
        if pgrep -x "Safari" >/dev/null; then
            killall Safari &> /dev/null
            local msg="Killed Safari for ${loggedInUser} via pgrep"
            logger -is -t BTEnforce "$msg"
            append_log "$msg"
            return 0
        fi
    fi
}

## Check whether the current date/time is during regular school hours.
during_school_hours () {
    
    ## Get current time
    current_hour=$(date +%H)
    current_minute=$(date +%M)
    day_of_week=$(date +%u)
    
    ## Convert to integers
    current_total_minutes=$((10#$current_hour * 60 + 10#$current_minute))
    
    ## Define school hours in minutes since midnight
    start_total_minutes=$((BTENFORCE_START_TIME * 60))
    end_total_minutes=$((BTENFORCE_STOP_TIME * 60))
    
    ## Check if weekday (Mon–Fri) and time is between start and end
    if (( day_of_week >= 1 && day_of_week <= 5 )); then
        if (( current_total_minutes >= start_total_minutes && current_total_minutes < end_total_minutes )); then
            return 0  # true. School in session.
        fi
    fi
    return 1  # false. Night/weekend.
}

check_login_items () {
    ## Check if any login items exist for the current user
    login_item_count=$(runAsUser osascript -e '
    tell application "System Events"
    count login items
    end tell
    ')
        
    if [[ "$login_item_count" -gt 0 ]]; then
        runAsUser osascript -e 'tell application "System Events" to delete login items'
        login_item_status="Removed ${login_item_count} login items for ${loggedInUser}"
        append_log "$login_item_status"
        logger -is -t BTEnforce "$login_item_status"
    fi
}
            

## ══════════╣ MAIN SCRIPT ╠═══════════

## Source the configuration file.
if [[ -f "$BTENFORCE_CONFIG" ]]; then
    source "$BTENFORCE_CONFIG"
else
    missing_config="ERROR: Missing the config file ${BTENFORCE_CONFIG}"
    logger -is -t BTEnforce "$missing_config"
    echo "$missing_config"
    exit 1
fi

if [[ "$BTENFORCE_DEBUG_MODE" == "true" ]]; then
    set -x
    append_log "Debug mode has been enabled. For support, please contact i-Tech at (407) 265-2000."
    append_log "support@i-techsupport.com  https://www.i-techsupport.com"
else
    set +x
fi

if [[ "$BTENFORCE_ACTIVE" == "true" ]]; then

    ## Check the day and time, then perform actions if the current time is within the specified period.
    if during_school_hours; then
        
        ## Install the daemon if missing.
        if [[ ! -f "$PLIST_DEST" ]]; then
            append_log "Daemon not found. Installing..."
            install_daemon
        fi
        
        if [[ "$BLUETOOTH_CONTROL" == "enforce" ]]; then
            check_bluetooth
        fi
        
        if [[ "$SAFARI_CONTROL" == "enforce" ]]; then
            check_safari
        fi
        
        if [[ "$LOGIN_ITEM_CONTROL" == "enforce" ]]; then
            check_login_items
        fi
    fi
fi

exit 0
