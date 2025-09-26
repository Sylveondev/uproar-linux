#!/bin/sh

# This is the text based interface for Uproar.

echo "(1/3) First thing first, Uproar needs to know where to install the system."
echo "      Warning: Uproar will erase the entire disk, so enter the correct disk."
sleep 3
echo "---
fdisk -l
echo "---
echo "Enter the disk to write to (For example: /dev/sda)"
read DISK
if [ -x DISK ]; then
  echo "Okay, Uproar will be installed to $DISK."
else
  echo "Disk does not exist in the file system."
  exit
fi
