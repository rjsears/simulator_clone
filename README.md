# simulator_clone
Bash script to help automate clonezilla creation and restoration of simulator system images. It can be used to automate the creation and restoration of any images using clonezilla.

This script assumes that you have nfs-common and cloenzilla installed on your local system.

It is intended to be run on a Linux system (although others may work) and will auto detect if you are running X and if you have Zenity installed it will default to a Zenity user interface. If not, it will test for dialog and use it if it is installed and finally will default to text mode.

It was written on a Ubuntu 17 install.

This script is specifically written for our setup. Here is the basic flow:

1) Detects Zenity or Dialog, fails to text mode if neither exist
2) Checks to see if you are operating in Remote (nfs) mode or local (local filesystem) mode
3) Checks to make sure /home/partimag exists, if not it will offer to create it
4) In remote mode, checks to see if the correct nfs export is mounted, offers to mount it if it is not mounted
5) In create_image mode, asks for device that you want to image
6) VERY basic error checking of device to a) see if it exists (via dmesg) and b) make sure it is not your boot device
7) Creates and verifies images
8) In restore_mode, retreives a list of available images from nfs mount and allows you to select image
9) Again, VERY basic error checking to make sure you are not restoring to your boot device
10) Restores and verifies images

