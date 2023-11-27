#!/bin/bash

# Stop the daemon
launchctl unload /Library/LaunchDaemons/com.itech.btenforce.plist 2> /dev/null

# Start the daemon
launchctl load /Library/LaunchDaemons/com.itech.btenforce.plist 2> /dev/null

exit 0
