#! /bin/bash

#######################################################################
## Richard J. Sears
## richard@sears.net
##
## simulator_clone.sh
##
## V1.01
## September 9th, 2017
##
## This is a bash script to help automate the creation and restoration
## of images to and from SSD/HDDs for our CJ simulator. It is intended
## to be run on a bash enabled linux system with nfs capabilities and 
## clonezilla installed.
##
##		REQUIREMENTS
##  nfs-common
##  clonezilla
##  partimage
##  partclone
##
##  All software needs to the the LATEST version otherwise you will get
##  errors with this script due to some additional flags and capabilities
##  added in newer versions.
####################################################################### 
##
## 9/9/17
## Added checks for more software. It seems some distributions
## do not install all of the required programs (partimage & Parted)
## when they install clonezilla (apt install clonezilla).
##
## Streamlined dialogs
##
#######################################################################

## Make necessary changes here:

## Are we going to save our images locally or remotely?
## Enter "remote" or "local"
## "local" will cause the script to bypass checking to see if the nfs mount point exists
operation="remote" 

## If remote, what server are we going to save to and get images from?
## This should be a FQDN or if it is not, then you should have a host
## entry. A normal IP address is fine as well.
nfs_server="plexnas"




## You should not have to change anything else from here down....


# Define some colors
red='\033[0;31m'
yellow='\033[0;33m'
green='\033[0;32m'
white='\033[0;37m'
blue='\033[0;34m'
nc='\033[0m'

how_called=$1
now=$(date +%y%m%d%H%M%S)

## Warning banner for use in text mode

warning_banner () {
echo
echo -e "${red}
 **       **           **           *******         ****     **       **       ****     **         ******** 
/**      /**          ****         /**////**       /**/**   /**      /**      /**/**   /**        **//////**
/**   *  /**         **//**        /**   /**       /**//**  /**      /**      /**//**  /**       **      // 
/**  *** /**        **  //**       /*******        /** //** /**      /**      /** //** /**      /**         
/** **/**/**       **********      /**///**        /**  //**/**      /**      /**  //**/**      /**    *****
/**** //****      /**//////**      /**  //**       /**   //****      /**      /**   //****      //**  ////**
/**/   ///**      /**     /**      /**   //**      /**    //***      /**      /**    //***       //******** 
//       //       //      //       //     //       //      ///       //       //      ///         ////////  
${nc}"
}
                                                                                                           

# The awesome LOFT Logo....

loft_logo () {
echo
echo -e "${red} **               *******         ********       **********
/**              **/////**       /**/////       /////**/// 
/**             **     //**      /**                /** ${white}   
/**            /**      /**      /*******           /**    
/**            /**      /**      /**////            /**    
/**            //**     **       /**                /** ${blue}   
/********       //*******        /**                /**    
////////         ///////         //                 //     
${nc}"
}


## Here we deterime if we are running X and if we have Zenity installed.
## If we do, then zenity becomes our default display, if not then we check
## to see if dialog is installed and use it, otherwise fall back to text
## output.

determine_display () {
	if [ -x "$(command -v zzenity)" ] && [ $DISPLAY ]; then
	display="zenity"
	else
		if [ -x "$(command -v ddialog)" ]; then
		display="dialog"
		else
			display=""
		fi
	fi
}


## Is clonezilla installed locally? IF not, let them know that
## we need it and exit the script.

is_clonezilla_installed () {
	if ! [ -x "$(command -v clonezilla)" ] ||
        !       [ -x "$(command -v partclone.dd)" ] ||
        !       [ -x "$(command -v partclone.vfat)" ] ||
        !       [ -x "$(command -v partclone.ntfs)" ] ||
        !       [ -x "$(command -v partclone.restore)" ] ||
        !       [ -x "$(command -v partimage)" ]; then
		if [ "$display" == "dialog" ]; then	
		dialog	--clear \
			--backtitle "SOFTWARE INSTALLATION ERROR" \
			--title "Is all required software installed...?" \
			--ok-label "EXIT" \
			--msgbox "\nSpecific software is required for this script to run. \
			\n\nPlease check the requirements and rerun this script! \
			\n\n\n\nIf you are running Ubuntu try:\n\napt install clonezilla; apt install partimage; apt install partclone" \
			15 80 		
			clear
		else
			if [ "$display" == "zenity" ]; then
			zenity --no-wrap --warning --text="<span size=\"xx-large\"> \
Software Installation Error!</span>\n\n\
Please check software requirements and run this script again.\n\n\n\
If you are running Ubuntu try: \n\n<b>apt install clonezilla; apt install partimage; apt install partclone</b>." \
--title="Software Error" --ok-label="QUIT" 2>/dev/null			
			exit 1
			fi	
		clear
		echo
		echo -e "${red}ERROR${nc} - Required software does not appear to be installed!." >&2
		echo "Please install clonezilla, partimage & partclone locally and rerun script."
		echo
		echo -e "${yellow}ABORTING!${nc}"
		echo
		echo
		exit 1
		fi
	exit 1
	fi
}


## Which simulator will we be working with today?

select_simulator () {
	if [ "$display" == "zenity" ]; then	
		simulator_selected=`cat simulator_list | \
                awk '{print "\n"$0}' | \
         	zenity --list --radiolist --width=500 --height=200 --separator='\n' --title="Available Simulators" \
                --text="Select Simulator to Utilize" --column="" --column="Simulators" 2>/dev/null`
		
		exitstatus=$?		
		if [ $exitstatus = 0 ]; then
			if [ -z "$simulator_selected" ]; then
        			select_simulator
			else
			zenity --question --title="Verify Simulator" --text="You entered [ $simulator_selected ], is this correct?" 2>/dev/null
			if [ $? = 0 ]; then
				echo
			else
			select_simulator
			fi

		fi	
		else
			exit 1
		fi
	else
		if [ "$display" == "dialog" ]; then
			rm .simtempfile
			COUNTER=1
			SIMULATOR=""
			while read i; do 
				SIMULATOR="$SIMULATOR $i $i off "
    				let COUNTER=COUNTER+1
			done < simulator_list

			dialog --no-tags --backtitle "Select Simulator" \
			--radiolist "Select which Simulator you are working on:" 9 50 $COUNTER \
			$SIMULATOR 2> .simtempfile 

			exitstatus=$?			
			simulator_selected=`cat .simtempfile`
			if [ $exitstatus == 0 ]; then
				if [ -z "$simulator_selected" ]; then
				select_simulator
			else
				dialog --clear --backtitle "Verify Simulator" --title "Verify Simulator" \
				--yesno "You entered [ $simulator_selected ], is this correct? \n" 5 50
				if [ $? = 0 ]; then
					echo
				else
					select_simulator	
				fi
			fi
	else
		exit 1
	fi
	
	else
		echo
		echo
		echo -e "These are the ${yellow}available${nc} Simulators:"
		nl simulator_list 
		count="$(wc -l simulator_list | cut -f 1 -d' ')"
		n=""
		while true; do
    			echo
    			read -p 'Please Select Simulator: ' n
    			if [ "$n" -eq "$n" ] && [ "$n" -gt 0 ] && [ "$n" -le "$count" ]; then
  			      	break
    			fi
		done
		simulator_selected="$(sed -n "${n}p" simulator_list)"
		echo
		echo -e -n "You selected ${yellow}$simulator_selected${nc}. Is this ${yellow}CORRECT${nc}? "
		read -n 1 -r
       		echo
       		if [[ $REPLY =~ ^[Yy]$ ]]
        	then
                	echo -e "Simulator set to ${blue}$simulator_selected${nc}"
        	else
                select_simulator
        	fi
	fi
fi

}


## We need nfs.common installed in order to mount the nfs export where we store our images.
## If nfs.common is not installed, error and quit.

is_nfs_installed () {
	if ! [ -x "$(command -v mount.nfs)" ]; then
		if [ "$display" == "dialog" ]; then	
		dialog	--clear \
			--backtitle "NFS ERROR" \
			--title "Is NFS installed...?" \
			--ok-label "EXIT" \
			--msgbox "\nNFS Common is required for this script to run. \
			\n\nPlease install nfs-common and rerun this script! \
			\n\nIf you are running Ubuntu try: apt install nfs-common" \
			13 70 		
			clear
		else
			if [ "$display" == "zenity" ]; then
			zenity --no-wrap --warning --text="<span size=\"xx-large\"> \
NFS Installation Error!</span>\n\n\
Please install nfs-common and run this script again.\n\n\n\
If you are running Ubuntu try: \n\n<b>apt install nfs-common</b>." \
--title="Clonezilla Error" --ok-label="QUIT" 2>/dev/null			
			exit 1
			fi	
		clear
		echo
		echo -e "${red}ERROR${nc} - NFS does not appear to be installed!." >&2
		echo "Please install nfs-common and rerun script."
		echo
		echo -e "If you are running Ubuntu try: i${yellow}apt install nfs-common${nc}"
		echo
		echo -e "${yellow}ABORTING!${nc}"
		echo
		echo
		exit 1
		fi
	exit 1
	fi
}

## Does the /home/partimag directory exist?

does_directory_exist () {
	if [ ! -d /home/partimag ]; then
		if [ "$display" == "dialog" ]; then	
			dialog --colors --clear --yes-label "CREATE DIRECTORY" --no-label "CANCEL & QUIT" --backtitle "DIRECTORY ERROR!" \
			--title "\Z1*** DIRECTORY ERROR ***\Zn" --yesno "\nThis script requires that the directory /home/partimag\
already be created.\n\n Would you like us to attempt to create the directory for you?" 10 100 2>/dev/null 				

			if [ $? = 0 ]; then
				mkdir /home/partimag
				if [ ! -d /home/partimag ]; then
					echo "Directory Creation Failed, please create manaually and rerun script"
					exit 1
				fi
			else
				exit 1
			fi

		else
                        if [ "$display" == "zenity" ]; then
                        zenity --no-wrap --question --text="<span size=\"xx-large\"> \
/home/partimag does not exist!</span>\n\n\n\
This script requires that the /home/partimag directory already be created.\
\n\nWould you like us to attempt to create the directory for you?" \
--title="Directory Error !!" --cancel-label="CANCEL & QUIT" --ok-label="CREATE DIRECTORY" 2>/dev/null
			
				if [ $? = 0 ]; then
					mkdir /home/partimag
					if [ ! -d /home/partimag ]; then
						echo "Directory Creation Failed, please create manaually and rerun script"
						exit 1
					fi
				else
					exit 1
				fi
                else
		echo
                echo -e "${red}DIRECTORY ERROR${nc} - /home/partimag does not appear to exist!." >&2
		echo
		echo -e "This script requires that the directory /home/partimag exist."
                echo
		echo -e -n "Would you like us to attempt to create the directory for you? "
		read -n 1 -r
		if [[ $REPLY =~ ^[Yy]$ ]]; then
			mkdir /home/partimag
			if [ ! -d /home/partimag ]; then
				echo "Directory Creation Failed, please create manaually and rerun script"
				exit 1
			fi
		else
			clear
			echo -e "${yellow}ABORTING!!${nc}"
			exit 1
		fi
	fi
fi			
fi
}


## Is /home/partimag mounted at the correct location? In order for clonezilla to
## work correctly and not pitch a fit, it writes to /home/partimag
## In our case, this is a mount point on our primary FreeNAS server where we store
## all of our images. If it is not mounted correctly, we cannot continue.
## You can set the "Operation" flag above to "local" to bypass this check 

is_partimag_mounted () {
	if [ $(mount | grep $nfs_server:/mnt/vol1/loft_sim_images/$simulator_selected | grep -c /home/partimag) != 1 ]; then
		if [ "$display" == "dialog" ]; then	
			dialog --colors --clear --yes-label "ATTEMPT MOUNT" --no-label "CANCEL & QUIT" --backtitle "MOUNT ERROR!" \
			--title "\Z1*** MOUNT ERROR ***\Zn" --yesno "\nThis script requires that the directory /home/partimag\n\
already be created and that it be mounted to: 
	\Z1$nfs_server:/mnt/vol1/loft_sim_images/$simulator_selected\Zn \n\n\n \
Would you like us to attempt to mount the correct export for you?" 10 100 2>/dev/null 				

			if [ $? = 0 ]; then
				/bin/umount /home/partimag
				/bin/mount -t nfs $nfs_server:/mnt/vol1/loft_sim_images/$simulator_selected /home/partimag
				if [ $? != 0 ]; then
					echo "Mount Failed, please mount manaually and rerun script"
					exit 1
				fi
			else
				exit 1
			fi

		else
                        if [ "$display" == "zenity" ]; then
                        zenity --no-wrap --question --text="<span size=\"xx-large\"> \
/home/partimag is not mounted properly!</span>\n\n\n\
This script requires that the /home/partimag directory already be created
and that it be mounted to:\n\n<b> $nfs_server:/mnt/vol1/loft_sim_images/$simulator_selected</b>.\n\n\
Would you like us to attempt to mount the correct export for you?" \
--title="Mount Error !!" --cancel-label="CANCEL & QUIT" --ok-label="ATTEMPT MOUNT" 2>/dev/null
			
				if [ $? = 0 ]; then
					/bin/umount /home/partimag
					/bin/mount -t nfs $nfs_server:/mnt/vol1/loft_sim_images/$simulator_selected /home/partimag
					if [ $? != 0 ]; then
						echo "Mount Failed, please mount manaually and rerun script"
						exit 1
					fi
				else
					exit 1
				fi
                else
		echo
                echo -e "${red}MOUNT ERROR${nc} - /home/partimag does not appear to be mounted correctly!." >&2
		echo
		echo -e "This script requires that /home/partimag be mounted to: $nfs_server:/mnt/vol1/loft_sim_images/$simulator_selected"
                echo
		echo -e -n "Would you like us to attempt to mount the correct export for you? "
		read -n 1 -r
		if [[ $REPLY =~ ^[Yy]$ ]]; then
			/bin/umount /home/partimag 2>/dev/null
			/bin/mount -t nfs $nfs_server:/mnt/vol1/loft_sim_images/$simulator_selected /home/partimag
			if [ $? != 0 ]; then
				echo "Mount Failed, please mount manaually and rerun script"
				echo -e "${white}mount -t nfs $nfs_server:/mnt/vol1/loft_sim_images/$simulator_selected /home/partimag${nc}"
				exit 1
			fi
		else
			clear
			echo -e "${yellow}ABORTING!!${nc}"
			exit 1
		fi
	fi
fi			
fi
}


## Once a device is entered into the script we do a little error checking. Here
## we are checking to see if the device actually exists on the system as seen via
## dmesg. Chances are, if dmesg does not see it, it is not the correct device.

check_device_available () {
	if [ $(dmesg | grep -c $userDEV) = 0 ]; then
		if [ "$display" == "dialog" ]; then	
		dialog	--clear \
			--colors \
			--backtitle "DEVICE ERROR!" \
			--title "** DEVICE ERROR **" \
			--ok-label "EXIT" \
			--msgbox "\n/dev/$userDEV does not appear to be valid or available on this system! \
			\n\n\n\nOnce this script exits, please rerun \Zb\Z1 dmesg \Zn from the command line and\ncheck your device selection!" \
			20 80 		
			clear
			exit 1
		else
                        if [ "$display" == "zenity" ]; then
                        zenity --no-wrap --warning --text="<span size=\"xx-large\"> \
/dev/$userDEV is not valid!</span>\n\n\n\
/dev/$userDEV does not appear to be valid or available on this system!\n\n
Once this script exits, run <b>dmesg</b> from the command line\nand check your device selection." \
--title="Device Error !!" --ok-label="QUIT" 2>/dev/null
                        exit 1
                        fi
                clear
                echo
		echo
		echo -e "${red}ERROR${nc} - /dev/$userDEV does not appear to be valid or available on this system"
		echo -e "Please rerun ${white}dmesg${nc} from the command line and check your device selection."
		echo
		exit 1
		fi
fi
}

## OK, again some basic error checking. Here we are seeing if the device that was entered is
## listed via the mount command as either mount at / or at /boot. In either case, that is bad
## since it suggests that the person is getting ready to attempt to clone a live filesystem ro
## even worse, write over their local hard drive. If they want to close their internal local
## hard drive, they should do so via a clonezilla live CD/USB, and not while the filesystem is
## mounted and running. Again, we can't do much here but tell them the error and stop the script.

check_device_ifbootdevice () {
	if [ $(mount | grep $userDEV | grep -c boot) != 0 ] || [ $(mount | grep $userDEV | egrep -c '\s/\s') != 0 ]; then
		if [ "$display" == "zenity" ]; then
			zenity --warning --no-wrap --text="The device that you have selected appears to be your BOOT device!\n\n \
Please <b>VERIFY</b> your device and try again!" 2>/dev/null
			exit 1
		else
			if [ "$display" == "dialog" ]; then
				dialog --backtitle "WARNING" --title "WARNING - Possible Boot Device" \
				--msgbox "\nThe device that you have selected appears to be your BOOT device!\n\n\
				Please VERIFY your device and try again!" 10 60
				exit 1
		else	
	echo
	clear
	warning_banner
	echo
	echo -e "${red}WARNING${yellow} * * * ${red}WARNING${yellow} * * * ${red}WARNING${nc}"
	echo
	echo
	echo -e "The device you have selected [${yellow}/dev/$userDEV${nc}] appears to be your BOOT device!"
	echo -e "Please ${white}VERIFY${nc} your device and try again!"
	echo
	exit 1
			fi
		fi
	fi
} 



## Ask the user for the device we will be using for the cloning or restore operation.

get_device () {
	if [ "$display" == "zenity" ]; then
	userDEV=$(zenity --title="Device Entry" --entry --text "Please input the SDD or HDD device to use. \nFor example: sda sdb sdc:" 2>/dev/null)

			if test $? -eq 0; then			
				if [ -z "$userDEV" ]; then
					get_device
				fi
			else
				exit 1
			fi

	zenity --question --title="Verify Device Entry" --text="You entered [ $userDEV ], is this correct?" 2>/dev/null
		if [ $? = 0 ]; then
			check_device_available
			check_device_ifbootdevice
		else
			get_device
		fi
	else
		if [ "$display" == "dialog" ]; then
			exec 3>&1;
			userDEV=$(dialog --clear \
			--backtitle "Enter Device Name" \
			--title "Enter Device Name" \
			--inputbox "\nPlease input the SDD or HDD device to use.\nFor example: sda  sdb  sdc:" \
			10 50 2>&1 1>&3);

			if test $? -eq 0; then			
				if [ -z "$userDEV" ]; then
					get_device
				fi
			else
				exit 1
			fi
				
			dialog --clear --backtitle "Verify Device Entry" --title "Verify Device Entry" \
			--yesno "You entered [ $userDEV ], is this correct?" 5 50
				if [ $? = 0 ]; then
				check_device_available
				check_device_ifbootdevice
				else
					get_device
				fi
	else
	echo
	echo
	echo -e -n "Please input the SDD or HDD device to use. For example: sda sdb sdc: "
	read userDEV
	echo
	echo -e -n "You entered [${blue}$userDEV${nc}], is this correct? "
	read -n 1 -r
        	echo
		if [[ $REPLY =~ ^[Yy]$ ]]
		then
			check_device_available
			check_device_ifbootdevice
		else
			get_device
		fi
	fi
fi
}

## If we are cloning a disk, ask the user for the image name. We will add a date/time
## string as well as a .img ending to the name they provide.

get_image_name () {
	if [ "$display" == "zenity" ]; then
	imageNAME=$(zenity --title="Get Image Name" --entry --text "What would you like to name your image?" 2>/dev/null)

			if test $? -eq 0; then			
				if [ -z "$imageNAME" ]; then
					get_image_name
				fi
			else
				exit 1
			fi

	zenity --question --title="Verify Image Name" --text="You entered [ $imageNAME.$now.img ], is this correct?" 2>/dev/null
		if [ $? = 0 ]; then
			echo
		else
			get_image_name
		fi
	else
		if [ "$display" == "dialog" ]; then
			exec 3>&1;
			imageNAME=$(dialog --clear \
			--backtitle "Enter Image Name" \
			--title "Enter Device Name" \
			--inputbox "\nWhat would you like to name your image?" \
			10 50 2>&1 1>&3);

			if [ $? = 0 ]; then
				if [ -z "$imageNAME" ]; then
					get_image_name
				fi
			else
				exit 1
			fi
				
			dialog --clear --backtitle "Verify Image Name" --title "Verify Image Name" \
			--yesno "You entered [ $imageNAME.$now.img ], is this correct?" 5 80
				if [ $? = 0 ]; then
					echo
				else
					get_image_name
				fi
	else
	echo
	echo -e -n "What would you like to name your image? "
	read imageNAME
	echo
	echo -e -n "You entered [${blue}$imageNAME.$now.img${nc}], is this correct? "
	read -n 1 -r
        	echo
		if [[ $REPLY =~ ^[Yy]$ ]]
		then
			echo
		else
			get_image_name
		fi
	fi
fi
}


## Verification of the entered information one more time.

print_inputs_clone () {
	if [ "$display" == "zenity" ]; then
	zenity --question --title="We are CREATING a new image! Please Verify Inputs" \
	--text="Is this information correct:\n\n\n
		Source Device:		<b>/dev/$userDEV</b> \n\
		Image Name:		<b>$imageNAME.$now.img</b>" 2>/dev/null
		if [ $? = 0 ]; then
			echo ""
		else
			$how_called
		fi
	else
		if [ "$display" == "dialog" ]; then	
		dialog --colors --clear --backtitle "We are CREATING a new image! Please Verify Inputs" \
		--title "\Z1We are CREATING a new image! Please Verify Inputs\Zn" \
		--yesno "\nIs this correct:\n\n\n
			Source Device:			/dev/$userDEV\n
			Image Name:		$imageNAME.$now.img" 10 60 
			
			if [ $? == 0 ]; then
				echo ""
			else
				$how_called
			fi
		else	

		echo
		echo
		echo -e "Source Device:		${yellow}/dev/$userDEV${nc}"
		echo -e "Image Name:		${yellow}$imageNAME.$now.img${nc}"
		echo
		echo -e -n "Is this ${yellow}CORRECT${nc}? "
		read -n 1 -r
		echo
			if [[ $REPLY =~ ^[Yy]$ ]]; then
				echo ""
			else
				$how_called
			fi
		fi
	fi
}


## Verification of the entered information one more time.

print_inputs_restore () {
	if [ "$display" == "zenity" ]; then
	zenity --question --title="We are RESTORING an image! Please Verify Inputs" \
	--text="Is this information correct:\n\n\n
		Restore to:		<b>/dev/$userDEV</b> \n\
		Image Name:		<b>$image_selected</b>" 2>/dev/null
		if [ $? = 0 ]; then
			echo ""
		else
			$how_called
		fi
	else
		if [ "$display" == "dialog" ]; then	
		dialog --colors --clear --backtitle "We are RESTORING an image! Please Verify Inputs" \
		--title "\Z1We are RESTORING an image! Please Verify Inputs\Zn" \
		--yesno "\nIs this correct:\n\n\n
			Restore to:			/dev/$userDEV\n
			Image Name:		$image_selected" 10 60 
			if [ $? = 0 ]; then
				echo ""
		else
			$how_called
		fi
	else	

		echo
		echo
		echo -e "Restore to:		${yellow}/dev/$userDEV${nc}"
		echo -e "Image Name:		${yellow}$imageNAME.$now.img${nc}"
		echo
		echo -e -n "Is this ${yellow}CORRECT${nc}? "
		read -n 1 -r
		echo
			if [[ $REPLY =~ ^[Yy]$ ]]; then
				echo ""
			else
				$how_called
			fi
		fi
	fi
}


## Check to see if the device they want to use is mounted. If it is,
## unmount it prior to use.

check_dev_mounted () {
echo
echo
if [ $(mount | grep -c $userDEV) = 1 ]; then
        echo -e "${red}ERROR${nc} - /dev/$userDEV appears to be mounted! - UNMOUNTING" >&2
	umount /dev/$userDEV*
	echo
        fi
}


## Here we get a list of available images on our FreeNAS server for using during the
## restore process. I am sure there is a better way to do this, but this works well
## and presents the user with a list of available images for them to choose from 
## during the resore process. 

available_images_list () {
	if [ "$display" == "zenity" ]; then	
		image_selected=`find /home/partimag -name "*.img" -type d | cut -b 16- 2>/dev/null | \
                awk '{print "\n"$0}' | \
         	zenity --list --radiolist --width=500 --height=500 --separator='\n' --title="Available Images" \
                --text="Select Image To Restore" --column="" --column="Images" 2>/dev/null`
		
		if [ -z "$image_selected" ]; then
        		available_images_list	
		fi
	else
		if [ "$display" == "dialog" ]; then
			cp /dev/null .clone_images_list
			ls -1 /home/partimag | grep img >> .clone_images_list
			COUNTER=1
			IMAGELIST=""
			while read i; do 
    				IMAGELIST="$IMAGELIST $i $i off "
    				let COUNTER=COUNTER+1
			done < .clone_images_list

			dialog --no-tags --backtitle "Available Image List" \
			--radiolist "Select Image to Restore" 0 0 $COUNTER \
			$IMAGELIST 2> .tempfile 

			image_selected=`cat .tempfile`

			exitstatus=$?			
			if [ $exitstatus = 0 ]; then
				echo "You choose $image_selected"
			else
				exit 1
			fi
	else

		echo
		echo
		echo -e "These are the ${yellow}available${nc} $simulator_selected Images:"
		cp /dev/null .clone_images_list
		ls -1 /home/partimag | grep img >> .clone_images_list
		nl .clone_images_list 
		count="$(wc -l .clone_images_list | cut -f 1 -d' ')"
		n=""
		while true; do
    			echo
    			read -p 'Please Select image: ' n
    			if [ "$n" -eq "$n" ] && [ "$n" -gt 0 ] && [ "$n" -le "$count" ]; then
  			      	break
    			fi
		done
		image_selected="$(sed -n "${n}p" .clone_images_list)"
		echo
		echo -e -n "You selected ${yellow}$image_selected${nc}. Is this ${yellow}CORRECT${nc}? "
		read -n 1 -r
       		echo
       		if [[ $REPLY =~ ^[Yy]$ ]]
        	then
                	echo -e "Image requested set to ${blue}$image_selected${nc}"
        	else
                available_images_list
        	fi
	fi
fi

}


## Function to launch clonezilla and create a new image. 

start_create_image () {
	if [ "$display" == "zenity" ]; then
	check_dev_mounted
	zenity --question --title="Time to Create our Image" \
	--ok-label="CREATE IMAGE" --cancel-label="CANCEL & QUIT" \
	--text="Command to use in the future: \n\n \
		<b>/usr/sbin/ocs-sr -q2 -j2 -z1p -i 4096 -p choose savedisk $imageNAME.$now.img $userDEV</b>\n\n\n \
                This will take some time since we are going to <b>VERIFY</b> the image after creation. \n\n\n \
		Press CREATE IMAGE to begin....."  2>/dev/null 
		if [ $? = 0 ]; then
			/usr/sbin/ocs-sr -q2 -j2 -z1p -i 4096 -p choose savedisk $imageNAME.$now.img $userDEV
		else
			exit 1	
		fi
	else
		if [ "$display" == "dialog" ]; then	
		dialog --colors --clear --yes-label "CREATE IMAGE" --no-label "CANCEL & QUIT" --backtitle "Time to Create our Image" \
                --title "\Z1Time to Create our Image\Zn" \
                --yesno "\nCommand to use in the future: \n\n \
                /usr/sbin/ocs-sr -q2 -j2 -z1p -i 4096 -p choose savedisk $imageNAME.$now.img $userDEV\n\n\n \
                This will take some time since we are going to VERIFY the image after creation. \n\n\n \
                Press CREATE IMAGE to begin....." 20 120 2>/dev/null
			if [ $? = 0 ]; then
				/usr/sbin/ocs-sr -q2 -j2 -z1p -i 4096 -p choose savedisk $imageNAME.$now.img $userDEV
		else
			exit 1
		fi


	else
echo
echo
check_dev_mounted
echo -e "Command to use next time: /usr/sbin/ocs-sr -q2 -j2 -z1p -i 4096 -p choose savedisk $imageNAME.$now.img $userDEV" 
echo -e "${white}IMPORTANT${nc} - This will take some time since we are going to ${yellow}verify${nc} the image once complete!"
echo
read -n 1 -s -r -p "Press any key to begin...."
/usr/sbin/ocs-sr -q2 -j2 -z1p -i 4096 -p choose savedisk $imageNAME.$now.img $userDEV 
fi

fi
}



## Function to launch clonezilla and restore an image.

start_restore_image () {
	if [ "$display" == "zenity" ]; then
	check_dev_mounted
	zenity --question --title="Time to RESTORE our Image" \
	--ok-label="RESTORE IMAGE" --cancel-label="CANCEL & QUIT" \
	--text="Command to use in the future: \n\n \
		<b>/usr/sbin/ocs-sr -g auto -e1 auto -icds -e2 -r -j2 -scr -p choose restoredisk $image_selected $userDEV</b>\n\n\n \
                This will take some time since we are going to <b>VERIFY</b> the image after we restore it. \n\n\n \
		Press RESTORE IMAGE to begin....."  2>/dev/null 
		if [ $? = 0 ]; then
			/usr/sbin/ocs-sr -g auto -e1 auto -icds -e2 -r -j2 -scr -p choose restoredisk $image_selected $userDEV
		else
			exit 1	
		fi
	else
		if [ "$display" == "dialog" ]; then	
		dialog --colors --clear --yes-label "RESTORE IMAGE" --no-label "CANCEL & QUIT" --backtitle "Time to RESTORE our Image" \
                --title "\Z1Time to Restore our Image\Zn" \
                --yesno "\nCommand to use in the future: \n\n\
		/usr/sbin/ocs-sr -g auto -e1 auto -icds -e2 -r -j2 -scr -p choose restoredisk $image_selected $userDEV\n\n\n \
		This will take some time since we are going to VERIFY the image after we restore it. \n\n\n \
		Press RESTORE IMAGE to begin....." 20 120 2>/dev/null
			if [ $? = 0 ]; then
				/usr/sbin/ocs-sr -g auto -e1 auto -icds -e2 -r -j2 -scr -p choose restoredisk $image_selected $userDEV
		else
			exit 1
		fi


	else
echo
echo
check_dev_mounted
echo -e "Command to use next time: /usr/sbin/ocs-sr -g auto -e1 auto -icds -e2 -r -j2 -scr -p choose restoredisk $image_selected $userDEV"
echo -e "${white}IMPORTANT${nc} - This will take some time since we are going to ${yellow}verify${nc} the image after we have restored it!"
echo
read -n 1 -s -r -p "Press any key to begin...."
/usr/sbin/ocs-sr -g auto -e1 auto -icds -e2 -r -j2 -scr -p choose restoredisk $image_selected $userDEV
fi

fi
}



## Initial function called with the script. Process starts here to create a new image.

create_image () {
determine_display
clear
loft_logo
echo
echo -e "We are going to ${yellow}CREATE${nc} an image from an EXISTING SSD or HDD!"
echo
is_clonezilla_installed
does_directory_exist
select_simulator
if [ "$operation" == "remote" ]; then
	is_partimag_mounted
fi
get_device
get_image_name
print_inputs_clone
start_create_image
}


## Initial function called with the script. Process starts here to restore an image.

restore_image () {
determine_display
clear
loft_logo
echo
echo -e "We are going to ${yellow}RESTORE${nc} an image to an SSD or HDD!"
echo
is_clonezilla_installed
does_directory_exist
select_simulator
if [ "$operation" == "remote" ]; then
	is_partimag_mounted
fi
available_images_list
get_device
print_inputs_restore
start_restore_image
}


## Help Information 

help () {
clear
loft_logo
echo
echo
echo "This script is designed to make an image of a hard drive"
echo "or to take a stored image and place it back onto a hard"
echo "drive or SSD drive."
echo
echo "All images are stored on plexnas at /mnt/vol1/loft_sim_images/CE525"
echo
echo "There are several prerequisites to using this script:"
echo -e "     1) Clonezilla ${yellow}must${nc} be installed on your local system."
echo -e "     2) You ${yellow}must${nc} have nfs mounted /mnt/vol1/loft_sim_images/CE525 at /home/partimag"
echo -e "     3) You ${yellow}must${nc} know the dev of the drive you are cloning or sending an image"
echo -e "     4) There ${yellow}must${nc} be a host entry for plexnas pointing to 10.200.50.3"
echo -e "     5) This system ${yellow}must${nc} be on an IP address allowed to nfs mount plexnas:/mnt/vol1/loft_sim_images/CE525"
echo
echo "If any of these prerequisitres are not met, this script will not work for you."
echo
echo "If you do not know the dev of the SSD or HDD you are going to be using, the"
echo "best way to determine it is to place the drive in the dock and then run dmesg."
echo "Look for the last device shown in dmesg, it should look something like this:"
echo
echo -e ${yellow}
echo -e "[ 4612.512815] scsi 3:0:0:0: Direct-Access     ${white}Samsung  SSD 850 PRO 256G${yellow} 0    PQ: 0 ANSI: 6"
echo "[ 4612.573621] sd 3:0:0:0: Attached scsi generic sg1 type 0"
echo "[ 4612.574630] sd 3:0:0:0: [sdb] 500118192 512-byte logical blocks: (256 GB/238 GiB)"
echo "[ 4612.574707] sd 3:0:0:0: [sdb] Write Protect is off"
echo "[ 4612.574709] sd 3:0:0:0: [sdb] Mode Sense: 43 00 00 00"
echo "[ 4612.574841] sd 3:0:0:0: [sdb] Write cache: enabled, read cache: enabled, doesn't support DPO or FUA"
echo "[ 4612.579213] sd 3:0:0:0: [sdb] Attached SCSI disk"
echo -e ${nc}
echo
echo -e "Notice the ${white}manufacturer${nc} and the ${white}size${nc} of the SSD. This can help to make sure you have"
echo -e "the correct device. ${red}WARNING${nc} - Failure to use the correct device can overright your main"
echo "hard drive, so please be very careful."
echo
echo "In this case, the drive we want to use is /dev/sdb"
echo
echo "If you have any doubts about using this script - STOP and get HELP!"
echo
echo -e "We will ${yellow}ATTEMPT${nc} to check to make sure everything should run correctly, but we will not"
echo "know the actual device you are using, so be careful!"
echo
echo

}

case "$1" in
    create_image)   create_image ;;
    restore_image)    restore_image ;;
    help)    help ;;
    *) echo "usage: $0 [create_image | restore_image | help]" >&2
       exit 1
       ;;
esac

