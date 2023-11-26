#!/bin/bash

######################################################################################### 
# Checks if Bluetooh is turned on.  If it's off, turn it back on and send
# info via json to make.com where it then sends an email to the student and the 
# tech department. Use in conjuction with a launch daemon that runs every 10 seconds.
# 
# Place this script in: /Library/Scripts/BTEnforce.sh
# The launch daemon should be placed in /Library/LaunchDaemons/com.itech.btenforce.plist
#
# blueutil must be installed first - https://github.com/toy/blueutil
#
# Keith Myers 9/7/2023 | https://www.i-techsupport.com/educational-tech/
########################################################################################

# Get the computer name for the log.
computerName=$(scutil --get ComputerName)

# Get the username for the log.
username=$([[ $3 ]] && echo "$3" || defaults read /Library/Preferences/com.apple.loginwindow lastUserName)

# Format the email address.
email="${username}@yourdomain.org"

# make.com webhook URL.
makeURL="https://hook.us1.make.com/yourWebhook"

# blueutil binary.
butil="/usr/local/bin/blueutil"

# Fails if the bluetooth utility isn't installed.
if [[ ! -f "$butil"  ]]; then
	echo "Unable to find $butil, exiting."
	exit 1
fi

# Required to run as root.
export BLUEUTIL_ALLOW_ROOT=1

# Get the status of the Bluetooth adapter.
status=$( ${butil} | head -n 1 | awk -F':' '{print $NF}')

# If Bluetooth is off, turn it back on.
if [[ "$status" -eq 0 ]]; then
	"$butil" --power 1
	
	# Format JSON data and post to webhook for processing.
	curl -X POST $makeURL -H 'Content-type: application/json' -d '{"computername":"'$computerName'","username":"'$username'","email":"'$email'"}' 

	# Write to the unified system log.  Retrieve with:  log show --predicate 'eventMessage contains "Reactivated Bluetooth"'
	logger -is -t BTEnforce "Reactivated Bluetooth"
fi
	
exit 0
		