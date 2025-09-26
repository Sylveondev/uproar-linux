#!/bin/sh

# This is the text based interface for Uproar.

echo "(1/3) First thing first, Uproar needs to know where to install the system.
Warning: Uproar will erase the entire disk, so enter the correct disk."
sleep 3
echo "---"
fdisk -l
echo "---
Enter the disk to write to (For example: sda, mmcblk0)"
read DISK
if [ -n /dev/$DISK ]; then
  echo "Okay, Uproar will be installed to $DISK."
else
  echo "Disk does not exist in the file system."
  exit
fi
echo "---"
if [ -d "/sys/firmware/efi" ]; then
    echo "The system is running in UEFI mode, so the disk will be created in the GPT format."
    sleep 2
    echo "Partitioning with fdisk..."
    echo -e "g\nn\n1\n\n+1G\nn\n2\n\n\nw" | fdisk /dev/$DISK
    echo "Partitioning is complete."
else
    echo "The system is running in BIOS (Legacy) mode, so the disk will be created in the MBR format."
    sleep 2
    echo "Partitioning with fdisk..."
    echo -e "o\nn\n1\n\n+1G\nn\n2\n\n\nw" | fdisk /dev/$DISK
    echo "Partitioning is complete."
fi

echo "---
(2/3) Next step, lets set up your user. Enter your username."
