#!/bin/sh

#find out the base path and return to entry path
enterypath=$PWD
cd `echo ${0%/*}` && cd ../
wavePath=$PWD
cd $enterypath

#TODO, make path dynamic base on path 
if [ -z "$1"]
then
	xmlPath="/$wavePath/db/"
else
	xmlPath="$1"
fi

output=/tmp/wlan_wave/dbXml/output/
release=/$wavePath/db/default/

addSpecialToInterface()
{
	local file_name=$1
	echo "Object_0=Device.WiFi.Security_State" > $file_name
	echo "WpaEncMode_0=AESEncryption" >> $file_name
	echo "EncryptionMode_0=ENC_AES" >> $file_name
	echo "BasicAuthMode_0=None" >> $file_name
	echo "AuthenticationMode_0=AUTH_PSK" >> $file_name
	echo "BeaconType_0=11i" >> $file_name
}

prepareRadio()
{
	fapi_wlan_dbXml ${xmlPath}/WiFi_data.xml ${output}
	
	cd $output
	radioList=`ls Device.WiFi.Radio.[1-9] | awk -F "."  '{print $4}'`
	cd -

	for radioNumber in $radioList
	do
		#We need decrease 1 because in WLAN the counting start from 0
		radioRPC=$radioNumber
		let radioRPC=$radioRPC-1

		mkdir -p ${release}/radio${radioRPC}/

		addSpecialToInterface "${release}/radio${radioRPC}/Device.WiFi.Security_State"

		cd $output
		for file in `ls | grep "Device\.WiFi\.[a-zA-Z]*\.${radioNumber}"`
		do
			mv $file ${release}/radio${radioRPC}/
		done
		cd -

		cd ${release}/radio${radioRPC}/
		for file in `ls`
		do
			fileNoIndex=`echo $file | sed 's/\.[0-9]//1'`
			mv $file $fileNoIndex
			sed 's/^Object_0.*$/Object_0='"$fileNoIndex"'/' -i $fileNoIndex
		done
		cd -
	done
	
	mv $output/Device.WiFi* ${release}/
}

prepareVap()
{
	fapi_wlan_dbXml ${xmlPath}/WiFi_control.xml ${output}

	mkdir -p ${release}/vap/
	# TODO
	# Add attribute support for what to copy for VAP and remove workaround
	rm -f $output/Device.WiFi.AccessPoint.AC*
	rm -f $output/Device.WiFi.AccessPoint.X_LANTIQ_COM_Vendor.HS20.*
	rm -f $output/Device.WiFi.AccessPoint.WPS
	mv $output/Device.WiFi.AccessPoint* ${release}/vap/
	mv $output/Device.WiFi.SSID* ${release}/vap/
	addSpecialToInterface "${release}/vap/Device.WiFi.Security_State"
}

patchPUMA()
{
	echo "EnableOnLine_0=false" >> ${release}/vap/Device.WiFi.AccessPoint.X_LANTIQ_COM_Vendor
}

#Main
#if [ -n "$1" ]
#then
#	hg clone https://mts.lantiq.com/~wlnsw/repo/feed/feed_sl_wlan feed_sl_wlan
#	hg update -C "$tag"
#	xmlPath="./feed_sl_wlan/files/db_xml/"
#else
#	xmlPath="./unitTestDB/"
#fi

#Clean folders and create Database
rm -rf ${release}/* || mkdir -p ${release}/
rm -rf $output/*
mkdir -p $output/
prepareRadio
rm -rf $output/*
prepareVap
patchPUMA
rm -rf $output/
