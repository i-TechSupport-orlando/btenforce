# `btenforce` for macOS
Tested on macOS 13, 14, 15, and 26

Preventing students from disabling Bluetooth in an effort to thwart classroom monitoring tools is a challenge. You cannot force Bluetooth to be on with an MDM profile because it then prevents the end-user from connecting peripherals. Also, if Bluetooth is off at the time you install the profile, the end-user will be unable to turn it back on.

A very simple launch daemon runs a script that checks if Bluetooth is turned off.  If it's off, the script turns it back on. Setting the launch daemon to a 5 second interval seems to work the best. This is controlled with the `BTENFORCE_INTERVAL` variable in the config file.
 
### `blueutil` version
When macOS 26 was released, the latest versions of `blueutil` no longer worked with `btenforce`. This was due to a change in how the blueutil binary interacted with macOS. Version 2.9 seems to be less prone to error, so this version is included in the `btenforce` package. When `btenforce` is called, it checks whether `blueutil` exists in `/usr/local/bin/blueutil`. If it doesn't exist, it copies the binary to `/usr/local/bin/blueutil`. If it does exist, you can modify the post-install option `OVERWRITE_BLUEUTIL` to `true`. It will then back up the original `blueutil` and copy the 2.9 binary to `/usr/local/bin/blueutil`.

## Configuration variables and default values
See `btenforce.env`

## Daemon Status and Control
- Check Daemon:        `sudo launchctl list | grep itech` A positive result will show something similar to `-  0   com.itech.btenforce`. If `btenforce` is being ran it will show the PID instead of a `-`.
- Unload Daemon:       `sudo launchctl bootout system/com.itech.btenforce`
- Start Daemon:        `sudo launchctl bootstrap system /Library/LaunchDaemons/com.itech.btenforce.plist`

# Installing `btenforce`

## Manual Installation
1. Copy `btenforce` to `/usr/local/bin`
2. Copy `blueutil` to `/usr/local/bin`
3. Copy `com.itech.btenforce.plist` to `/Library/LaunchDaemons/com.itech.btenforce.plist`
4. Copy `btenforce.env` to `/Library/Application Support/i-Tech/btenforce`
5. Modify `btenforce.env` as needed.
6. Set ownership of the files to `root:wheel` and set permissions to prevent changes by students (`644`)
7. Run `sudo launchctl bootstrap system /Library/LaunchDaemons/com.itech.btenforce.plist`

## MDM Installation
1. Install `btenforce-pppc.mobileconfig` on the target devices
2. Upload `btenforce2.2.1.pkg` to your MDM or other distribution point
3. Upload `btenforce-postinstall.sh` to your MDM and configure the desired options
4. Create a policy to install `btenforce2.2.1.pkg` and run `btenforce-postinstall.sh` with the desired parameters.

# Dependencies
`blueutil` - https://github.com/toy/blueutil. The packaged release of `btenforce` contains `blueutil` version 2.9. `blueutil` was originally written by Frederik Seiffert <ego@frederikseiffert.de>. Copyright (c) 2011-2025 Ivan Kuchin.

# Safari Prevention
Most schools prefer students use Google Chrome due to the robust feature set designed spcificaly with schools in mind. The problem is macOS does not have an easy way to restrict its usage by end-users. `btenforce` effectively prevents Safari from being used because if the app is detected, it's killed. Hopefully Apple adds more robust web browser restrictions in a future version of macOS. 

Ensure that `btenforce` is installed after any workflows that require Safari such as before Chrome (or another browser) is installed. `btenforce` should not be enabled early in the enrollment process with `$SAFARI_CONTROL` set to `enforce`.

## Safari Control Methods
- osascript: This is the most accurate method as it will only alert to open Safari windows. This requires you to install the config profile `btenforce-pppc.mobileconfig`.
- pgrep:     If osascript isn't possible due to a prompting the students to approve it, or you cannot create a PPPC profile, this is a good alternative. It will have some false positives though. `pgrep` is the default method used. If `$SAFARI_CONTROL` is set to `allow`, `$SAFARI_CONTROL_METHOD` will be ignored.

## Jamf Pro Tip
Create a smart group with the criteria of 'Application title has Google Chrome.app' to group computers that have Chrome installed, then create a software restriction for process name `Safari` and check the box labeled 'kill process'. Then, scope the software restriction to the smart group. `btenforce` will then detect if Safari is open and kill it, so if the student found a way around the software restriction, it will still be prevented. It's also helpful to create an EA with a dropdown menu to override and allow Safari to run. The EA can be used to control which computers appear in the smart group.

## Mosyle Tip
Migrate to Jamf Pro ;-)

# Delete Login Items
`LOGIN_ITEM_CONTROL="enforce"` Deletes all user added login items. This prevents students from loading software when the machine boots. This is a tactic used by students on managed macOS devices to launch software that is restricted by Jamf Pro. There's a delay between when the Mac boots and when Jamf Pro's software restrictions take effect. Restricting login items prevents the students from launching software on the restricted list. If a student adds a login item, it is deleted by `btenforce` according to the `BTENFORCE_INTERVAL` that is set.

# Troubleshooting
- Bluetooth is not turning back on: Check that the current day & time is within the time window you set in the config file. Run `btenforce -debug` to test without time constraints. Another possible cause is that it's inside the time window but the daemon is not running. Use `sudo launchctl list | grep itech` to check if the daemon is running. If not, run `sudo launchctl bootstrap system /Library/LaunchDaemons/com.itech.btenforce.plist` to start it. 
- Another possible reason is that the PPPC profile is not installed or the `blueutil` binary is not in the correct location. If after it was installed the user clicked on "Don't Allow" for one of the prompts, you'll need to reinstall `btenforce`.
- If Bluetooth isn't turning back on during school hours, the other features may not be working either if you activated them. Check that `BTENFORCE_ACTIVE` is set to `true` in `/Library/Application Support/i-Tech/btenforce.env` or your custom env file location. Run `sudo launchctl bootout system/com.itech.btenforce` and `sudo launchctl bootstrap system /Library/LaunchDaemons/com.itech.btenforce.plist` to restart the daemon.
- View the logs in `/var/log/btenforce` or your custom log path.
- You may also obtain the log entries from the Unified Log with `log show --predicate 'eventMessage contains "btenforce"' --info --debug`.
- `btenforce -debug` will override the day of week and time of day restrictions and run the script as though school is always in session. 

# Setting Options
`btenforce` can be configured by using any of the following methods:
- You may modify the configuration on a single computer with `btenforce -configure`. This is convenient for testing.
- Manually by editing `/Library/Application Support/i-Tech/btenforce.env`.
- By running `btenforce-postinstall.sh` after installation.

# Configuration Profile
`btenforce` needs some PPPC permissions to function correctly. Install `btenforce-pppc.mobileconfig` to grant permissions to `blueutil` to modify Bluetooth and allow `osascript` to run. Once the profile is installed, the daemon should be able to run `blueutil` as the end-user. YMMV. It's a good idea to install `btenforce` at the end of the enrollment process so that you can click on "Allow" if prompted. `btenforce-pppc.mobileconfig` has been tested with macOS 26 and `blueutil` 2.9.1 and it effectively removes any end-user prompts for permissions.

---
Copyright (c) 2026 i-Tech Support Inc.
https://www.i-techsupport.com | info@i-techsupport.com