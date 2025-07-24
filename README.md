# btenforce for macOS
Tested on macOS 13, 14, 15.5

blueutil must be installed first - https://github.com/toy/blueutil. The packaged release of btenforce contains blueutil.

Students love to turn Bluetooth off in an effort to thwart classroom monitoring tools. You cannot force Bluetooth to be on with an MDM profile because it then prevents the end-user from connecting peripherals. Also, if Bluetooth is off at the time you install the profile, the end-user will be unable to turn it back on.

A very simple launch daemon runs a script that checks if Bluetooth is turned off.  If it's off, the script turns it back on and sends info to make.com where it then sends an email to the student and the tech department. I have found that setting the launch daemon to ten seconds works the best. I originally had it set higher, but the students would continually turn it back off. Ten seconds seems to be too agravating for even the most determined students. Once they receive the emails and realize that their actions are being logged, they tend to stop trying.

## App Path
The application is installed to `/Applications/.i-Tech/BTEnforce.app`

## Options
The features are controlled via `/Library/Application Support/i-Tech/btenforce.env`

`BTENFORCE_ACTIVE="true"`  Change to 'false' to prevent the app from running completely.

`BLUETOOTH_CONTROL="enforce"`  Enable or disable Bluetooth control with "enforce" or "allow"

`BTENFORCE_START_TIME=07` Start enforcement at 07:00

`BTENFORCE_STOP_TIME=16`  Stop enforcement at 16:00

## Safari Browser Prevention
To force students to use the school's managed Chrome browser, you can enable Safari blocking by changing the config entry to 'enforce'

`SAFARI_CONTROL="allow"` Set to 'enforce' to restrict Safari. 

### Safari may be blocked via two methods
* osascript: This is the most accurate method as it will only alert to open Safari windows.
* pgrep:     If osascript isn't possible due to a TCC restriction and you cannot create a PPPC profile, this is a good alternative. It will have some false positives.

## Delete Login Items
`LOGIN_ITEM_CONTROL="enforce"`

Deletes all user added login items. This prevents the students from loading software when the machine boots.

## Check Daemon
`sudo launchctl | grep itech` A positive result will show something similar to `-  0   com.itech.btenforce`

## Unload Daemon
`sudo launchctl unload com.itech.btenforce`





Keith Myers 9/7/2023 | https://www.i-techsupport.com/educational-tech/
