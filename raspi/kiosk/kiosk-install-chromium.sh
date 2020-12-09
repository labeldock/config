#!/bin/sh
echo "Making sure everything is up to date..."
sudo apt-get update
sudo apt-get upgrade

echo "Installning necessary packages..."
sudo apt-get install xdotool unclutter -y
sudo apt-get install chromium-browser -y