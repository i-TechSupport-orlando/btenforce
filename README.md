# btenforce for macOS

Students love to turn Bluetooth off in an effort to thwart classroom monitoring tools. You cannot force Bluetooth to be on with an MDM profile because it then prevents the end-user from connecting peripherals. Also, if Bluetooth is off at the time you install the profile, the end-user will be unable to turn it back on.

A very simple launch daemon runs a script that checks if Bluetooth is turned off.  If it's off, the script turns it back on and sends info to make.com where it then sends an email to the student and the tech department. I have found that setting the launch daemon to ten seconds works the best. I originally had it set higher, but the students would continually turn it back off. Ten seconds seems to be too agravating for even the most determined students. Once they receive the emails and realize that their actions are being logged, they tend to stop trying.


The email component is handled by make.com via a webhook.
 
Copy the files to the following paths, then run restartDaemon.sh to turn it on, or restart the computer.

/Library/Scripts/BTEnforce.sh

/Library/LaunchDaemons/com.itech.btenforce.plist



Tested on macOS 13, 14, 15.5

blueutil must be installed first - https://github.com/toy/blueutil

Keith Myers 9/7/2023 | https://www.i-techsupport.com/educational-tech/
