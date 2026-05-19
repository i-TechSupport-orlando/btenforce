# btenforce for macOS
Tested on macOS 13, 14, 15, and 26

Students love to turn Bluetooth off in an effort to thwart classroom monitoring tools. You cannot force Bluetooth to be on with an MDM profile because it then prevents the end-user from connecting peripherals. Also, if Bluetooth is off at the time you install the profile, the end-user will be unable to turn it back on.

A very simple launch daemon runs a script that checks if Bluetooth is turned off.  If it's off, the script turns it back on. I have found that setting the launch daemon to ten seconds works the best. I originally had it set higher, but the students would continually turn it back off. Ten seconds seems to be too agravating for even the most determined students. 

## Version 2.1 Changes
- Abandoned the app bundle structure. The package installer places the main script in `/usr/local/bin/btenforce` and `blueutil` in `/usr/local/share/btenforce/blueutil`, and the daemon in `/Library/LaunchDaemons/com.itech.btenforce.plist`.
- `btenforce` is now a combination of the Bluetooth utility plus other functions such as Safari control and login item control. See the config file for more information.
- The included version of `blueutil` is version 2.9 due to some irregularities with newer versions on macOS 26.
- Removed ANSI color coding from log messages.
- Reduced the interval to 5 seconds.
- Added logging to configuration function.
- Prevents reconfiguring by standard users.
- Cleaned up redundant login check.
- Added log retention period to the configuration options.
- Added function to append missing configuration variables to the config file. This was necessary because previous versions of `btenforce` may have been installed without the new variables.
- Added comprehensive configuration variable validation in post-install script.
- Replaced deprecated `launchctl unload` / `launchctl load` with `bootout`/`bootstrap`.
- Added version to `blueutil` on install/update for logging.
- Added check for `blueutil` and then copy it from `/usr/local/share/btenforce/blueutil` if not found in `/usr/local/bin`. The package doesn't overwrite blueutil by default.
- Added `MDM_TYPE` variable for clarity in config file.
- Added version to the log header in the config file for easy identification.
- Refined configuration function for usability and convenience. It will now check for configuration errors in the config file and report them to the admin user that's configuring `btenforce`.
- Added parameters to postinstall script for Jamf Pro MDM and Mosyle MDM. See the notes in the postinstall script for more information.
- Enhanced time entry and validation for the configuration function.
- Added warning when configuring Safari function with `osascript` method on macOS.
- Added the method used to configure `btenforce` to the config file along with the time and date of the configuration.
- Reduced unessential noise from logs.
- Added check for `BTENFORCE_ACTIVE` in config file and exit if not found.
- Added i-Tech banner with support info.
- Changed logic to continue if no user is logged on, then skip the controls and log the exit code.
- Added trap for `INT` and `TERM` signals to log the exit code and exit.
- Added trap for `ERR` signal to log the error message and exit.
- Reduced unessential noise from logs when school is not in session by adding a flag file to prevent the script from logging on every execution.
- Modified the shebang from `/bin/zsh` to `/bin/bash` for compatibility in the post-install script. since that will be most likely executed by an MDM and if Mosyle, must be Bash.
- Added default config values so that btenforce will function without customizing the config. Only Bluetooth enforcement is activated by default. Configure with --configure for other options, or use the btenforce-postinstall.sh script to configure btenforce with your desired settings.
- Added inactive flag to prevent needless logging while the daemon is disabled.
- Added function to download & install the daemon plist if missing.
- Corrected logic issue with the during_school_hours function.

### Blueutil version
When macOS 26 was released, the latest versions of `blueutil` no longer worked with `btenforce`. The version that I've had the most luck with was version 2.9. I have included this version of blueutil in the package installer. The package copies the 2.9 binary to `/usr/local/share/blueutil` When `btenforce` is called, it checks whether `blueutil` exists in `/usr/local/bin/blueutil`. If it doesn't exist, it copies it from `/usr/local/share/blueutil` to `/usr/local/bin/blueutil`.

## Configuration variables and default values
```bash
# Enable/disable the daemon (bool)
BTENFORCE_ACTIVE="true"

# Fully qualified domain name (string)
BTENFORCE_DOMAIN="yourdomain.org"

# Safari blocking option. 'enforce', 'allow' (string)
SAFARI_CONTROL="allow"

# Safari blocking method. 'osascript', 'pgrep' (string)
SAFARI_CONTROL_METHOD="pgrep"

# Bluetooth blocking option. 'enforce', 'allow' (string)
BLUETOOTH_CONTROL="enforce"

# Login item control. 'enforce', 'allow' (string)
LOGIN_ITEM_CONTROL="allow"

# School start time in 24-hour clock. Format: HH:MM (string)
BTENFORCE_START_TIME="07:00"

# School stop time in 24-hour clock. Format: HH:MM (string)
BTENFORCE_STOP_TIME="15:00"

# Log file path (string)
BTENFORCE_LOG_FILE="/var/log/btenforce.log"

# Time constraint override. (bool)
TIME_CONSTRAINT_OVERRIDE="false"

# Log retention in days (int) Range: 7-1095
LOG_RETENTION="$LOG_RETENTION"`
```
## Safari Prevention
Most schools prefer students use Google Chrome due to the robust feature set designed spcificaly with schools in mind. The problem is macOS does not have an easy way to restrict its usage by end-users. `btenforce` effectively prevents Safari from being used because if the app is detected, it's killed. Hopefully Apple adds more robust web browser restrictions in a future version of macOS.

- osascript: This is the most accurate method as it will only alert to open Safari windows. This requires a config profile that I have yet to get working.
- pgrep:     If osascript isn't possible due to a prompting the students to approve it, or you cannot create a PPPC profile, this is a good alternative. It will have some false positives though. `pgrep` is the default method used. If `$SAFARI_CONTROL` is set to `allow`, `$SAFARI_CONTROL_METHOD` will be ignored.

## Delete Login Items
`LOGIN_ITEM_CONTROL="enforce"` Deletes all user added login items. This prevents the students from loading software when the machine boots. This is a tactic used by students on managed macOS devices to launch software that is restricted by Jamf Pro. There's a delay between when the device boots and when Jamf Pro's software restrictions feature begins enforcing restricted software. Restricting login items prevents the students from launching software on the restricted list. If a student adds a login item, it is quickly deleted by `btenforce`.

## Daemon Status and Control
- Check Daemon
`sudo launchctl list | grep itech` A positive result will show something similar to `-  0   com.itech.btenforce`
- Unload Daemon
`sudo launchctl bootout system/com.itech.btenforce`
- Load Daemon
`sudo launchctl bootstrap system/Library/LaunchDaemons/com.itech.btenforce.plist`
- Restart Daemon
`sudo launchctl bootout system/com.itech.btenforce && sudo launchctl bootstrap system/Library/LaunchDaemons/com.itech.btenforce.plist`

# Installing `btenforce`

## Manual Installation
1. Copy `btenforce` to `/usr/local/bin`
2. Copy `blueutil` to `/usr/local/bin`
3. Copy `com.itech.btenforce.plist` to `/Library/LaunchDaemons`
4. Copy `btenforce.env` to `/Library/Application Support/i-Tech/btenforce`
5. Set ownership of the files to `root:wheel` and set permissions to prevent changes by students (`644`)
6. Run `sudo launchctl bootstrap system/Library/LaunchDaemons/com.itech.btenforce.plist`

## Jamf Pro Installation
1. Upload `btenforce2.1.pkg` to Jamf Pro
2. Upload `btenforce-postinstall.sh` to Jamf Pro
3. Create a policy to install `btenforce2.1.pkg` and then run `btenforce-postinstall.sh` with the desired parameters.

## Mosyle Installation
1. Distribute the package to the target macOS devices
2. Edit `btenforce-postinstall.sh` to comment out the Jamf Pro params and uncomment the Mosyle params
3. Create a Mosyle custom command to run `btenforce-postinstall.sh` and scope to the endpoints that have received the package

# Dependencies
`blueutil` - https://github.com/toy/blueutil. The packaged release of btenforce contains `blueutil` version 2.9.

# Troubleshooting
- Bluetooth is not turning back on: The most likely cause for this is that it's currently outside of the time window you set in the config file. Run `btenforce --debug` to test without time constraints. Another possible cause is that it's inside the time window but the daemon is not running. Use `sudo launchctl list | grep itech` to check if the daemon is running. If not, run `sudo launchctl bootstrap system/Library/LaunchDaemons/com.itech.btenforce.plist` to start it.
- If the above is happening, the other features most likely are not working either since they are all controled via the same config file and daemon. Check `BTENFORCE_ACTIVE` in the config file and make sure it's set to `true`.
- View the logs at `/var/log/btenforce.log`
- You may also obtain the log entries from the Unified Log with `log show --predicate 'eventMessage contains "btenforce"' --info --debug`. When `btenforce` is called by the daemon, it will appear in the log in a format similar to:
`launchd: [system/com.itech.btenforce [93638]:] Successfully spawned btenforce[93638] because interval`

## Debugging
`btenforce --debug` will run the script in debug mode. Debug mode will override the day of week and time of day restrictions and run the script as though it is always in session. You may modify the configuration on a single computer with `btenforce --configure`. 

# Configuration Profile
`btenforce` needs some PPPC permissions to function correctly. Install `btenforce-pppc.mobileconfig` to grant permissions to `blueutil`. Once the profile is installed, the daemon should be able to run `blueutil` as the end-user. YMMV. 




https://www.i-techsupport.com/educational-tech/
