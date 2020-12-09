## STEP 1
```
sudo raspi-config
```
- 1 System option > S3 Change Password...
- 1 System option > S5 Auto login
- 1 System option > S1 Wireless lan

## systemctl example
```
sudo systemctl enable kiosk.service
sudo systemctl start kiosk.service
sudo systemctl status kiosk.service
sudo systemctl stop kiosk.service
sudo systemctl disable kiosk.service
```

## kiosk resolution
sudo raspi-config