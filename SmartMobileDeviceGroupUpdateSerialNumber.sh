#!/bin/bash

# Name: SmartMobileDeviceGroupUpdateSerialNumber.sh
# Date: 04-23-2022
# Author: Michael Permann
# Version: 1.0
# Credits: Inspiration provided by Jamf Nation discussion https://www.jamf.com/jamf-nation/\
# discussions/10471/script-to-add-computers-to-static-group-by-computer-name#responseChild169014
# Purpose: Updates smart mobile device group using group name and list of serial numbers.
# Group name and path to list of serial numbers can be provided as command line arguments or they 
# can be provided interactively. If the group doesn't exist, it will be created. Please avoid 
# spaces in file name or paths.
# Usage: SmartMobileDeviceGroupUpdateSerialNumber.sh "Smart_Mobile_Device_Name" "/path/to/list/of/serial/numbers"

APIUSER="USERNAME"
APIPASS="PASSWORD"
JPSURL="https://jamf.pro.url:8443"
STATUSCODE="200"
smartGroupName=$1
importList=$2

# Check if command line arguments provided, if not request them interactively
if [ ! "$1" ] || [ ! -f "$2" ]
then
    /bin/echo "Command line arguments not found"
    /bin/echo "Provide smart group name"
    read -r -p 'Name: ' smartGroupName
    /bin/echo "$smartGroupName"
    /bin/echo "Provide path to file containing serial numbers"
    read -r -p 'Path to file: ' importList
    /bin/echo "$importList"
fi

smartGroupNameStatusCode=$(/usr/bin/curl -o /dev/null -w "%{http_code}" -s -k -u "$APIUSER":"$APIPASS" "$JPSURL"/JSSResource/mobiledevicegroups/name/"${smartGroupName// /%20}")
/bin/echo "Compare $smartGroupNameStatusCode to $STATUSCODE"
if [ "$smartGroupNameStatusCode" != "$STATUSCODE" ]
then
    /bin/echo "Smart group name is $smartGroupName"
    /bin/echo "That doesn't appear to be a valid smart group"
    # Create the smart group using provided name
    smartGroupID=$(/usr/bin/curl -s -k -u "$APIUSER":"$APIPASS" "$JPSURL"/JSSResource/mobiledevicegroups/id/0 -X POST -H Content-type:application/xml --data "<mobile_device_group><name>$smartGroupName</name><is_smart>true</is_smart><site><id>-1</id><name>None</name></site></mobile_device_group>" | xpath -e /mobile_device_group/id | tr -cd "[:digit:]")
    /bin/echo "$smartGroupName created with ID of: $smartGroupID"
else
    /bin/echo "Group is valid"
    smartGroupID=$(/usr/bin/curl -s -k -u "$APIUSER":"$APIPASS" "$JPSURL"/JSSResource/mobiledevicegroups/name/"${smartGroupName// /%20}" | xpath -e /mobile_device_group/id | tr -cd "[:digit:]")
    /bin/echo "$smartGroupName already exists with ID of: $smartGroupID"
fi
    
# Start creating XML for mobile device group to be uploaded at the end
groupXML="<mobile_device_group><criteria>"

# Read list into an array
inputArrayCounter=0
while read -r line || [[ -n "$line" ]]
do
    inputArray[$inputArrayCounter]="$line"
    inputArrayCounter=$((inputArrayCounter+1))
done < "$importList"
/bin/echo "${#inputArray[@]} lines found"

foundCounter=0
for ((i = 0; i < ${#inputArray[@]}; i++))
do
    /bin/echo "Processing ${inputArray[$i]}"
    groupXML="$groupXML<criterion><name>Serial Number</name><priority>$i</priority><and_or>or</and_or><search_type>is</search_type><value>${inputArray[$i]}</value></criterion>"
    foundCounter=$((foundCounter+1))
done

# Finish creating XML for Mobile Device group
groupXML="$groupXML</criteria></mobile_device_group>"

# Print final XML
/bin/echo "$groupXML"
/bin/echo "$smartGroupID"

# Report on and attempt smart group creation
/bin/echo "$foundCounter mobile devices matched"
/bin/echo "Attempting to upload mobile devices to group $smartGroupID"
/usr/bin/curl -s -k -u "$APIUSER":"$APIPASS" "$JPSURL"/JSSResource/mobiledevicegroups/id/"$smartGroupID" -X PUT -H Content-type:application/xml --data "$groupXML"