#!/bin/sh

MOUNT_TARGET_DIR="/media/sda"

[ ! -d $MOUNT_TARGET_DIR ] && sudo mkdir $MOUNT_TARGET_DIR
sudo mount /dev/sda1 /media/sda

unset MOUNT_TARGET_DIR

exit 0
