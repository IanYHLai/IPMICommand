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
echo -e "${color_convert}*This script will test one of the sensors to verify the command implemented or not.*${color_reset}"
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
read ER1 ER2 <<< $($i 0x01)
$i 0x00 0x20 0x00
if [ ! $? -eq '0' ] ; then
	$i 0x00 0x20 0x00 >> SE.log
	echo -e "${color_red} Set Event Receiver failed${color_reset}" | tee -a SE.log
	FailCounter=$(($FailCounter+1))
else
	$i 0x00 0x20 0x00>> SE.log
	echo -e "${color_green} Set Event Receiver to Slave Address=0x20 and LUN=0x00 finished${color_reset} " |tee -a SE.log
	echo " Restore default event receiver value..."
	$i 0x00 0x$ER1 0x$ER2
	echo " Restore finished..."
fi

# raw 0x04 0x01
echo ""
echo " Get Event Receiver" |tee -a  SE.log
echo " Response below :" |tee -a  SE.log
$i 0x01
if [ ! $? -eq '0' ] ; then
	$i 0x01 >> SE.log
	echo -e "${color_red} Get Event Receiver failed${color_reset}" |tee -a SE.log
	FailCounter=$(($FailCounter+1))
else
	$i 0x01 >> SE.log
	read ER1 ER2 <<< $($i 0x01)
	for j in ER{1..2}; do
		eval temp=\$$j
		temp=${D2B[$((16#$temp))]}
		read $j'b1' $j'b2' $j'b3' $j'b4' $j'b5' $j'b6' $j'b7' $j'b8' <<< "${temp:0:1} ${temp:1:1} ${temp:2:1} ${temp:3:1} ${temp:4:1} ${temp:5:1} ${temp:6:1} ${temp:7:1}"
	done
	if [ $ER1 -eq 'ff' ];then
		echo -e " Event Message Generation has been disabled."|tee -a SE.log
	else
		echo -e " Event Receiver Slave Address = 0x$ER1"|tee -a SE.log
	fi
	echo -e " Event Receiver LUN = 0x$ER2"|tee -a SE.log
	echo -e " ${color_green}Get Event Receiver finished ${color_reset}" |tee -a  SE.log
fi

# raw 0x04 0x02 This command need to check the sensor name , ID, type, event data suggest that manual testing for high testing quality
echo ""
echo " Platform Event Message Command" |tee -a  SE.log
echo " Response below :" |tee -a  SE.log
$i 0x02 0x04 $ST $SID $ET 0x00 0x00 0x00
if [ ! $? -eq '0' ] ; then
	echo -e " ${color_red}Platform Event Message Command failed${color_reset}" |tee -a SE.log
	$i 0x02 0x04 $ST $SID $ET 0x00 0x00 0x00 >> SE.log
	FailCounter=$(($FailCounter+1))
else
	$i 0x02 0x04 $ST $SID $ET 0x00 0x00 0x00 >> SE.log
	echo -e " ${color_green}Platform Event Message Command finished, check whether the SEL log is consisstent with sensor name and event data please...${color_reset}" |tee -a  SE.log
	ipmitool sel elist |tee -a SE.log
fi

# raw 0x04 0x10
echo " Get PEF Capabilities Command" |tee -a  SE.log
echo " Response below :" |tee -a SE.log
$i 0x10
if [ ! $? -eq '0' ] ; then
	echo -e " ${color_red}Get PEF Capabilities Command failed ${color_reset}"|tee -a SE.log
	$i 0x10 >> SE.log
	FailCounter=$(($FailCounter+1))
else
	$i 0x10 >> SE.log
	read PC1 PC2 PC3 <<< $($i 0x10)
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
		echo -e "${color_red}The bit 6 is holding, this bit is reserved, check the spec please...${color_reset}"|tee -a SE.log
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
	echo -e "Number of event filter table entries = $((16#$PC3))"|tee -a SE.log
	echo -e "${color_green} Get PEF Capabilities Command finished${color_reset}"|tee -a SE.log
fi

# raw 0x04 0x11
echo ""
echo " Arm PEF Postpone Timer Command"|tee -a SE.log
echo " Response below :" |tee -a SE.log
$i 0x11 0x05
if [ ! $? -eq '0' ] ; then
	$i 0x11 0x05 >> SE.log
	echo -e " ${color_red}Set Arm PEF Postpone Timer Command failed ${color_reset}"|tee -a SE.log
	FailCounter=$(($FailCounter+1))
else
	$i 0x11 0x05 >> SE.log
	echo -e "${color_green} Set Arm PEF Postpone Timer 5 seconds finished ${color_reset}"|tee -a SE.log
fi

# raw 0x04 0x12
echo " Set PEF Configuration Parameters Command" |tee -a SE.log
echo " Set all PEF action disable "|tee -a SE.log
echo " Response below :" |tee -a  SE.log
# Set all PEF action disable
$i 0x12 0x02 0x00
if [ ! $? -eq '0' ] ; then
	$i 0x12 0x02 0x00>> SE.log
	echo -e " ${color_red}Set all PEF action disable failed ${color_reset}"|tee -a SE.log
	FailCounter=$(($FailCounter+1))
else
	if [ ! "$($i 0x13 0x02 0x00 0x00)" == " 11 00" ]; then
		echo -e "${color_red} Set all PEF action disable failed the response of get configuration doesn't match the setting${color_reset}"|tee -a SE.log
		FailCounter=$(($FailCounter+1))
	else
		$i 0x12 0x02 0x00 >> SE.log
		echo -e "${color_green} Set all PEF action disable finished${color_reset}"|tee -a SE.log	
	fi
fi

# raw 0x04 0x13
echo " Get PEF Configuration Parameters Command "|tee -a SE.log
echo " Get PEF set in progress state "|tee -a SE.log
echo " Response below :"|tee -a SE.log
# Get PEF set in progress state
$i 0x13 0x00 0x00 0x00
if [ ! $? -eq '0' ] ; then
	$i 0x13 0x00 0x00 0x00>> SE.log
	echo -e "${color_red} Get PEF set in progress state failed ${color_reset}"|tee -a SE.log
	FailCounter=$(($FailCounter+1))
else
	read GP1 GP2 <<< $($i 0x13 0x00 0x00 0x00)
	for j in GP{1..2}; do
		eval temp=\$$j
		temp=${D2B[$((16#$temp))]}
		read $j'b1' $j'b2' $j'b3' $j'b4' $j'b5' $j'b6' $j'b7' $j'b8' <<< "${temp:0:1} ${temp:1:1} ${temp:2:1} ${temp:3:1} ${temp:4:1} ${temp:5:1} ${temp:6:1} ${temp:7:1}"
	done
	$i 0x13 0x00 0x00 0x00 >> SE.log
	echo -e "The parameter revision is $GP1 (MSN=present revision. LSN = oldest revision parameter is backward compatible with. 11h for parameters in this specification.)"|tee -a SE.log
	case $GP2b7$GP2b8 in 
		00) echo -e " Now is set complete state"|tee -a SE.log;;
		01) echo -e " Now is set in progress state"|tee -a SE.log;;
		10) echo -e " Now is commit write state"|tee -a SE.log;;
		11) echo -e "${color_red} The state now is reserved please check whether the spec defined or not...${color_reset}"|tee -a SE.log;;
	esac
	echo -e "${color_green} Get PEF set in progress state finished${color_reset}"|tee -a SE.log	
fi

# raw 0x04 0x14
echo " Set Last Processed Event ID Command"|tee -a SE.log
echo " Response below :"|tee -a SE.log
echo " Set Last Processed Event ID of BMC to ffff "|tee -a SE.log
$i 0x14 0x01 0xff 0xff
if [ ! $? -eq '0' ] ; then
	$i 0x14 0x01 0xff 0xff>> SE.log
	echo -e " ${color_red}Set Last Processed Event ID of BMC to ffff failed ${color_reset}"|tee -a SE.log
	FailCounter=$(($FailCounter+1))
else
	$i 0x14 0x01 0xff 0xff >> SE.log
	echo -e "${color_green} Set Last Processed Event ID of BMC to ffff finished${color_reset}"|tee -a SE.log
fi
echo ""
# raw 0x04 0x15
echo " Get Last Processed Event ID Command" |tee -a  SE.log
echo " Response below :" |tee -a SE.log
$i 0x15
if [ ! $? -eq '0' ] ; then
	$i 0x15 >> SE.log
	echo -e "${color_red} Get Last Processed Event ID Command failed ${color_reset}"|tee -a SE.log
	FailCounter=$(($FailCounter+1))
else
	if [ $($i 0x15 |awk '{print$9$10}') == "ffff" ]; then
		$i 0x15 >> SE.log
		echo -e "${color_green} Get Last Processed Event ID Command finished${color_reset}"|tee -a SE.log
	else
		$i 0x15 >> SE.log
		echo -e "${color_red} Get Last Processed Event ID Command finished , but Set Last Processed Event ID Command failed ${color_reset}"|tee -a SE.log
		FailCounter=$(($FailCounter+1))
	fi
fi
echo ""
# raw 0x04 0x16
echo " Alert Immediate Command" |tee -a SE.log
echo " Response below :" |tee -a  SE.log
# Send alert immediately to destination 1 with volatile string
$i 0x16 $Ch 0x01 0x80 0x00
if [ ! $? -eq '0' ] ; then
	$i 0x16 $Ch 0x01 0x80 0x00 >> SE.log
	echo -e "${color_red} Send alert Immediately to destination selector 1 failed ${color_reset}"|tee -a SE.log
	FailCounter=$(($FailCounter+1))
else
	$i 0x16 $Ch 0x01 0x80 0x00 >> SE.log
	echo -e "${color_green} Send alert Immediately to destination selector 1 finished${color_reset}"|tee -a SE.log
fi
# 
echo ""
# raw 0x04 0x20
echo " Get Device SDR Info Command" |tee -a SE.log
echo " Response below :" |tee -a SE.log
$i 0x20 0x01 #get SDR count 0x01 get SDR count
if [ ! $? -eq '0' ] ; then
	$i 0x20 0x01>> SE.log
	echo -e "${color_red} Get Device SDR Info SDR count failed${color_reset}"|tee -a SE.log
	FailCounter=$(($FailCounter+1))
else
	read GD1 GD2 GD3 GD4 GD5 GD6 <<< $($i 0x20 0x01)
	for j in GD{1..6}; do
		eval temp=\$$j
		temp=${D2B[$((16#$temp))]}
		read $j'b1' $j'b2' $j'b3' $j'b4' $j'b5' $j'b6' $j'b7' $j'b8' <<< "${temp:0:1} ${temp:1:1} ${temp:2:1} ${temp:3:1} ${temp:4:1} ${temp:5:1} ${temp:6:1} ${temp:7:1}"
	done
	read GDs1 null <<< $($i 0x20 0x00)
	$i 0x20 0x01 >> SE.log
	echo -e " There are $((16#$GDs1)) sensors implemented on LUN in SUT."|tee -a SE.log
	echo -e " There are $((16#$GD1)) SDRs in SUT."|tee -a SE.log
	if [ $GD2b1 -eq '1' ];then 
		echo " Dynamic sensor population. This device may have its sensor population vary during ‘run time’ (defined as any time other that when an install operation is in progress)."|tee -a SE.log
		echo " The Sensor Population Change Indicator is $GD3$GD4$GD5$GD6 (LS byte first.Four byte timestamp, or counter check the spec please.)"
	else 
		echo " Static sensor population. The number of sensors handled by this device is fixed, and a query shall return records for all sensors."|tee -a SE.log
	fi
	if [ $GD2b5 -eq '1' ];then
		echo "LUN 3 has sensors."|tee -a SE.log
	fi
	if [ $GD2b6 -eq '1' ];then
		echo "LUN 2 has sensors."|tee -a SE.log
	fi
	if [ $GD2b7 -eq '1' ];then
		echo "LUN 1 has sensors."|tee -a SE.log
	fi
	if [ $GD2b8 -eq '1' ];then
		echo "LUN 0 has sensors."|tee -a SE.log
	fi
	echo -e "${color_green} Get Device SDR count Info SDR count finished.${color_reset}"|tee -a SE.log
fi

echo ""

# raw 0x04 0x21  0x0a 0x23 有差?
echo " Get Device SDR Command" |tee -a  SE.log
echo " Response below :" |tee -a SE.log
$i 0x21 0x00 0x00 0x00 0x00 0x00 0xff #get SDR that offset 0x00
if [ ! $? -eq '0' ] ; then
	$i 0x21 0x00 0x00 0x00 0x00 0x00 0xff>> SE.log
	echo -e "${color_red} Get Device SDR Command failed ${color_reset}"|tee -a SE.log
	FailCounter=$(($FailCounter+1))
else
	$i 0x21 0x00 0x00 0x00 0x00 0x00 0xff >> SE.log
	echo -e " Get Device SDR Command finished${color_reset}"|tee -a SE.log
fi

# raw 0x04 0x22
echo " Reserve Device SDR Repository Command"|tee -a SE.log
echo " Response below :" |tee -a  SE.log
$i 0x22 
if [ ! $? -eq '0' ] ; then
	$i 0x22 >> SE.log
	echo -e "${color_red} Reserve Device SDR Repository Command failed ${color_reset}"|tee -a SE.log
	FailCounter=$(($FailCounter+1))
else
	$i 0x22 >> SE.log
	read RS1 RS2 <<< $($i 0x22)
	for j in RS{1,2}; do
		eval temp=\$$j
		temp=${D2B[$((16#$temp))]}
		read $j'b1' $j'b2' $j'b3' $j'b4' $j'b5' $j'b6' $j'b7' $j'b8' <<< "${temp:0:1} ${temp:1:1} ${temp:2:1} ${temp:3:1} ${temp:4:1} ${temp:5:1} ${temp:6:1} ${temp:7:1}"
	done
	echo " Reserve a SDR Repository ID = $RS2$RS1"
	echo -e "${color_green} Reserve Device SDR Repository Command finished${color_reset}"|tee -a SE.log
fi

# raw 0x04 0x23
#echo Get Sensor Reading Factors Command >> SE.log
#echo "Response below :" >> SE.log
#$i 0x23 0x10  # sensor ID 10h
#if [ ! $? == 0 ] ; then
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
if [ ! $? -eq '0' ] ; then
	$i 0x24 $SID 0xff 0x00 0x00 >> SE.log
	echo -e "${color_red} Set Sensor Hysteresis Command failed ${color_reset}"|tee -a SE.log
	FailCounter=$(($FailCounter+1))
else
	$i 0x24 $SID 0xff 0x00 0x00>> SE.log
	echo -e "${color_green} Set Sensor Hysteresis Command finished"|tee -a SE.log
	echo " Restore default setting...."
	$i 0x24 $SID 0xff 0x$resH1 0x$resH2
	echo " Restore setting fnished...."
fi

# raw 0x04 0x25
echo " Get Sensor Hysteresis Command"|tee -a  SE.log
echo " Response below :" |tee -a SE.log
$i 0x25 $SID 0xff
if [ ! $?==0 ] ; then
	$i 0x25 $SID >> SE.log
	echo -e "${color_red} Get Sensor Hysteresis Command failed ${color_reset}"|tee -a SE.log
	FailCounter=$(($FailCounter+1))
else
	$i 0x25 $SID>> SE.log
	read GS1 GS2 <<< $($i 0x25 $SID)
	for j in GS{1..2}; do
		eval temp=\$$j
		temp=${D2B[$((16#$temp))]}
		read $j'b1' $j'b2' $j'b3' $j'b4' $j'b5' $j'b6' $j'b7' $j'b8' <<< "${temp:0:1} ${temp:1:1} ${temp:2:1} ${temp:3:1} ${temp:4:1} ${temp:5:1} ${temp:6:1} ${temp:7:1}"
	done
	if [ ! $GS1 -eq '0' ];then
		echo "Positive-going Threshold Hysteresis = $GS1"|tee -a SE.log
	else
		echo "Positive-going Threshold Hysteresis is N/A"|tee -a SE.log
	fi
	if [ ! $GS2 -eq '0' ];then
		echo "Negative-going Threshold Hysteresis = $GS2"|tee -a SE.log
	else
		echo "Negative-going Threshold Hysteresis is N/A"|tee -a SE.log
	fi
	
	echo -e "${color_green} Get Sensor Hysteresis Command finished${color_reset}"|tee -a SE.log
fi

# raw 0x04 0x26
#echo Set Sensor Thresholds Command >> SE.log
#echo "Response below :" >> SE.log
#$i 0x26 $SID 
#if [ ! $?==0 ] ; then
#	echo Set Sensor Thresholds Command failed 
#	$i 0x26 $SID >> SE.log
#	echo " Set Sensor Thresholds Command $i 0x26 fail " >> SE.log
#	FailCounter=$(($FailCounter+1))
#else
#	echo Set Sensor Thresholds Command success
#	$i 0x26 $SID >> SE.log
#	echo " Set Sensor Thresholds Command $i 0x26 success " >> SE.log
#fi

# raw 0x04 0x27
echo " Get Sensor Thresholds Command " | tee -a SE.log
echo " Response below :" | tee -a SE.log
$i 0x27 $SID 
if [ ! $? -eq '0' ] ; then
	$i 0x27 $SID >> SE.log
	echo -e "${color_red} Get Sensor Thresholds Command failed ${color_reset}" | tee -a SE.log
	FailCounter=$(($FailCounter+1))
else
	$i 0x27 $SID >> SE.log
	echo -e "${color_green} Get Sensor Thresholds Command finished${color_reset}"|tee -a SE.log
fi

# raw 0x04 0x28 
echo " Set Sensor Event Enable Command" |tee -a SE.log
echo " Response below :" |tee -a SE.log
SEE=$($i 0x29 $SID)
IFS=' ' read SEE1 SEE2 SEE3 SEE4 SEE5 SEE6 <<< "$SEE"
$i 0x28 $SID 0xc0 0x$SEE2 0x$SEE3 0x$SEE4 0x$SEE5 0x$SEE6
if [ ! $? -eq '0' ] ; then
	$i 0x28 $SID 0xc0 0x$SEE2 0x$SEE3 0x$SEE4 0x$SEE5 0x$SEE6 >> SE.log
	echo -e "${color_red} Set Sensor Event Enable Command failed ${color_reset}" | tee -a SE.log
	FailCounter=$(($FailCounter+1))
else
	if [[ "$($i 0x29 $SID)"=="0xc0 $SEE2 $SEE3 $SEE4 $SEE5 $SEE6" ]]
		$i 0x28 $SID 0xc0 0x$SEE2 0x$SEE3 0x$SEE4 0x$SEE5 0x$SEE6 >> SE.log
		echo -e "${color_green} Set Sensor Thresholds Command finished ${color_reset}"|tee -a SE.log
	else
		$i 0x28 $SID 0xc0 0x$SEE2 0x$SEE3 0x$SEE4 0x$SEE5 0x$SEE6 >> SE.log
		echo -e "${color_red} Set Sensor Event Enable Command failed ${color_reset}" |tee -a SE.log
		FailCounter=$(($FailCounter+1))
	fi
fi

# raw 0x04 0x2a rearm all event status
echo " Re-arm Sensor Events Command" |tee -a SE.log
echo " Response below :" |tee -a SE.log
$i 0x2a $SID 0x00
if [ ! $?==0 ] ; then
	$i 0x2a $SID 0x00 >> SE.log
	echo -e " ${color_red}Re-arm Sensor Events Command failed ${color_reset}"|tee -a SE.log
	FailCounter=$(($FailCounter+1))
else
	$i 0x2a $SID 0x00 >> SE.log
	echo -e "${color_green} Re-arm Sensor Events Command finished${color_reset}"|tee -a SE.log
fi

# raw 0x04 0x2b
echo " Get Sensor Event Status Command" |tee -a SE.log
echo " Response below :" |tee -a SE.log
$i 0x2b $SID
if [ ! $?==0 ] ; then
	$i 0x2b $SID >> SE.log
	echo -e "${color_red} Get Sensor Event Status Command failed ${color_reset}"|tee -a SE.log
	FailCounter=$(($FailCounter+1))
else
	$i 0x2b $SID >> SE.log
	echo -e "${color_green} Get Sensor Event Status Command finished ${color_reset}"|tee -a SE.log
fi

# raw 0x04 0x2d
echo " Get Sensor Reading Command" |tee -a SE.log
echo " Response below :" |tee -a SE.log
$i 0x2d $SID
if [ ! $?==0 ] ; then
	$i 0x2d $SID >> SE.log
	echo -e "${color_red} Get Sensor Reading Command failed ${color_reset}" |tee -a SE.log
	FailCounter=$(($FailCounter+1))
else
	#############################################
	read GSR1 GSR2 GSR3 GSR4 <<< $($i 0x20 0x01)
	for j in GSR{1..4}; do
		eval temp=\$$j
		temp=${D2B[$((16#$temp))]}
		read $j'b1' $j'b2' $j'b3' $j'b4' $j'b5' $j'b6' $j'b7' $j'b8' <<< "${temp:0:1} ${temp:1:1} ${temp:2:1} ${temp:3:1} ${temp:4:1} ${temp:5:1} ${temp:6:1} ${temp:7:1}"
	done
	#############################################
	if [  ];then
	fi
	$i 0x2d $SID >> SE.log
	echo -e "${color_green} Get Sensor Reading Command finished${color_reset}"|tee -a SE.log
fi

# raw 0x04 0x2f
echo Get Sensor Type Command >> SE.log
echo "Response below :" >> SE.log
$i 0x2f $SID
if [ ! $?==0 ] ; then
	echo Get Sensor Type Command failed 
	$i 0x2f $SID >> SE.log
	echo " Get Sensor Type Command $i 0x2f fail " >> SE.log
	FailCounter=$(($FailCounter+1))
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
	FailCounter=$(($FailCounter+1))
else
	echo Set Sensor Type Command success
	$i 0x2e $SID >> SE.log
	echo " Set Sensor Type Command $i 0x2e success " >> SE.log
fi

if [ ! $FailCounter == 0 ]; then
	echo -e "${color+red} Sensor&Event function test finished but has some command failed check the log please.${color_reset}" |tee -a SE.log
else
	echo -e "${color_green} Sensor&Event function test finished.${color_reset}" |tee -a SE.log
fi
