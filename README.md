# btenforce
Reactivates bluetooth automatically.
Checks if Bluetooh is turned on.  If it's off, turn it back on and send
info via json to make.com where it then sends an email to the student and the 
tech department. Use in conjuction with a launch daemon that runs every 10 seconds.
 
Place this script in: /Library/Scripts/BTEnforce.sh
The launch daemon should be placed in /Library/LaunchDaemons/com.itech.btenforce.plist

blueutil must be installed first - https://github.com/toy/blueutil

Keith Myers 9/7/2023 | https://www.i-techsupport.com/educational-tech/
