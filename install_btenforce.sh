#!/bin/zsh

## ╔═════════════════════════════════════════════════════════════════╗
## ║         Installs i-Tech BTEnforce Bluetooth Enforcement       	 ║
## ║   Author: Keith Myers, i-Tech | keith.myers@i-techsupport.com   ║
## ╚═════════════════════════════════════════════════════════════════╝
## 
## 7/24/2025: Released 
##  
## Installs the software and activates the LaunchDaemon. The app is 
## configured via /Library/Application Support/i-Tech/btenforce.env
##
## (C) i-Tech Support Inc.


sw_url="https://github.com/i-TechSupport-orlando/btenforce/releases/download/v1.5/BTEnforce.pkg"
tmp_path="/tmp/btenforce"
out_package="${tmp_path}/BTEnforce.pkg"

## Application bundle.
app_bundle="/Applications/.i-Tech/BTEnforce.app"
new_plist="com.itech.btenforce.plist"

## BTEnforce.
plist_source="${app_bundle}/Contents/Resources/${new_plist}"
plist_dest="/Library/LaunchDaemons/${new_plist}"

## Log files.
log_file="/var/log/BTEnforce.log"
error_file="/var/log/BTEnforce_error.log"

max_tries=3

clean_up() {
	## Delete the temporary files.
	
	if [[ -d "$tmp_path" ]]; then
		rm -rf "$tmp_path"
		echo "Deleted ${tmp_path}."
	else
		echo "${tmp_path} did not exist."
	fi
}

download_software() {
	try=1
	
	## Create the temp path if it doesn't exist.
	mkdir -p "$tmp_path"

	while ((try < max_tries)); do
		## Download the software.
		curl -sfL --retry 3 -o "$out_package" "$sw_url"
		sleep 1
		
		## Ensure the file exists.
		if [[ -f "$out_package" ]]; then
			echo "Downloaded BTEnforce successfully."
			return 0
		else
			echo "Unable to download the software. Retrying..."
			((try++))
		fi
	done
	
	echo "Unable to download BTEnforce after ${max_tries} attempts."
	clean_up
	exit 1
}

activate_daemon () {
	touch "$log_file"
	touch "$error_file"
	
	## Copy the new plists
	cp "$plist_source" "$plist_dest"
	echo "Copied ${plist_source} to ${plist_dest}"
	
	chown root:wheel "$plist_dest"
	chmod 644 "$plist_dest"
	echo "Set ownership and permissions on ${plist_dest}"
	
	launchctl load "$plist_dest"
	sleep 2
	
	daemon_status=$( launchctl list | grep "itech" )
	
	if [[ -n "$daemon_status" ]]; then
		echo "LaunchDaemon installed and loaded."
		clean_up
		exit 0
	else
		echo "❌ The daemon failed to start."
		clean_up
		exit 1
	fi
	
}

install_software () {
	installer -pkg "$out_package" -target /
		
	sleep 2
		
	if [[ -e $app_bundle ]]; then
		echo "Installed BTEnforce by i-Tech successfully. Activating daemon..."
		activate_daemon
	else
		echo "❌ Could not find ${app_bundle}"
		clean_up
		exit 3
	fi
}

if download_software; then
	install_software
fi

exit 0

		
