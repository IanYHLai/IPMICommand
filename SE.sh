#!/bin/bash

# Set response color
color_reset='\e[0m'
color_green='\e[32m'
color_red='\e[31m'
color_convert='\e[7m'

echo -e "$color_redRemove and backup the previous log as date format...${color_reset}"
if [ -f "SE.log" ]; then
	cp SE.log $(date +%Y%m%d_%T)_SE.log && rm -f SE.log
fi
date |tee -a SE.log
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

##Convert to Binary
D2B=({0..1}{0..1}{0..1}{0..1}{0..1}{0..1}{0..1}{0..1})

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

#
## Start the test
# 
#
#
# raw 0x04 0x00
echo ""
echo " Set Event Receiver" |tee -a  SE.log
echo " Response below :" |tee -a  SE.log
read ER1 ER2 <<< $i 0x01
$i 0x00 0x20 0x00
if [ ! $?==0 ] ; then
	$i 0x00 0x20 0x00 >> SE.log
	echo " Set Event Receiver failed" | tee -a SE.log
	FailCounter=$(($FailCounter+1))
else
	$i 0x00 0x20 0x00>> SE.log
	echo " Set Event Receiver to Slave Address=0x20 and LUN=0x00 finished " |tee -a SE.log
	echo " Restore default event receiver value..."
	$i 0x00 0x$ER1 0x$ER2
	echo " Restore finished..."
fi

# raw 0x04 0x01
echo ""
echo " Get Event Receiver" |tee -a  SE.log
echo " Response below :" |tee -a  SE.log
$i 0x01
if [ ! $?==0 ] ; then
	$i 0x01 >> SE.log
	echo " Get Event Receiver failed" |tee -a SE.log
	FailCounter=$(($FailCounter+1))
else
	$i 0x01 >> SE.log
	read ER1 ER2 <<< $($i 0x00)
	for j in ER{1..2}; do
		eval temp=\$$j
		temp=${D2B[$((16#$temp))]}
		read $j'b1' $j'b2' $j'b3' $j'b4' $j'b5' $j'b6' $j'b7' $j'b8' <<< "${temp:0:1} ${temp:1:1} ${temp:2:1} ${temp:3:1} ${temp:4:1} ${temp:5:1} ${temp:6:1} ${temp:7:1}"
	done
	if [ $ER1 -eq 'ff' ];then
		echo " Event Message Generation has been disabled."|tee -a SE.log
	else
		echo " Event Receiver Slave Address = 0x$ER1"
	fi
	echo " Event Receiver LUN = 0x$ER2"|tee -a SE.log
	echo " Get Event Receiver finished " |tee -a  SE.log
fi

# raw 0x04 0x02 This command need to check the sensor name , ID, type, event data suggest that manual testing for high testing quality
echo ""
echo " Platform Event Message Command" |tee -a  SE.log
echo " Response below :" |tee -a  SE.log
$i 0x02 0x04 $ST $SID $ET 0x00 0x00 0x00
if [ ! $?==0 ] ; then
	echo " Platform Event Message Command failed" |tee -a SE.log
	$i 0x02 0x04 $ST $SID $ET 0x00 0x00 0x00 >> SE.log
	$FailCounter=$(($FailCounter+1))
else
	$i 0x02 0x04 $ST $SID $ET 0x00 0x00 0x00 >> SE.log
	echo " Platform Event Message Command finished, check whether the SEL log is consisstent with sensor name and event data please..." |tee -a  SE.log
	ipmitool sel elist |tee -a SE.log
fi

# raw 0x04 0x10
echo " Get PEF Capabilities Command" |tee -a  SE.log
echo " Response below :" |tee -a SE.log
$i 0x10
if [ ! $?==0 ] ; then
	echo " Get PEF Capabilities Command failed "|tee -a SE.log
	$i 0x10 >> SE.log
	$FailCounter=$(($FailCounter+1))
else
	$i 0x10 >> SE.log
	read PC1 PC2 PC3 <<< $($i 0x00)
	for j in PC{1..3}; do
		eval temp=\$$j
		temp=${D2B[$((16#$temp))]}
		read $j'b1' $j'b2' $j'b3' $j'b4' $j'b5' $j'b6' $j'b7' $j'b8' <<< "${temp:0:1} ${temp:1:1} ${temp:2:1} ${temp:3:1} ${temp:4:1} ${temp:5:1} ${temp:6:1} ${temp:7:1}"
	done
	
	echo " The PEF version is $PC1'h', it's LSN first, 51h > version 1.5"|tee -a SE.log
	if [ $PC2b1 -eq '1' ];then
		echo " OEM Event Record Filtering supported"|tee -a SE.log
	else 
		echo " OEM Event Record Filtering not supported"|tee -a SE.log
	fi
	if [ $PC2b2 -eq '1' ];then
		echo " This bit is reserved, check the spec please..."|tee -a SE.log
	fi
	echo " Action Suport :"|tee -a SE.log
	if [ $PC2b3 -eq '1' ];then
		echo " Diagnostic interrupt"|tee -a SE.log
	fi
	if [ $PC2b4 -eq '1' ];then
		echo " OEM action"|tee -a SE.log
	fi
	if [ $PC2b5 -eq '1' ];then
		echo " Power cycle"|tee -a SE.log
	fi
	if [ $PC2b6 -eq '1' ];then
		echo " Reset"|tee -a SE.log
	fi
	if [ $PC2b7 -eq '1' ];then
		echo " Power down"|tee -a SE.log
	fi
	if [ $PC2b8 -eq '1' ];then
		echo " Alert"|tee -a SE.log
	fi
	echo ""|tee -a SE.log
	echo "Number of event filter table entries = $((16#$PC3)) "|tee -a SE.log
	echo -e "${color_green} Get PEF Capabilities Command finished${color_reset}"|tee -a SE.log
fi

# raw 0x04 0x11
echo ""
echo " Arm PEF Postpone Timer Command"|tee -a SE.log
echo " Response below :" |tee -a SE.log
$i 0x11 0x05
if [ ! $?==0 ] ; then
	$i 0x11 0x05 >> SE.log
	echo " Set Arm PEF Postpone Timer Command failed "|tee -a SE.log
	$FailCounter=$(($FailCounter+1))
else
	$i 0x11 0x05 >> SE.log
	echo " Set Arm PEF Postpone Timer 5 seconds finished "|tee -a SE.log
fi

# raw 0x04 0x12
echo " Set PEF Configuration Parameters Command" |tee -a SE.log
echo " Set all PEF action disable "|tee -a SE.log
echo " Response below :" |tee -a  SE.log
# Set all PEF action disable
$i 0x12 0x02 0x00
if [ ! $?==0 ] ; then
	$i 0x12 0x02 0x00>> SE.log
	echo " Set all PEF action disable failed "|tee -a SE.log
	$FailCounter=$(($FailCounter+1))
else
	if [ ! "$($i 0x13 0x02 0x00 0x00)" == " 11 00" ]; then
		echo " Set all PEF action disable failed the response of get configuration doesn't match the setting "|tee -a SE.log
		$FailCounter=$(($FailCounter+1))
	else
		$i 0x12 0x02 0x00 >> SE.log
		echo " Set all PEF action disable finished"|tee -a SE.log	
	fi
fi

# raw 0x04 0x13
echo " Get PEF Configuration Parameters Command "|tee -a SE.log
echo " Get PEF set in progress state "|tee -a SE.log
echo " Response below :"|tee -a SE.log
# Get PEF set in progress state
$i 0x13 0x00 0x00 0x00
if [ ! $?==0 ] ; then
	$i 0x13 0x00 0x00 0x00>> SE.log
	echo " Get PEF set in progress state failed "|tee -a SE.log
	$FailCounter=$(($FailCounter+1))
else
	read GP1 GP2 <<< $($i 0x00)
	for j in GP{1..2}; do
		eval temp=\$$j
		temp=${D2B[$((16#$temp))]}
		read $j'b1' $j'b2' $j'b3' $j'b4' $j'b5' $j'b6' $j'b7' $j'b8' <<< "${temp:0:1} ${temp:1:1} ${temp:2:1} ${temp:3:1} ${temp:4:1} ${temp:5:1} ${temp:6:1} ${temp:7:1}"
	done
	$i 0x13 0x00 0x00 0x00 >> SE.log
	echo "The parameter revision is $GP1 (MSN=present revision. LSN = oldest revision parameter is backward compatible with. 11h for parameters in this specification.)"
	case $GP2b7$GP2b8 in 
		00) echo "Now is set complete state"|tee -a SE.log;;
		01) echo "Now is set in progress state"|tee -a SE.log;;
		10) echo "Now is commit write state"|tee -a SE.log;;
		11) echo "The state now is reserved please check whether the spec defined or not..."|tee -a SE.log;;
	esac
	echo " Get PEF set in progress state finished"|tee -a SE.log	
fi

# raw 0x04 0x14
echo " Set Last Processed Event ID Command"|tee -a SE.log
echo " Response below :"|tee -a SE.log
echo " Set Last Processed Event ID of BMC to ffff "|tee -a SE.log
$i 0x14 0x01 0xff 0xff
if [ ! $?==0 ] ; then
	$i 0x14 0x01 0xff 0xff>> SE.log
	echo " Set Last Processed Event ID of BMC to ffff failed "|tee -a SE.log
	$FailCounter=$(($FailCounter+1))
else
	$i 0x14 0x01 0xff 0xff >> SE.log
	echo " Set Last Processed Event ID of BMC to ffff finished"|tee -a SE.log
fi
echo ""
# raw 0x04 0x15
echo " Get Last Processed Event ID Command" |tee -a  SE.log
echo " Response below :" |tee -a SE.log
$i 0x15
if [ ! $?==0 ] ; then
	$i 0x15 >> SE.log
	echo " Get Last Processed Event ID Command failed "|tee -a SE.log
	$FailCounter=$(($FailCounter+1))
else
	if [ $($i 0x15 |awk '{print$9$10}') == "ffff" ]; then
		$i 0x15 >> SE.log
		echo " Get Last Processed Event ID Command finished"|tee -a SE.log
	else
		$i 0x15 >> SE.log
		echo " Get Last Processed Event ID Command finished , but Set Last Processed Event ID Command failed "|tee -a SE.log
		$FailCounter=$(($FailCounter+1))
	fi
fi
echo ""
# raw 0x04 0x16
echo " Alert Immediate Command" |tee -a SE.log
echo " Response below :" |tee -a  SE.log
# Set PEF alert destination selector 01
ipmitool raw 0x0c 0x01 $Ch 0x12 0x01 0x00 0x00 0x00 # Set set destination 1
ipmitool raw 0x0c 0x01 $Ch 0x13 0x01 0x00 0x00 $CliIP $CliMAC # Set alert destination 1 IPaddr and MAC
#ipmitool raw 0x0c 0x01 $Ch 0x00 0x02 # Set commit write(optional)
ipmitool raw 0x0c 0x01 $Ch 0x00 0x00 # Set Complete

# Send alert immediately to destination 1
$i 0x16 $Ch 0x01 0x00 
if [ ! $?==0 ] ; then
	$i 0x16 $Ch 0x01 0x00 >> SE.log
	echo " Send alert Immediately to destination selector 1 failed "|tee -a SE.log
	$FailCounter=$(($FailCounter+1))
else
	$i 0x16 $Ch 0x01 0x00 >> SE.log
	echo " Send alert Immediately to destination selector 1 finished"|tee -a SE.log
fi
# 打到一半
echo ""
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
