#!/bin/bash
# disabled energy save
xset s noblank
xset s off
xset -dpms

# hide mouse
unclutter -idle 5 -root &

# for chromium
sed -i 's/"exited_cleanly":false/"exited_cleanly":true/' /home/pi/.config/chromium/Default/Preferences
sed -i 's/"exit_type":"Crashed"/"exit_type":"Normal"/' /home/pi/.config/chromium/Default/Preferences

# other
# yarn start

# chromium
/usr/bin/chromium-browser --noerrdialogs --disable-infobars --remote-debugging-port=9222 --kiosk localhost:80