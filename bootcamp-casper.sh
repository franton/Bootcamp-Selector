#!/bin/bash

# Script to detect if Bootcamp partition is present then place the appropriate image in it.

# Author  : contact@richard-purves.com
# Version : 1.0 - Initial Version

# I'll be honest. There is a lot "borrowed" from different places.
# Code for changing bootcamp install hostname is from DeployStudio.
# The renaming of Windows relies totally on TwoCanoe's Winclone and the tools it embeds in it's own files.
# Since we're also using the pkg installer it generates, we don't need to worry about EFI vs MBR booting.
# However we do need the pkg set up NOT to create a partition. You will have to do that yourselves via Casper, DeployStudio etc.
# I do it that way so this script exits early if the partition is not present.

# Setup variables here

LOGFOLDER="/private/var/log/organisation"
LOG=$LOGFOLDER"/Bootcamp-Install.log"
WAITINGROOM="/Library/Application\ Support/JAMF/Waiting Room"

DISK=$( diskutil list | grep "Microsoft Basic Data" | awk '{ print $8 }' )
DISK_ID=$( echo $DISK | cut -c5 )
PARTITION_ID=$( echo $DISK | cut -c7 )
NTFS_DEVICE=${DISK_ID}s${PARTITION_ID}

MODELID=$( sysctl hw.model | awk '{ print $2 }' )

# This is where we take the current hostname and append PC- in front of it for our naming convention
# Modify the next two lines to however you need your computers named. Ours has the asset tag in the number.

HOSTNAME=$( scutil --get HostName | awk '{print toupper($0)}' )
PCHOSTNAME="PC-$HOSTNAME"

# Ok, does the log folder exist? If not then create.

if [ ! -d "$LOGFOLDER" ];
then
	mkdir $LOGFOLDER
fi

# Setup functions here: logging, changing the windows hostname and installing bootcamp.

logme()
{
	# Check to see if function has been called correctly
	if [ -z "$1" ]
	then
		echo $( date )" - logme function call error: no text passed to function! Please recheck code!" >> $LOG
		exit 1
	fi

	# Log the passed details
	echo $( date )" - "$1 >> $LOG
	echo "" >> $LOG
}

changeBCname()
{
	# unmount device
	logme "Unmounting disk $NTFS_DEVICE"
	diskutil unmountDisk $NTFS_DEVICE | tee -a ${LOG}

	# sysprep file lookup
	SYSPREP_FILE=""
	"${TOOLS_FOLDER}"/ntfscat -f "${NTFS_DEVICE}" /SysPrep/SYSPREP.INF > /tmp/SYSPREP.INF

	if [ ${?} -eq 0 ]
	then
		SYSPREP_FILE=/SysPrep/SYSPREP.INF
	else
		"${TOOLS_FOLDER}"/ntfscat -f "${NTFS_DEVICE}" /windows/panther/unattend.XML > /tmp/unattend.xml

		if [ ${?} -eq 0 ]
		then
			SYSPREP_FILE=/windows/panther/unattend.XML
		else
			"${TOOLS_FOLDER}"/ntfscat -f "${NTFS_DEVICE}" /windows/system32/sysprep/unattend.xml > /tmp/unattend.xml

			if [ ${?} -eq 0 ]
			then
				SYSPREP_FILE=/windows/system32/sysprep/unattend.xml
			fi
		fi
	fi

	# update sysprep's file ComputerName attribute
	if [ -n "${SYSPREP_FILE}" ] && [ -n "${PCHOSTNAME}" ]
	then

		if [ `basename "${SYSPREP_FILE}"` = "SYSPREP.INF" ]
		then
			INF_SYSPREP_COMPUTERNAME=`grep -i -m 1 "ComputerName=" /tmp/SYSPREP.INF | tr -d " \n\r" | sed s/'*'/'\\\*'/`

			if [ -n "${INF_SYSPREP_COMPUTERNAME}" ]
			then
				logme "Updating computer name in ${SYSPREP_FILE} to ${PCHOSTNAME}"
				sed s%"${INF_SYSPREP_COMPUTERNAME}"%"ComputerName=${PCHOSTNAME}"% /tmp/SYSPREP.INF > /tmp/SYSPREP.INF.NEW
				"${TOOLS_FOLDER}"/ntfscp -f "${NTFS_DEVICE}" /tmp/SYSPREP.INF.NEW "${SYSPREP_FILE}"

				if [ ${?} -ne 0 ]
				then
					logme "Error performing NTFS file operation on ${SYSPREP_FILE}. Aborting."
					exit 1
				fi
			fi
		else
			XML_SYSPREP_COMPUTERNAME=`grep -i -m 1 "<ComputerName>.*</ComputerName>" /tmp/unattend.xml | tr -d " \n\r" | sed s/'*'/'\\\*'/ | awk -F"ComputerName" '{ print $2 }'`

			if [ -n "${XML_SYSPREP_COMPUTERNAME}" ]
			then
				logme "Updating computer name in ${SYSPREP_FILE} to ${PCHOSTNAME}"
				sed s%"${XML_SYSPREP_COMPUTERNAME}"%">${PCHOSTNAME}</"% /tmp/unattend.xml > /tmp/unattend.xml.NEW
				"${TOOLS_FOLDER}"/ntfscp -f "${NTFS_DEVICE}" /tmp/unattend.xml.NEW "${SYSPREP_FILE}"

				if [ ${?} -ne 0 ]
				then
					logme "Error performing NTFS file operation on ${SYSPREP_FILE}. Aborting."
				exit 1
				fi
			fi
		fi
	fi 

	# remount device
	logme "Mounting device $NTFS_DEVICE"
	diskutil mountDisk $NTFS_DEVICE | tee -a ${LOG}
}

installBC()
{
	NAME="$1"
	BCINSTALL="$WAITINGROOM/$NAME.pkg"
	TOOLS_FOLDER="$BCINSTALL/Contents/Resources/$NAME.winclone"

	logme "Caching $NAME.pkg"
	jamf policy -trigger $NAME | tee -a ${LOG}
	
	logme "Installing $NAME.pkg"
	installer -pkg $BCINSTALL -target / -verboseR | tee -a ${LOG}
	
	logme "Changing Windows hostname"
	changeBChostname

	logme "Cleaning up cached installation folder"
	rm -Rfd $BCINSTALL | tee -a ${LOG}
}

# First check to see if a Bootcamp partition is present

if [ $DISK = "" ];
then
	logme "Bootcamp partition not present. Exiting."
	exit 0
fi

# Ok we get to do stuff. Start the logging.

logme "Bootcamp Installation Script"
logme "Current computer name: $HOSTNAME"
logme "Windows computer name: $PCHOSTNAME"

# Now run the appropriate installation on the current computer

case "$MODELID" in

	#### Windows 8.1 section ####

	# Bootcamp 5.1.5886
	
	"MacBookPro12"*|"MacBookAir7"*|"MacBook8"*)
		logme "Starting installation of Windows 8 with Bootcamp 5.1.5886 64bit"
		installBC "Win8-5.1.5886-64bit"
	;;

	# Bootcamp 5.5776

	"iMac15"*)
		logme "Starting installation of Windows 8 with Bootcamp 5.1.5776 64bit"
		installBC "Win8-5.1.5776-64bit"
	;;
	
	# Bootcamp 5.5640

	"MacBookPro11"*|"MacBookAir6"*|"iMac14"*|"MacPro6"*|"Macmini7"*)
		logme "Starting installation of Windows 8 with Bootcamp 5.1.5640 64bit"
		installBC "Win8-5.1.5640-64bit"
	;;

	# Bootcamp 5

	"MacBookPro10"*|"iMac13"*|"VMware"*)
		logme "Starting installation of Windows 8 with Bootcamp 5 64bit"
		installBC "Win8-5-64bit"
	;;

	#### Windows 7 64bit Boot Camp 5 section ####
	
	"MacBookPro6"*|"MacBookPro8"*|"MacBookPro9"*|"MacBookAir4"*|"MacBookAir5"*|"iMac11,3"|"iMac12"*|"Macmini5"*|"Macmini6"*|"MacPro4"*|"MacPro5"*)
		logme "Starting installation of Windows 7 with Bootcamp 5 64bit"
		installBC "Win7-5-64bit"
	;;
	
	# Note that 27-inch, Mid 2010 is iMac11,3 and gets Boot Camp 5
	
	#### Windows 7 64bit Boot Camp 4 section ####
	
	"MacBookPro4"*|"MacBookPro5"*|"MacBookAir3"*|"MacBook6"*|"MacBook7"*|"iMac10"*|"iMac11,1"|"iMac11,2"|"Macmini4"*|"MacPro3"*)
		logme "Starting installation of Windows 7 with Bootcamp 4 64bit"
		installBC "Win7-4-64bit"
	;;
	
	#### Windows 7 32bit section ####
	
	"MacBookPro7"*|"MacBookAir1"*|"MacBookAir2"*|"MacBook5"*|"iMac7"*|"iMac8"*|"iMac9"*|"Macmini3"*)
		logme "Starting installation of Windows 7 32bit"
		installBC "Win7-32bit.pkg"
	;;
	
esac

logme "Script completed!"
exit 0
