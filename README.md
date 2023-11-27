# btenforce for macOS

Students love to turn Bluetooth off so that classroom tools are ineffective. You cannot force Bluetooth to be on via your MDM tools because it then prevents the user from connecting peripherals. Also, it’s possible that you will force Bluetooth off if it was off when the profile is installed.

A very simple launch daemon runs a script that checks if Bluetooth is turned off.  If it's off, the script turns it back on and sends info via json to make.com where it then sends an email to the student and the tech department. I have found that setting the launch daemon to ten seconds works the best. I originally had it set higher, but the students would actually continually turn it back off. Ten seconds seems to be too agravating for even the most determined students ;)
 
Copy the files to the following paths:

/Library/Scripts/BTEnforce.sh

/Library/LaunchDaemons/com.itech.btenforce.plist



Tested on macOS 13 & 14.

blueutil must be installed first - https://github.com/toy/blueutil

Keith Myers 9/7/2023 | https://www.i-techsupport.com/educational-tech/
