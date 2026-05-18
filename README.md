# btenforce for macOS
Tested on macOS 13, 14, 15, and 26

blueutil must be installed first - https://github.com/toy/blueutil. The packaged release of btenforce contains blueutil.

Students love to turn Bluetooth off in an effort to thwart classroom monitoring tools. You cannot force Bluetooth to be on with an MDM profile because it then prevents the end-user from connecting peripherals. Also, if Bluetooth is off at the time you install the profile, the end-user will be unable to turn it back on.

A very simple launch daemon runs a script that checks if Bluetooth is turned off.  If it's off, the script turns it back on and sends info to make.com where it then sends an email to the student and the tech department. I have found that setting the launch daemon to ten seconds works the best. I originally had it set higher, but the students would continually turn it back off. Ten seconds seems to be too agravating for even the most determined students. 

## Version 2.1 Changes
- Abandoned the app bundle structure. The package installer places the main script in `/usr/local/bin/btenforce` and `blueutil` in `/usr/local/share/btenforce/blueutil`, and the daemon in `/Library/LaunchDaemons/com.itech.btenforce.plist`.
- `btenforce` is now a combination of the Bluetooth utility plus other functions such as Safari control and login item control. See the config file for more information.
- The included version of `blueutil` is version 9 due to some irregularities with newer versions on macOS 26.
- Removed ANSI color coding from log messages.
- Added logging to configuration function.
- Added comment indicating that the script is running as a standard user.
- Prevents reconfiguring by standard users.
- Cleaned up redundant login check.
- Added log retention period to the configuration options.
- Added function to append missing configuration variables to the config file.
- Added comprehensive configuration variable validation in post-install script.
- Corrected the installation function to check for the source files before copying them.
- Replaced deprecated `launchctl unload`/`bootstrap` with `bootout`/`bootstrap`.
- Added version to `blueutil` on install/update for logging.
- Added check for `blueutil` and then copy it from `/usr/local/share/btenforce/blueutil` if not found in `/usr/local/bin`.
- Added `MDM_TYPE` variable for clarity in config file.
- Added version to the log header in the config file for easy identification.
- Refined configuration function for usability and convenience. It will now check for configuration errors in the config file and report them to the user.
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

### Blueutil version
When macOS 26 was released, the latest versions of `blueutil` no longer worked. At the time, the version that is working well is version 2.9. I have included the version of blueutil in the package installer.

## Configuration variables and default values

Enable/disable the daemon (bool)
`BTENFORCE_ACTIVE="true"`

Fully qualified domain name (string)
`BTENFORCE_DOMAIN="yourdomain.org"`

Safari blocking option. 'enforce', 'allow' (string)
`SAFARI_CONTROL="allow"`

Safari blocking method. 'osascript', 'pgrep' (string)
`SAFARI_CONTROL_METHOD="pgrep"`

Bluetooth blocking option. 'enforce', 'allow' (string)
`BLUETOOTH_CONTROL="enforce"`

Login item control. 'enforce', 'allow' (string)
`LOGIN_ITEM_CONTROL="allow"`

School start time in 24-hour clock. Format: HH:MM (string)
`BTENFORCE_START_TIME="07:00"`

School stop time in 24-hour clock. Format: HH:MM (string)
`BTENFORCE_STOP_TIME="15:00"`

Log file path (string)
`BTENFORCE_LOG_FILE="/var/log/btenforce.log"`

Time constraint override. (bool)
`TIME_CONSTRAINT_OVERRIDE="false"`

Log retention in days (int) Range: 7-1095
`LOG_RETENTION="$LOG_RETENTION"`

## Safari may be blocked via two methods
- osascript: This is the most accurate method as it will only alert to open Safari windows.
- pgrep:     If osascript isn't possible due to a TCC restriction and you cannot create a PPPC profile, this is a good alternative. It will have some false positives. `pgrep` is the default method used. If `$SAFARI_CONTROL` is set to `allow`, `$SAFARI_CONTROL_METHOD` will be ignored.

## Delete Login Items
`LOGIN_ITEM_CONTROL="enforce"` Deletes all user added login items. This prevents the students from loading software when the machine boots.
This is a tactic used by students on managed macOS devices to launch software that is restricted by Jamf Pro. There's a delay between when the device boots and when Jamf Pro's software restrictions feature begins enforcing restricted software. Restricting login items prevents the students from launching software on the restricted list. If a student adds a login item, it is quickly deleted by `btenforce`.

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
5. Set ownership of the files to root and set permissions to prevent changes by students (644)
6. Run `sudo launchctl bootstrap system/Library/LaunchDaemons/com.itech.btenforce.plist`

## Jamf Pro Installation
1. Upload `btenforce.pkg` to Jamf Pro
2. Upload `btenforce-postinstall.sh` to Jamf Pro
3. Create a policy to install `btenforce.pkg` and then run `btenforce-postinstall.sh` with the desired parameters.

## Mosyle Installation
1. Distribute the package to the target macOS devices
2. Edit `btenforce-postinstall.sh` to comment out the Jamf Pro params and uncomment the Mosyle params
3. Create a Mosyle custom command to run `btenforce-postinstall.sh` and scope to the endpoints that have received the package

# Debugging
`btenforce --debug` will run the script in debug mode. Debug mode will override the day of week and time of day restrictions and run the script as though it is always in session. You may modify the configuration on a single computer with `btenforce --configure`. 


https://www.i-techsupport.com/educational-tech/
