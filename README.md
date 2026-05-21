# btenforce for macOS
Tested on macOS 13, 14, 15, and 26

Students love to turn Bluetooth off in an effort to thwart classroom monitoring tools. You cannot force Bluetooth to be on with an MDM profile because it then prevents the end-user from connecting peripherals. Also, if Bluetooth is off at the time you install the profile, the end-user will be unable to turn it back on.

A very simple launch daemon runs a script that checks if Bluetooth is turned off.  If it's off, the script turns it back on. I have found that setting the launch daemon to a 5 second interval works the best. 

## Version 2.1 Changes
- Abandoned the app bundle structure. The package installer places the main script in `/usr/local/bin/btenforce` and `blueutil` in `/usr/local/share/btenforce/blueutil`, and the daemon in `/Library/LaunchDaemons/com.itech.btenforce.plist`.
- `btenforce` is now a combination of the Bluetooth utility plus other functions such as Safari control and login item control. See the config file for more information.
- The included version of `blueutil` is version 2.9 due to some irregularities with newer versions on macOS 26.
- Removed ANSI color coding from log messages.
- Reduced the interval to 5 seconds.
- Added logging to configuration function.
- Prevents reconfiguring by standard users by forcing root access.
- Cleaned up redundant login check.
- Added log retention period to the configuration options.
- Added function to append missing configuration variables to the config file. This was necessary because previous versions of `btenforce` may have been installed without the new variables.
- Added comprehensive configuration variable validation in post-install script.
- Replaced deprecated `launchctl unload` / `launchctl load` with `bootout`/`bootstrap`.
- Added version to `blueutil` on install/update for logging.
- Added check for `blueutil` and then copy it from `/usr/local/share/btenforce/blueutil` if not found in `/usr/local/bin`. The package doesn't overwrite `blueutil` in `/usr/local/bin` by default.
- Added version to the log header in the config file for easy identification.
- Refined configuration function for usability and convenience. It will now check for configuration errors in the config file and report them to the admin user that's configuring `btenforce`.
- Enhanced time entry and validation for the configuration function.
- Added warning when configuring Safari function with `osascript` method on macOS.
- Added the method used to configure `btenforce` to the config file along with the time and date of the configuration.
- Added check for `BTENFORCE_ACTIVE` in config file and exit if not found.
- Changed logic to continue if no user is logged on, then skip the controls and log the exit code.
- Added trap for `INT` and `TERM` signals to log the exit code and exit.
- Added trap for `ERR` signal to log the error message and exit.
- Reduced unessential log entries when school is not in session by adding a flag file to prevent the script from logging on every execution.
- Modified the shebang from `/bin/zsh` to `/bin/bash` for compatibility in the post-install script. since that will be most likely executed by an MDM and if Mosyle, must be Bash.
- Added default config values so that btenforce will function without customizing the config. Only Bluetooth enforcement is activated by default. Configure with --configure for other options, or use the btenforce-postinstall.sh script to configure btenforce with your desired settings.
- Added inactive flag to prevent needless logging while the daemon is disabled, the user is logged off, or during times outside of the configured school hours.
- Added function to download & install the daemon plist if missing.
- Corrected logic issue with the during_school_hours function.
- Added an option to adjust the interval in which `btenforce` runs.

### Blueutil version
When macOS 26 was released, the latest versions of `blueutil` no longer worked with `btenforce`. The version that I've had the most luck with was version 2.9. I have included this version of blueutil in the package installer. The package copies the 2.9 binary to `/usr/local/share/blueutil` When `btenforce` is called, it checks whether `blueutil` exists in `/usr/local/bin/blueutil`. If it doesn't exist, it copies it from `/usr/local/share/blueutil` to `/usr/local/bin/blueutil`.

## Configuration variables and default values
```bash
# Enable/disable the daemon as a whole ('true' or 'false')
BTENFORCE_ACTIVE=true

# Interval between checks in seconds (1-3600)
BTENFORCE_INTERVAL="5"

# School start time in 24-hour clock. (HH:mm)
BTENFORCE_START_TIME="07:00"

# School stop time in 24-hour clock (HH:mm)
BTENFORCE_STOP_TIME="15:00"

# Bluetooth option ('enforce' or 'allow')
BLUETOOTH_CONTROL="enforce"

# Login item controls ('enforce' or 'allow')
LOGIN_ITEM_CONTROL="allow"

# Safari option ('enforce' or 'allow')
SAFARI_CONTROL="allow"

# Email domain
BTENFORCE_DOMAIN="yourdomain.com"

# Safari blocking option ('osascript', 'pgrep')
SAFARI_CONTROL_METHOD="pgrep"

# Log file path
BTENFORCE_LOG_FILE="/var/log/btenforce.log"

# Time constraint override
TIME_CONSTRAINT_OVERRIDE="false"

# Log retention in days
LOG_RETENTION="180"

```
## Daemon Status and Control
- Check Daemon:    `sudo launchctl list | grep itech` A positive result will show something similar to `-  0   com.itech.btenforce`
- Unload Daemon:   `sudo launchctl bootout system/com.itech.btenforce`
- Load Daemon:     `sudo launchctl bootstrap system /Library/LaunchDaemons/com.itech.btenforce.plist`
- Restart Daemon:  `sudo launchctl bootout system/com.itech.btenforce && sudo launchctl bootstrap system /Library/LaunchDaemons/com.itech.btenforce.plist`

# Installing `btenforce`

## Manual Installation
1. Copy `btenforce` to `/usr/local/bin`
2. Copy `blueutil` to `/usr/local/bin`
3. Copy `com.itech.btenforce.plist` to `/Library/LaunchDaemons`
4. Copy `btenforce.env` to `/Library/Application Support/i-Tech/btenforce`
5. Set ownership of the files to `root:wheel` and set permissions to prevent changes by students (`644`)
6. Run `sudo launchctl bootstrap system /Library/LaunchDaemons/com.itech.btenforce.plist`

## Jamf Pro Installation
1. Upload `btenforce-pppc.mobileconfig` to Jamf Pro and scope to target devices
2. Upload `btenforce2.1.pkg` to Jamf Pro
3. Upload `btenforce-postinstall.sh` to Jamf Pro and configure the desired options
4. Create a policy to install `btenforce2.1.pkg` and run `btenforce-postinstall.sh` with the desired parameters.

## Mosyle Installation
1. Install `btenforce-pppc.mobileconfig` to the target macOS devices			
2. Distribute `btenforce2.1.pkg` to the target macOS devices
3. Edit `btenforce-postinstall.sh` to comment out the Jamf Pro parameters or use the defaults
4. Create a Mosyle custom command to run `btenforce-postinstall.sh` and scope to the endpoints that have received the package

# Dependencies
`blueutil` - https://github.com/toy/blueutil. The packaged release of btenforce contains `blueutil` version 2.9.

# Safari Prevention
Most schools prefer students use Google Chrome due to the robust feature set designed spcificaly with schools in mind. The problem is macOS does not have an easy way to restrict its usage by end-users. `btenforce` effectively prevents Safari from being used because if the app is detected, it's killed. Hopefully Apple adds more robust web browser restrictions in a future version of macOS. It's extremely effective, but ensure that `btenforce` is installed after anyworkflows that require Safari such as before Chrome (or another browser) is installed. `btenforce` should not be enabled early in the enrollment process with `$SAFARI_CONTROL` set to `enforce`.

## Safari Control Methods
- osascript: This is the most accurate method as it will only alert to open Safari windows. This requires you to install the config profile `btenforce PPPC.mobileconfig`.
- pgrep:     If osascript isn't possible due to a prompting the students to approve it, or you cannot create a PPPC profile, this is a good alternative. It will have some false positives though. `pgrep` is the default method used. If `$SAFARI_CONTROL` is set to `allow`, `$SAFARI_CONTROL_METHOD` will be ignored.

## Jamf Pro Tip
Create a smart group with the criteria of 'Application title has Google Chrome.app' to group computers that have Chrome installed, then create a software restriction for process name `Safari` and check the box labeled 'kill process'. Then, scope the software restriction to the smart group. `btenforce` will then detect if Safari is open and kill it, so if the student found a way around the software restriction, it will still be prevented.

## Mosyle Tip
Migrate to Jamf Pro ;-)

# Delete Login Items
`LOGIN_ITEM_CONTROL="enforce"` Deletes all user added login items. This prevents the students from loading software when the machine boots. This is a tactic used by students on managed macOS devices to launch software that is restricted by Jamf Pro. There's a delay between when the device boots and when Jamf Pro's software restrictions feature begins enforcing restricted software. Restricting login items prevents the students from launching software on the restricted list. If a student adds a login item, it is quickly deleted by `btenforce`.

# Troubleshooting
- Bluetooth is not turning back on: Check that the current time is within the time window you set in the config file. Run `btenforce -debug` to test without time constraints. Another possible cause is that it's inside the time window but the daemon is not running. Use `sudo launchctl list | grep itech` to check if the daemon is running. If not, run `sudo launchctl bootstrap system /Library/LaunchDaemons/com.itech.btenforce.plist` to start it. Another possible reason is that the PPPC profile is not installed or the `blueutil` binary is not in the correct location. Check the install package receipt with `pkgutil --files /var/db/receipts/com.itech.btenforce.plist` to see if it was installed. If after it was installed the user clicked on "Don't Allow" for one of the prompts, you'll need to reinstall `btenforce`.
- If Bluetooth isn't turning back on during school hours, the other features may not be working either if you activated them. Check that `BTENFORCE_ACTIVE` is set to `true` in `/Library/Application Support/i-Tech/btenforce.env` or your custom env file location. Run `sudo launchctl bootout system/com.itech.btenforce` and `sudo launchctl bootstrap system /Library/LaunchDaemons/com.itech.btenforce.plist` to restart the daemon.
- View the logs at `/var/log/btenforce.log` or your custom log path.
- You may also obtain the log entries from the Unified Log with `log show --predicate 'eventMessage contains "btenforce"' --info --debug`. When `btenforce` is called by the daemon, it will appear in the log in a format similar to:
`launchd: [system/com.itech.btenforce [93638]:] Successfully spawned btenforce[93638] because interval`
- `btenforce -debug` will run the script in debug mode. Debug mode will override the day of week and time of day restrictions and run the script as though school is always in session. You may modify the configuration on a single computer with `btenforce -configure`, manually by editing `/Library/Application Support/i-Tech/btenforce.env`, or by pushing out a new `.env` file using your MDM with `btenforce-postinstall.sh`. 

# Configuration Profile
`btenforce` needs some PPPC permissions to function correctly. Install `btenforce-pppc.mobileconfig` to grant permissions to `blueutil`. Once the profile is installed, the daemon should be able to run `blueutil` as the end-user. YMMV. It's a good idea to install `btenforce` during macOS enrollment so that you can click on "Allow" if prompted.

---
Copyright (c) 2026 i-Tech Support Inc.
https://www.i-techsupport.com | info@i-techsupport.com