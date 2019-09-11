#!/bin/bash
echo "Start S/E function raw command..."
i="ipmitool raw 0x04"
sleep 1
read -p "Please input BMC channel number(with 0xFF format) :" Ch
read -p "Please input sensor name for testing(Has Hysteresis defined) :" SN 
read -p "Please input sensor type of $SN(with 0xFF format) :" ST
read -p "Please input event type of $SN(with 0xFF format) :" ET
read -p "Please input alert destination IPaddr(IPv4) :" CliIP
read -p "Please input alert destination MACaddr(with '-' format like 01-02-03-04-05-06) :" CliMAC
# Split the ipaddr to several variable
IFS=. read ip1 ip2 ip3 ip4 <<< "$CliIP" # set delimiter IFS='.' then pass the string $CliIP to read ip1-ip4 
# Can also use ${CliIP%%.*} '%%.*' %% means matches the left side string with right side character in this case assume the CliIP is 127.0.0.1 ${CliIP%%.*} will be 127
# Then delete the first string of ip with CliIP=${CliIP#*.*} the {#*.*} means that before(including) first character '.' all string ignore, so in this case $CliIP will be 0.0.1 then repeat the step til all number are saved
# If there use ${CliIP##*.*} ignore all string before the last character '.', in this case $CliIP will be 1
# ip1=${CliIP%%.*} && CliIP=${CliIP#*.*}
# ip2=${CliIP%%.*} && CliIP=${CliIP#*.*} 
# ip3=${CliIP%%.*} && CliIP=${CliIP#*.*}
# ip4=${CliIP%%.*} && CliIP=${CliIP#*.*}

## Convert ip to hex
ip1=$(printf '%x\n' "$ip1")
ip2=$(printf '%x\n' "$ip2")
ip3=$(printf '%x\n' "$ip3")
ip4=$(printf '%x\n' "$ip4")
CliIP=0x$ip1 0x$ip2 0x$ip3 0x$ip4

## Convert MAC format
IFS=- read mac1 mac2 mac3 mac4 mac5 mac6 <<< "$CliMAC"
CliMAC="0x$mac1 0x$mac2 0x$mac3 0x$mac4 0x$mac5 0x$mac6"

SID=0x$(ipmitool sdr elist | grep -i "$SN" | awk -F\| '{print$2}' | cut -c 2-3) #with SN (sensor name) to search the sdr elist then cut the sensor ID to perform like 0xXX and save into $SID.
FailCounter=0

# Set response color
color_reset='\e[0m'
color_green='\e[32m'
color_red='\e[31m'
color_convert='\e[7m'

#
## Start the test
# 
#
#
# raw 0x04 0x00
echo Set Event Receiver >> SE.log
echo "Response below :" >> SE.log
$i 0x00
if [ ! $?==0 ] ; then
	echo Set Event Receiver failed 
	$i 0x00 >> SE.log
	echo " Set Event Receiver $i 0x00 fail " >> SE.log
	$FailCounter=$(($FailCounter+1))
else
	echo Set Event Receiver success
	$i 0x00 >> SE.log
	echo " Set Event Receiver $i 0x00 success " >> SE.log
fi

# raw 0x04 0x01
echo Get Event Receiver >> SE.log
echo "Response below :" >> SE.log
$i 0x01
if [ ! $?==0 ] ; then
	echo Get Event Receiver failed 
	$i 0x01 >> SE.log
	echo " Get Event Receiver $i 0x01 fail " >> SE.log
	$FailCounter=$(($FailCounter+1))
else
	echo Get Event Receiver success
	$i 0x01 >> SE.log
	echo " Get Event Receiver $i 0x01 success " >> SE.log
fi

# raw 0x04 0x02
echo Platform Event Message Command >> SE.log
echo "Response below :" >> SE.log
$i 0x02 0x04 $ST $SID $ET 0x00 0x00 0x00
if [ ! $?==0 ] ; then
	echo Platform Event Message Command failed 
	$i 0x02 0x04 0x07 0x70 0x6f 0x00 0x00 0x00 >> SE.log
	echo " Platform Event Message Command $i 0x02 fail " >> SE.log
	$FailCounter=$(($FailCounter+1))
else
	echo Platform Event Message Command success
	$i 0x02 0x04 $ST $SID $ET 0x00 0x00 0x00 >> SE.log
	echo " Platform Event Message Command $i 0x02 success " >> SE.log
fi

# raw 0x04 0x10
echo Get PEF Capabilities Command >> SE.log
echo "Response below :" >> SE.log
$i 0x10
if [ ! $?==0 ] ; then
	echo Get PEF Capabilities Command failed 
	$i 0x10 >> SE.log
	echo " Get PEF Capabilities Command $i 0x10 fail " >> SE.log
	$FailCounter=$(($FailCounter+1))
else
	echo Get PEF Capabilities Command success
	$i 0x10 >> SE.log
	echo " Get PEF Capabilities Command $i 0x10 success " >> SE.log
fi

# raw 0x04 0x11
echo Arm PEF Postpone Timer Command >> SE.log
echo "Response below :" >> SE.log
$i 0x11 0x05
if [ ! $?==0 ] ; then
	echo Arm PEF Postpone Timer Command failed 
	$i 0x11 0x05 >> SE.log
	echo " Arm PEF Postpone Timer Command $i 0x11 fail " >> SE.log
	$FailCounter=$(($FailCounter+1))
else
	echo Arm PEF Postpone Timer Command success
	$i 0x11 0x05 >> SE.log
	echo " Arm PEF Postpone Timer Command $i 0x11 success " >> SE.log
fi

# raw 0x04 0x12
echo Set PEF Configuration Parameters Command >> SE.log
echo "Response below :" >> SE.log
# Set all PEF action disable
$i 0x12 0x02 0x00
if [ ! $?==0 ] ; then
	echo Set PEF Configuration Parameters Command failed 
	$i 0x12 0x02 0x00>> SE.log
	echo " Set PEF Configuration Parameters Command $i 0x12 fail " >> SE.log
	$FailCounter=$(($FailCounter+1))
else
	echo Set PEF Configuration Parameters Command success
	$i 0x12 0x02 0x00 >> SE.log
	echo " Set PEF Configuration Parameters Command $i 0x12 success " >> SE.log
fi

# raw 0x04 0x13
echo Get PEF Configuration Parameters Command >> SE.log
echo "Response below :" >> SE.log
# Get all PEF action global setting
$i 0x13 0x02 0x00 0x00
if [ ! $?==0 ] ; then
	echo Get PEF Configuration Parameters Command failed 
	$i 0x13 0x02 0x00 0x00>> SE.log
	echo " Get PEF Configuration Parameters Command $i 0x13 fail " >> SE.log
	$FailCounter=$(($FailCounter+1))
else
	if [ ! $($i 0x13 0x02 0x00 0x00) == " 11 00" ]; then
		echo Get PEF Configuration Parameters Command failed 
		$i 0x13 0x02 0x00 0x00>> SE.log
		echo " Get PEF Configuration Parameters Command $i 0x13 fail " >> SE.log
		$FailCounter=$(($FailCounter+1))
	else
		echo Get PEF Configuration Parameters Command success
		$i 0x13 0x02 0x00 0x00 >> SE.log
		echo " Get PEF Configuration Parameters Command $i 0x13 success " >> SE.log
	fi
	
fi

# raw 0x04 0x14
echo Set Last Processed Event ID Command >> SE.log
echo "Response below :" >> SE.log
$i 0x14 0x01 0xff 0xff
if [ ! $?==0 ] ; then
	echo Set Last Processed Event ID Command failed 
	$i 0x14 0x01 0xff 0xff>> SE.log
	echo " Set Last Processed Event ID Command $i 0x14 fail " >> SE.log
	$FailCounter=$(($FailCounter+1))
else
	echo Set Last Processed Event ID Command success
	$i 0x14 0x01 0xff 0xff >> SE.log
	echo " Set Last Processed Event ID Command $i 0x14 success " >> SE.log
fi

# raw 0x04 0x15
echo Get Last Processed Event ID Command >> SE.log
echo "Response below :" >> SE.log
$i 0x15
if [ ! $?==0 ] ; then
	echo Set Last Processed Event ID Command failed 
	$i 0x15 >> SE.log
	echo " Get Last Processed Event ID Command $i 0x15 fail " >> SE.log
	$FailCounter=$(($FailCounter+1))
else
	if [$($i 0x15 |awk '{print$9$10}') == "ffff" ]; then
		echo Get Last Processed Event ID Command success
		$i 0x15 >> SE.log
		echo " Get Last Processed Event ID Command $i 0x15 success " >> SE.log
	else
		echo Set Last Processed Event ID Command failed 
		$i 0x15 >> SE.log
		echo " Get Last Processed Event ID Command $i 0x15 fail " >> SE.log
		$FailCounter=$(($FailCounter+1))
fi
fi

# raw 0x04 0x16
echo Alert Immediate Command >> SE.log
echo "Response below :" >> SE.log
# Set PEF alert destination selector 01
ipmitool raw 0x0c 0x01 0x01 0x12 0x01 0x00 0x00 0x00 # Set set destination 1
ipmitool raw 0x0c 0x01 0x01 0x13 0x01 0x00 0x00 $CliIP $CliMAC # Set alert destination 1 IPaddr and MAC
ipmitool raw 0x0c 0x01 0x01 0x00 0x02 # Set commit write(optional)
ipmitool raw 0x0c 0x01 0x01 0x00 0x00 # Set Complete
# Send alert immediately to destination 1
$i 0x16 $Ch 0x01 0x00 
if [ ! $?==0 ] ; then
	echo Alert Immediate Command failed 
	$i 0x16 $Ch 0x01 0x00 >> SE.log
	echo " Alert Immediate Command $i 0x16 fail " >> SE.log
	$FailCounter=$(($FailCounter+1))
else
	echo Alert Immediate Command success
	$i 0x16 $Ch 0x01 0x00 >> SE.log
	echo " Alert Immediate Command $i 0x16 success " >> SE.log
fi



# raw 0x04 0x20
echo Get Device SDR Info Command >> SE.log
echo "Response below :" >> SE.log
$i 0x20 0x01 #get SDR count 0x00 get sensor count
if [ ! $?==0 ] ; then
	echo Get Device SDR Info Command failed 
	$i 0x20 0x01>> SE.log
	echo " Get Device SDR Info Command $i 0x20 fail " >> SE.log
	$FailCounter=$(($FailCounter+1))
else
	echo Get Device SDR Info Command success
	$i 0x20 0x01 >> SE.log
	echo " Get Device SDR Info Command $i 0x20 success " >> SE.log
fi

# raw 0x04 0x21
echo Get Device SDR Command >> SE.log
echo "Response below :" >> SE.log
$i 0x21 0x00 0x00 0x00 0x00 0x08 0xff #get SDR that offset 0x08 
if [ ! $?==0 ] ; then
	echo Get Device SDR Command failed 
	$i 0x21 0x00 0x00 0x00 0x00 0x08 0xff>> SE.log
	echo " Get Device SDR Command $i 0x21 fail " >> SE.log
	$FailCounter=$(($FailCounter+1))
else
	echo Get Device SDR Command success
	$i 0x21 0x00 0x00 0x00 0x00 0x08 0xff >> SE.log
	echo " Get Device SDR Command $i 0x21 success " >> SE.log
fi

# raw 0x04 0x22
echo Reserve Device SDR Repository Command >> SE.log
echo "Response below :" >> SE.log
$i 0x22  
if [ ! $?==0 ] ; then
	echo Reserve Device SDR Repository Command failed 
	$i 0x22 >> SE.log
	echo " Reserve Device SDR Repository Command $i 0x22 fail " >> SE.log
	$FailCounter=$(($FailCounter+1))
else
	echo Reserve Device SDR Repository Command success
	$i 0x22 >> SE.log
	echo " Reserve Device SDR Repository Command $i 0x22 success " >> SE.log
fi

# raw 0x04 0x23
#echo Get Sensor Reading Factors Command >> SE.log
#echo "Response below :" >> SE.log
#$i 0x23 0x10  # sensor ID 10h
#if [ ! $?==0 ] ; then
#	echo Get Sensor Reading Factors Command failed 
#	$i 0x23 0x10 >> SE.log
#	echo " Get Sensor Reading Factors Command $i 0x23 fail " >> SE.log
#	$FailCounter=$(($FailCounter+1))
#else
#	echo Get Sensor Reading Factors Command success
#	$i 0x23 0x10 >> SE.log
#	echo " Get Sensor Reading Factors Command $i 0x23 success " >> SE.log
#fi

# raw 0x04 0x24
echo Set Sensor Hysteresis Command >> SE.log
echo "Response below :" >> SE.log
resH="$i 0x25 $SID 0xff"
IFS=" " read resH1 resH2 < "$resH"
$i 0x24 $SID 0xff 0x00 0x00 
if [ ! $?==0 ] ; then
	echo Set Sensor Hysteresis Command failed 
	$i 0x24 $SID 0xff 0x00 0x00 >> SE.log
	echo " Set Sensor Hysteresis Command $i 0x24 fail " >> SE.log
	$FailCounter=$(($FailCounter+1))
else
	echo Set Sensor Hysteresis Command success
	$i 0x24 $SID 0xff 0x00 0x00>> SE.log
	echo " Set Sensor Hysteresis Command $i 0x24 success " >> SE.log
	echo restore default setting....
	$i 0x24 $SID 0xff 0x$resH1 0x$resH2
	echo restore setting fnished....
fi

# raw 0x04 0x25
echo Get Sensor Hysteresis Command >> SE.log
echo "Response below :" >> SE.log
$i 0x25 $SID 0xff
if [ ! $?==0 ] ; then
	echo Get Sensor Hysteresis Command failed 
	$i 0x25 $SID >> SE.log
	echo " Get Sensor Hysteresis Command $i 0x25 fail " >> SE.log
	$FailCounter=$(($FailCounter+1))
else
	echo Get Sensor Hysteresis Command success
	$i 0x25 $SID>> SE.log
	echo " Get Sensor Hysteresis Command $i 0x25 success " >> SE.log
fi

# raw 0x04 0x26
#echo Set Sensor Thresholds Command >> SE.log
#echo "Response below :" >> SE.log
#$i 0x26 $SID 
#if [ ! $?==0 ] ; then
#	echo Set Sensor Thresholds Command failed 
#	$i 0x26 $SID >> SE.log
#	echo " Set Sensor Thresholds Command $i 0x26 fail " >> SE.log
#	$FailCounter=$(($FailCounter+1))
#else
#	echo Set Sensor Thresholds Command success
#	$i 0x26 $SID >> SE.log
#	echo " Set Sensor Thresholds Command $i 0x26 success " >> SE.log
#fi

# raw 0x04 0x27
echo Get Sensor Thresholds Command >> SE.log
echo "Response below :" >> SE.log
$i 0x27 $SID 
if [ ! $?==0 ] ; then
	echo Get Sensor Thresholds Command failed 
	$i 0x27 $SID >> SE.log
	echo " Get Sensor Thresholds Command $i 0x27 fail " >> SE.log
	$FailCounter=$(($FailCounter+1))
else
	echo Get Sensor Thresholds Command success
	$i 0x27 $SID >> SE.log
	echo " Get Sensor Thresholds Command $i 0x27 success " >> SE.log
fi

# raw 0x04 0x28
echo Set Sensor Event Enable Command >> SE.log
echo "Response below :" >> SE.log
SEE=$($i 0x29 $SID)
IFS=' ' read SEE1 SEE2 SEE3 SEE4 SEE5 SEE6 <<< "$SEE"
$i 0x28 $SID 0xc0 0x$SEE2 0x$SEE3 0x$SEE4 0x$SEE5 0x$SEE6
if [ ! $?==0 ] ; then
	echo Set Sensor Event Enable Command failed 
	$i 0x28 $SID 0xc0 0x$SEE2 0x$SEE3 0x$SEE4 0x$SEE5 0x$SEE6 >> SE.log
	echo " Set Sensor Event Enable Command $i 0x28 fail " >> SE.log
	$FailCounter=$(($FailCounter+1))
else
	if [[ "$($i 0x29 $SID)"=="0xc0 $SEE2 $SEE3 $SEE4 $SEE5 $SEE6" ]]
		echo Set Sensor Thresholds Command success
		$i 0x28 $SID 0xc0 0x$SEE2 0x$SEE3 0x$SEE4 0x$SEE5 0x$SEE6 >> SE.log
		echo " Set Sensor Event Enable Command $i 0x28 success " >> SE.log
		echo Set Sensor Event Enable Command failed 
		$i 0x28 $SID 0xc0 0x$SEE2 0x$SEE3 0x$SEE4 0x$SEE5 0x$SEE6 >> SE.log
		echo " Set Sensor Event Enable Command $i 0x28 fail " >> SE.log
		$FailCounter=$(($FailCounter+1))
	else
	fi
fi

# raw 0x04 0x2a
echo Re-arm Sensor Events Command >> SE.log
echo "Response below :" >> SE.log
$i 0x2a $SID 0x00
if [ ! $?==0 ] ; then
	echo Re-arm Sensor Events Command failed 
	$i 0x2a $SID 0x00 >> SE.log
	echo " Re-arm Sensor Events Command $i 0x2a fail " >> SE.log
	$FailCounter=$(($FailCounter+1))
else
	echo Re-arm Sensor Events Command success
	$i 0x2a $SID 0x00 >> SE.log
	echo " Re-arm Sensor Events Command $i 0x2a success " >> SE.log
fi

# raw 0x04 0x2b
echo Get Sensor Event Status Command >> SE.log
echo "Response below :" >> SE.log
$i 0x2b $SID
if [ ! $?==0 ] ; then
	echo Get Sensor Event Status Command failed 
	$i 0x2b $SID >> SE.log
	echo " Get Sensor Event Status Command $i 0x2b fail " >> SE.log
	$FailCounter=$(($FailCounter+1))
else
	echo Get Sensor Event Status Command success
	$i 0x2b $SID >> SE.log
	echo " Get Sensor Event Status Command $i 0x2b success " >> SE.log
fi

# raw 0x04 0x2d
echo Get Sensor Reading Command >> SE.log
echo "Response below :" >> SE.log
$i 0x2d $SID
if [ ! $?==0 ] ; then
	echo Get Sensor Reading Command failed 
	$i 0x2d $SID >> SE.log
	echo " Get Sensor Reading Command $i 0x2d fail " >> SE.log
	$FailCounter=$(($FailCounter+1))
else
	echo Get Sensor Reading Command success
	$i 0x2d $SID >> SE.log
	echo " Get Sensor Reading Command $i 0x2d success " >> SE.log
fi

# raw 0x04 0x2f
echo Get Sensor Type Command >> SE.log
echo "Response below :" >> SE.log
$i 0x2f $SID
if [ ! $?==0 ] ; then
	echo Get Sensor Type Command failed 
	$i 0x2f $SID >> SE.log
	echo " Get Sensor Type Command $i 0x2f fail " >> SE.log
	$FailCounter=$(($FailCounter+1))
else
	echo Get Sensor Type Command success
	$i 0x2f $SID >> SE.log
	echo " Get Sensor Type Command $i 0x2f success " >> SE.log
fi

# raw 0x04 0x2e
echo Set Sensor Type Command >> SE.log
echo "Response below :" >> SE.log
$i 0x2e $SID
if [ ! $?==0 ] ; then
	echo Set Sensor Type Command failed 
	$i 0x2e $SID >> SE.log
	echo " Set Sensor Type Command $i 0x2c fail " >> SE.log
	$FailCounter=$(($FailCounter+1))
else
	echo Set Sensor Type Command success
	$i 0x2e $SID >> SE.log
	echo " Set Sensor Type Command $i 0x2e success " >> SE.log
fi

if [ ! $FailCounter == 0 ]; then
	echo "Sensor&Event function test finished but has some command failed check the log please."
	echo "Sensor&Event function test finished but has some command failed check the log please." >> SE.log
else
	echo "Sensor&Event function test finished."
	echo "Sensor&Event function test finished." >> SE.log
fi