#!/bin/bash

# Set response color
color_reset='\e[0m'
color_green='\e[32m'
color_red='\e[31m'
color_convert='\e[7m'
color_blue='\e[34m'
echo -e "$color_redRemove and backup the previous log as date format...${color_reset}"
if [ -f "SE.log" ]; then
	cp SE.log $(date +%Y%m%d_%T)_SE.log && rm -f SE.log
fi

date |tee -a SE.log

echo -e "${color_convert}*This script will test one of the sensors to verify the command implemented or not.*${color_reset}"
read OSInfo <<< $(cat /etc/redhat-release)
echo "$USER start S/E testing in $OSInfo "|tee -a SE.log

i="ipmitool raw 0x04"
sleep 1
ipmitool sdr elist | awk '{ print $1 }' > SName.txt
ipmitool sdr elist | awk '{ print $2 }' | cut -d 'h' -f 1 > SNum.txt
while read line 
	do 
		ipmitool sdr get $line >> SDR.txt
		#echo $line >> SType.txt
		ipmitool sdr get $line |grep -i Type|awk -F\: '{print $2}' | awk -F "(" {'print $2'} | cut -d ')' -f 1 >> SType.txt
		ipmitool sdr get $line |grep -i Type|awk -F\: '{print $2}' | awk -F "(" {'print $2'} | cut -d ')' -f 1 >> ForTest.txt
		ipmitool sdr elist | awk '{ print $2 }' | cut -d 'h' -f 1 >> ForTest.txt
		read temp <<< $(ipmitool sdr get $line| grep -i "sensor id"|awk -F'(' '{ print $2 }' | cut -d ')' -f 1)
		ipmitool raw 0x04 0x2f $temp|awk -F' ' '{print $2}' >> ForTest.txt
		ipmitool raw 0x04 0x2f $temp|awk -F' ' '{print $2}' >> EType.txt
		echo "" >> ForTest.txt
	done < SName.txt

#read -p "Please input BMC channel number(with 0xFF format) :" Ch
Ch=0x0f
#read -p "Please input sensor name for testing(with no quotes like CPU_CUPS) :" SN 
#read -p "Please input sensor type of $SN(with 0xFF format) :" ST
#read -p "Please input event type of $SN(with 0xFF format) :" ET
#read -p "Please input alert destination IPaddr(IPv4 like 127.0.0.1) :" CliIP
CliIP=192.168.1.100
#read -p "Please input alert destination MACaddr(with '-' format like 01-02-03-04-05-06) :" CliMAC
CliMAC="00-0C-29-1B-79-A0"
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
CliIP="0x$ip1 0x$ip2 0x$ip3 0x$ip4"

## Convert MAC format
IFS=- read mac1 mac2 mac3 mac4 mac5 mac6 <<< "$CliMAC"
CliMAC="0x$mac1 0x$mac2 0x$mac3 0x$mac4 0x$mac5 0x$mac6"

#SID=0x$(ipmitool sdr elist | grep -i "$SN" | awk -F\| '{print$2}' | cut -c 2-3) #with SN (sensor name) to search the sdr elist then cut the sensor ID to perform like 0xXX and save into $SID.

FailCounter=0
echo "Current ipmitool Channel=$Ch Client ip=$CliIP Client Mac=$CliMAC"|tee -a SE.log

## Start the test
# raw 0x04 0x00
echo ""|tee -a SE.log
echo " Set Event Receiver" |tee -a  SE.log
echo " Response below :" |tee -a  SE.log
read ER1 ER2 <<< $($i 0x01)
$i 0x00 0x20 0x00
if [ ! $? -eq '0' ] ; then
	$i 0x00 0x20 0x00 >> SE.log
	echo -e "${color_red} Set Event Receiver failed${color_reset}" | tee -a SE.log
	FailCounter=$(($FailCounter+1))
else
	$i 0x00 0x20 0x00 >> SE.log
	echo -e "${color_blue} Set Event Receiver to Slave Address=0x20 and LUN=0x00 finished${color_reset} " |tee -a SE.log
	echo " Restore default event receiver value..."
	$i 0x00 0x$ER1 0x$ER2
	echo " Restore finished..."
fi

# raw 0x04 0x01
echo " "|tee -a SE.log
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
	if [ $ER1=='ff' ];then
		echo -e " Event Message Generation has been ${color_red}disabled${color_reset}."|tee -a SE.log
	else
		echo -e " Event Receiver Slave Address = ${color_green}0x$ER1${color_reset}"|tee -a SE.log
	fi
	echo -e " Event Receiver LUN = ${color_green}0x$ER2${color_reset}"|tee -a SE.log
	echo -e " ${color_blue}Get Event Receiver finished ${color_reset}" |tee -a  SE.log
fi

# raw 0x04 0x02 This command need to check the sensor name , ID, type, event data suggest that manual testing for high testing quality
#echo ""|tee -a SE.log
#echo " Platform Event Message Command" |tee -a  SE.log
#echo " Response below :" |tee -a  SE.log
#$i 0x02 0x20 0x04 $ST $SID $ET 0x00 0x00 0x00
#if [ ! $? -eq '0' ] ; then
#	$i 0x02 0x20 0x04 $ST $SID $ET 0x00 0x00 0x00 >> SE.log
#	echo -e " ${color_red}Platform Event Message Command failed${color_reset}" |tee -a SE.log
#	FailCounter=$(($FailCounter+1))
#else
#	$i 0x02 0x20 0x04 $ST $SID $ET 0x00 0x00 0x00 >> SE.log
#	echo -e " ${color_blue}Platform Event Message Command finished, check whether the SEL log is consisstent with sensor name and event data please...${color_reset}" |tee -a  SE.log
#	ipmitool -v sel elist |tee -a SE.log
#fi

# raw 0x04 0x10
echo ""|tee -a SE.log
echo " Get PEF Capabilities Command" |tee -a  SE.log
echo " Response below :" |tee -a SE.log
$i 0x10
if [ ! $? -eq '0' ] ; then
	$i 0x10 >> SE.log
	echo -e " ${color_red}Get PEF Capabilities Command failed ${color_reset}"|tee -a SE.log
	FailCounter=$(($FailCounter+1))
else
	$i 0x10 >> SE.log
	read PC1 PC2 PC3 <<< $($i 0x10)
	for j in PC{1..3}; do
		eval temp=\$$j
		temp=${D2B[$((16#$temp))]}
		read $j'b1' $j'b2' $j'b3' $j'b4' $j'b5' $j'b6' $j'b7' $j'b8' <<< "${temp:0:1} ${temp:1:1} ${temp:2:1} ${temp:3:1} ${temp:4:1} ${temp:5:1} ${temp:6:1} ${temp:7:1}"
	done
	
	echo -e " The PEF version is ${color_green}$PC1${color_reset}(hex), it's LSN first, 51h > version 1.5"|tee -a SE.log
	if [ $PC2b1 -eq '1' ];then
		echo -e " ${color_green}OEM Event Record Filtering supported${color_reset}"|tee -a SE.log
	else 
		echo -e " ${color_red}OEM Event Record Filtering not supported${color_reset}"|tee -a SE.log
	fi
	if [ $PC2b2 -eq '1' ];then
		echo -e "${color_red}The bit 6 is holding, this bit is reserved, check the spec please...${color_reset}"|tee -a SE.log
	fi
	echo -e " ${color_convert}Action Suport :${color_reset}"|tee -a SE.log
	if [ $PC2b3 -eq '1' ];then
		echo -e " ${color_green}Diagnostic interrupt${color_reset}"|tee -a SE.log
	fi
	if [ $PC2b4 -eq '1' ];then
		echo -e " ${color_green}OEM action${color_reset}"|tee -a SE.log
	fi
	if [ $PC2b5 -eq '1' ];then
		echo -e " ${color_green}Power cycle${color_reset}"|tee -a SE.log
	fi
	if [ $PC2b6 -eq '1' ];then
		echo -e " ${color_green}Reset${color_reset}"|tee -a SE.log
	fi
	if [ $PC2b7 -eq '1' ];then
		echo -e " ${color_green}Power down${color_reset}"|tee -a SE.log
	fi
	if [ $PC2b8 -eq '1' ];then
		echo -e " ${color_green}Alert${color_reset}"|tee -a SE.log
	fi
	echo ""|tee -a SE.log
	echo -e " Number of event filter table entries = ${color_green}$((16#$PC3))${color_reset}"|tee -a SE.log
	echo -e "${color_blue} Get PEF Capabilities Command finished${color_reset}"|tee -a SE.log
fi

# raw 0x04 0x11
echo ""|tee -a SE.log
echo " Arm PEF Postpone Timer Command"|tee -a SE.log
echo " Response below :" |tee -a SE.log
$i 0x11 0x05
if [ ! $? -eq '0' ] ; then
	$i 0x11 0x05 >> SE.log
	echo -e " ${color_red}Set Arm PEF Postpone Timer Command failed ${color_reset}"|tee -a SE.log
	FailCounter=$(($FailCounter+1))
else
	$i 0x11 0x05 >> SE.log
	echo -e "${color_blue} Set Arm PEF Postpone Timer 5 seconds finished ${color_reset}"|tee -a SE.log
fi

# raw 0x04 0x12
echo ""|tee -a SE.log
echo " Set PEF Configuration Parameters Command" |tee -a SE.log
echo " Set all PEF action disable..."|tee -a SE.log
echo " Response below :" |tee -a  SE.log
# Set all PEF action disable
$i 0x12 0x02 0x00
if [ ! $? -eq '0' ] ; then
	$i 0x12 0x02 0x00>> SE.log
	echo -e " ${color_red}Set all PEF action disable failed ${color_reset}"|tee -a SE.log
	FailCounter=$(($FailCounter+1))
else
	if [ ! "$($i 0x13 0x02 0x00 0x00)"=="11 00" ]; then
		echo -e "${color_red} Set all PEF action disable failed the response of get configuration doesn't match the setting${color_reset}"|tee -a SE.log
		FailCounter=$(($FailCounter+1))
	else
		$i 0x12 0x02 0x00 >> SE.log
		echo -e "${color_blue} Set all PEF action disable finished${color_reset}"|tee -a SE.log	
	fi
	echo " Restore PEF action default setting..."
	$i 0x12 0x02 0x3f
	echo " Restore PEF action default finished..."
fi

# raw 0x04 0x13
echo ""|tee -a SE.log
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
	echo -e " The parameter revision is ${color_green}$GP1${color_reset}(MSN=present revision. LSN = oldest revision parameter is backward compatible with. 11h for parameters in this specification.)"|tee -a SE.log
	case $GP2b7$GP2b8 in 
		00) echo -e " PEF config is ${color_green}set complete state${color_reset}"|tee -a SE.log;;
		01) echo -e " PEF config is ${color_green}set in progress state${color_reset}"|tee -a SE.log;;
		10) echo -e " PEF config is ${color_green}commit write state${color_reset}"|tee -a SE.log;;
		11) echo -e "${color_red} The state now is reserved please check whether the spec defined or not...${color_reset}"|tee -a SE.log;;
	esac
	echo -e "${color_blue} Get PEF set in progress state finished${color_reset}"|tee -a SE.log	
fi

# raw 0x04 0x14
echo ""|tee -a SE.log
echo " Set Last Processed Event ID Command"|tee -a SE.log
echo " Set Last Processed Event ID of BMC to ffff "|tee -a SE.log
echo " Response below :"|tee -a SE.log
$i 0x14 0x01 0xff 0xff
if [ ! $? -eq '0' ] ; then
	$i 0x14 0x01 0xff 0xff>> SE.log
	echo -e " ${color_red}Set Last Processed Event ID of BMC to ffff failed ${color_reset}"|tee -a SE.log
	FailCounter=$(($FailCounter+1))
else
	$i 0x14 0x01 0xff 0xff >> SE.log
	echo -e "${color_blue} Set Last Processed Event ID of BMC to ffff finished${color_reset}"|tee -a SE.log
fi
echo ""|tee -a SE.log
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
		echo -e "${color_blue} Get Last Processed Event ID Command finished${color_reset}"|tee -a SE.log
	else
		$i 0x15 >> SE.log
		echo -e "${color_red} Get Last Processed Event ID Command finished , but Set Last Processed Event ID Command failed ${color_reset}"|tee -a SE.log
		FailCounter=$(($FailCounter+1))
	fi
fi
echo ""|tee -a SE.log
# raw 0x04 0x16
echo " Alert Immediate Command" |tee -a SE.log
echo " Response below :" |tee -a  SE.log
# Send alert immediately to destination 1 with volatile string
$i 0x16 $Ch 0x80 0x00
if [ ! $? -eq '0' ] ; then
	$i 0x16 $Ch 0x80 0x00 >> SE.log
	echo -e "${color_red} Send alert Immediately to destination selector 1 failed ${color_reset}"|tee -a SE.log
	FailCounter=$(($FailCounter+1))
else
	$i 0x16 $Ch 0x80 0x00 >> SE.log
	echo -e "${color_blue} Send alert Immediately to destination selector 1 finished${color_reset}"|tee -a SE.log
fi

echo ""|tee -a SE.log
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
	echo -e " There are ${color_green}$((16#$GDs1))${color_reset} sensors implemented on LUN in SUT."|tee -a SE.log
	echo -e " There are ${color_green}$((16#$GD1))${color_reset} SDRs in SUT."|tee -a SE.log
	if [ $GD2b1 -eq '1' ];then 
		echo -e " ${color_green}Dynamic sensor population${color_reset}. This device may have its sensor population vary during ‘run time’ (defined as any time other that when an install operation is in progress)."|tee -a SE.log
		echo -e " The Sensor Population Change Indicator is ${color_green}$GD3$GD4$GD5$GD6${color_resset} (LS byte first.Four byte timestamp, or counter check the spec please.)"
	else 
		echo -e " ${color_green}Static sensor population${color_reset}. The number of sensors handled by this device is fixed, and a query shall return records for all sensors."|tee -a SE.log
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
	echo -e "${color_blue} Get Device SDR count Info SDR count finished.${color_reset}"|tee -a SE.log
fi

echo ""|tee -a SE.log

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
	echo -e "${color_blue} Get Device SDR Command finished${color_reset}"|tee -a SE.log
fi
echo ""|tee -a SE.log
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
	echo -e "${color_blue} Reserve Device SDR Repository Command finished${color_reset}"|tee -a SE.log
fi
echo ""|tee -a SE.log

# raw 0x04 0x23
echo " Get Sensor Reading Factors Command"|tee -a SE.log
echo " Response below :" |tee -a SE.log
while read SID 
	do
		$i 0x23 0x$SID 0xff
		if [ ! $? == 0 ] ; then
		$i 0x23 0x$SID 0xff >> SE.log
		echo -e "${color_red} Get Sensor $SID Reading Factors Command failed ${color_reset}"|tee -a SE.log
		FailCounter=$(($FailCounter+1))
		else
		$i 0x23 0x$SID 0xff >> SE.log
		read SRF1 SRF2 SRF3 SRF4 SRF5 SRF6 SRF7 <<< $($i 0x23 $SID 0xff)
		for j in SRF{1..7}; do
			eval temp=\$$j
			temp=${D2B[$((16#$temp))]}
			read $j'b1' $j'b2' $j'b3' $j'b4' $j'b5' $j'b6' $j'b7' $j'b8' <<< "${temp:0:1} ${temp:1:1} ${temp:2:1} ${temp:3:1} ${temp:4:1} ${temp:5:1} ${temp:6:1} ${temp:7:1}"
		done
		read SRR null <<< $($i 0x2d $SID)
		echo " Linear formula : y = L [ (M * x + (B * 10^K1)) * 10^K2 ] units"|tee -a SE.log
		echo " Tolerance formula : y = L[Mx/2 * 10K2 ] units"|tee -a SE.log
		echo -e " Next reading is ${color_green}$SRF1${color_reset}, indicates the next reading for which a different set of sensor reading factors is defined"|tee -a SE.log
		echo -e " Parameter 'x' = ${color_green}$((16#$SRR))${color_reset}"|tee -a SE.log
		echo -e " Parameter 'M' = ${color_green}$((2#$SRF3b1$SRF3b2$SRF2b1$SRF2b2$SRF2b3$SRF2b4$SRF2b5$SRF2b6$SRF2b7$SRF2b8))${color_reset}"|tee -a SE.log
		echo -e " Parameter 'B' = ${color_green}$((2#$SRF5b1$SRF5b2$SRF4b1$SRF4b2$SRF4b3$SRF4b4$SRF4b5$SRF4b6$SRF4b7$SRF4b8))${color_reset}"|tee -a SE.log
		K1=$((2#$SRF7b5$SRF7b6$SRF7b7$SRF7b8))
		K2=$((2#$SRF7b1$SRF7b2$SRF7b3$SRF7b4))
		[ "$K2" -gt 127 ] && ((K2=$K2-256)); echo -e " Parameter 'K2' = ${color_green}$K2${color_reset}"|tee -a SE.log
		[ "$K1" -gt 127 ] && ((K1=$K1-256)); echo -e " Parameter 'K1' = ${color_green}$K1${color_reset}"|tee -a SE.log
		echo -e " Tolerance in +/- ½raw counts is ${color_green}$((2#$SRF3b3$SRF3b4$SRF3b5$SRF3b6$SRF3b7SRF3b8))${color_reset}"|tee -a SE.log
		echo -e " Basic Sensor Accuracy in 1/100 percent is ${color_green}$((2#$SRF6b1$SRF6b2$SRF6b3$SRF6b4$SRF5b3$SRF5b4$SRF5b5$SRF5b6$SRF5b7$SRF5b8))${color_reset}" 
		echo -e " ${color_blue}Get Sensor $SID Reading Factors Command finished ${color_reset}"|tee -a SE.log	
	fi
done < SNum.txt
echo ""|tee -a SE.log

# raw 0x04 0x24
echo " Set Sensor Hysteresis Command" |tee -a SE.log
echo " Response below :" |tee -a SE.log
while read SID
	do
		read resH1 resH2 <<< $($i 0x25 $SID 0xff)
		echo $resH1 $resH2
		$i 0x24 0x$SID 0xff 0x00 0x00 
		if [ ! $? -eq '0' ] ; then
			$i 0x24 0x$SID 0xff 0x00 0x00 >> SE.log
			echo -e "${color_red} Set Sensor Hysteresis Command failed ${color_reset}"|tee -a SE.log
			FailCounter=$(($FailCounter+1))
		else
			$i 0x24 0x$SID 0xff 0x00 0x00 >> SE.log
			echo -e "${color_blue} Set Sensor Hysteresis Command finished ${color_reset}"|tee -a SE.log
			echo " Restore default setting...."
			$i 0x24 0x$SID 0xff 0x$resH1 0x$resH2 
			echo " Restore setting fnished...."
		fi
	done < SNum.txt
echo ""|tee -a SE.log

# raw 0x04 0x25
echo " Get Sensor Hysteresis Command"|tee -a  SE.log
echo " Response below :" |tee -a SE.log
while read SID
	do
		$i 0x25 $SID 0xff
		if [ ! $?==0 ] ; then
			$i 0x25 $SID 0xff >> SE.log
			echo -e "${color_red} Get Sensor Hysteresis Command failed ${color_reset}"|tee -a SE.log
			FailCounter=$(($FailCounter+1))
		else
			$i 0x25 $SID 0xff >> SE.log
			read GS1 GS2 <<< $($i 0x25 $SID 0xff)
			for j in GS{1..2}; do
				eval temp=\$$j
				temp=${D2B[$((16#$temp))]}
				read $j'b1' $j'b2' $j'b3' $j'b4' $j'b5' $j'b6' $j'b7' $j'b8' <<< "${temp:0:1} ${temp:1:1} ${temp:2:1} ${temp:3:1} ${temp:4:1} ${temp:5:1} ${temp:6:1} ${temp:7:1}"
			done
			if [ ! $GS1 -eq '0' ];then
				echo -e " Positive-going Threshold Hysteresis = ${color_green}$GS1${color_reset}"|tee -a SE.log
			else
				echo " Positive-going Threshold Hysteresis is N/A"|tee -a SE.log
			fi
			if [ ! $GS2 -eq '0' ];then
				echo -e " Negative-going Threshold Hysteresis = ${color_green}$GS2${color_reset}"|tee -a SE.log
			else
				echo " Negative-going Threshold Hysteresis is N/A"|tee -a SE.log
			fi
			echo -e "${color_blue} Get Sensor Hysteresis Command finished${color_reset}"|tee -a SE.log
		fi
	done < SNum.txt
echo ""|tee -a SE.log

# raw 0x04 0x27
echo " Get Sensor Thresholds Command " | tee -a SE.log
echo " Response below :" | tee -a SE.log
while read SID
	do
		$i 0x27 $SID 
		if [ ! $? -eq '0' ] ; then
			$i 0x27 $SID >> SE.log
			echo -e "${color_red} Get Sensor Thresholds Command failed ${color_reset}" | tee -a SE.log
			FailCounter=$(($FailCounter+1))
		else
			$i 0x27 $SID >> SE.log
			read GT1 GT2 GT3 GT4 GT5 GT6 GT7<<< $($i 0x27 $SID)
			for j in GT{1..7}; do
				eval temp=\$$j
				temp=${D2B[$((16#$temp))]}
				read $j'b1' $j'b2' $j'b3' $j'b4' $j'b5' $j'b6' $j'b7' $j'b8' <<< "${temp:0:1} ${temp:1:1} ${temp:2:1} ${temp:3:1} ${temp:4:1} ${temp:5:1} ${temp:6:1} ${temp:7:1}"
			done
			echo -e " ${color+green}$SN${color_reset} Readable threshold : "|tee -a SE.log
			if [ $GT1b3 -eq '1' ];then
				echo -e " Upper non-recoverable threshold = ${color_green}$((16#$GT7))${color_reset}(dec)"|tee -a SE.log
			fi
			if [ $GT1b4 -eq '1' ];then
				echo -e " upper critical threshold = ${color_green}$((16#$GT6))${color_reset}(dec)"|tee -a SE.log
			fi
			if [ $GT1b5 -eq '1' ];then
				echo -e " upper non-critical threshold = ${color_green}$((16#$GT5))${color_reset}(dec)"|tee -a SE.log
			fi
			if [ $GT1b6 -eq '1' ];then
				echo -e " lower non-recoverable threshold = ${color_green}$((16#$GT4))${color_reset}(dec)"|tee -a SE.log
			fi
			if [ $GT1b7 -eq '1' ];then
				echo -e " lower critical threshold = ${color_green}$((16#$GT3))${color_reset}(dec)"|tee -a SE.log
			fi
			if [ $GT1b8 -eq '1' ];then
				echo -e " lower non-critical threshold = ${color_green}$((16#$GT2))${color_reset}(dec)"|tee -a SE.log
			fi
			echo " "|tee -a SE.log
			echo -e "${color_blue} Get Sensor Thresholds Command finished${color_reset}"|tee -a SE.log
		fi
	done < SNum.txt
echo ""|tee -a SE.log

# raw 0x04 0x26
echo " Set Sensor Thresholds Command" |tee -a SE.log
echo " Response below :" |tee -a SE.log
while read SID
	do
		read LNC <<< $(printf %x $(((16#$GT2)+1)))
		read LCR <<< $(printf %x $(((16#$GT3)+1)))
		read LNR <<< $(printf %x $(((16#$GT4)+1)))
		read UNC <<< $(printf %x $(((16#$GT5)+1)))
		read UCR <<< $(printf %x $(((16#$GT6)+1)))
		read UNR <<< $(printf %x $(((16#$GT7)+1)))
		$i 0x26 $SID 0x$GT1 0x$LNC 0x$LCR 0x$LNR 0x$UNC 0x$UCR 0x$UNR
		if [ ! $?==0 ] ; then
			$i 0x26 $SID 0x$GT1 0x$LNC 0x$LCR 0x$LNR 0x$UNC 0x$UCR 0x$UNR >> SE.log
			echo -e "${color_red} Set Sensor Thresholds Command failed${color_reset}" |tee -a SE.log
			FailCounter=$(($FailCounter+1))
		else
			$i 0x26 $SID 0x$GT1 0x$LNC 0x$LCR 0x$LNR 0x$UNC 0x$UCR 0x$UNR >> SE.log
			echo " Please check the response manually..."|tee -a SE.log
			echo -e " ${color_green}$UNR $UCR $UNC $LNR $LCR $LNC${color_reset} check the vaule if support"|tee -a SE.log
			echo -e " ${color_green}$GT1b3 $GT1b4 $GT1b5 $GT1b6 $GT1b7 $GT1b8${color_reset} mask the threshold with '1' support."|tee -a SE.log
			ipmitool raw 0x04 0x27 $SID |tee -a SE.log
			echo -e " ${color_blue}Set Sensor Thresholds Command finished${color_reset}"|tee -a SE.log
			echo " Restore default threshold..."
			$i 0x26 $SID 0x$GT1 0x$GT2 0x$GT3 0x$GT4 0x$GT5 0x$GT6 0x$GT7
			echo " Restore finished..."
		fi
	done < SNum.txt
echo ""|tee -a SE.log

# raw 0x04 0x28 
echo " Set Sensor Event Enable Command" |tee -a SE.log
echo " Response below :" |tee -a SE.log
read SEE1 SEE2 SEE3 SEE4 SEE5 SEE6 <<< $($i 0x29 $SID)
if [ ! -z $SEE6 ];then
	$i 0x28 $SID 0xc0 0x95 0x0a 0x95 0x0a 0x$SEE6
	if [ ! $? -eq '0' ] ; then
		$i 0x28 $SID 0xc0 0x95 0x0a 0x95 0x0a 0x$SEE6 >> SE.log
		echo -e "${color_red} Set Sensor Event Enable Command failed ${color_reset}" | tee -a SE.log
		FailCounter=$(($FailCounter+1))
	else
		$i 0x28 $SID 0xc0 0x95 0x0a 0x95 0x0a 0x$SEE6 >> SE.log
		echo -e "${color_blue} Set Sensor Thresholds Command finished ${color_reset}"|tee -a SE.log
	fi
else
	$i 0x28 $SID 0xc0 0x95 0x0a 0x95 0x0a
	if [ ! $? -eq '0' ] ; then
		$i 0x28 $SID 0xc0 0x95 0x0a 0x95 0x0a >> SE.log
		echo -e "${color_red} Set Sensor Event Enable Command failed ${color_reset}" | tee -a SE.log
		FailCounter=$(($FailCounter+1))
	else
		$i 0x28 $SID 0xc0 0x95 0x0a 0x95 0x0a >> SE.log
		echo -e "${color_blue} Set Sensor Thresholds Command finished ${color_reset}"|tee -a SE.log
	fi
fi
echo ""|tee -a SE.log
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
	echo -e "${color_blue} Re-arm Sensor Events Command finished${color_reset}"|tee -a SE.log
fi
echo ""|tee -a SE.log
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
	read GSE1 GSE2 GSE3 GSE4 GSE5 <<< $($i 0x2b $SID)
	for j in GSE{1..5}; do
		eval temp=\$$j
		temp=${D2B[$((16#$temp))]}
		read $j'b1' $j'b2' $j'b3' $j'b4' $j'b5' $j'b6' $j'b7' $j'b8' <<< "${temp:0:1} ${temp:1:1} ${temp:2:1} ${temp:3:1} ${temp:4:1} ${temp:5:1} ${temp:6:1} ${temp:7:1}"
	done
	if [ $GSE1b1 -eq '0' ];then
		echo -e " All Event Messages ${color_red}disabled${color_reset} from $SN"|tee -a SE.log
	fi
	if [ $GSE1b2 -eq '0' ];then
		echo -e " Sensor scanning ${color_red}disabled${color_reset} on $SN"|tee -a SE.log
	fi
	if [ $GSE1b3 -eq '1' ];then
		echo -e " $SN reading/state ${color_red}unavailable${color_reset}"|tee -a SE.log
	fi
	if [ ! "$(ipmitool sdr get $SN |grep -i discrete)" ];then
		if [ $GSE2b1 -eq '1' ];then
			echo -e " Assertion event condition for ${color_red}upper non-critical going high${color_reset} occurred"|tee -a SE.log
		fi
		if [ $GSE2b2 -eq '1' ];then
			echo -e " Assertion event condition for ${color_green}upper non-critical going low${color_reset} occurred"|tee -a SE.log
		fi
		if [ $GSE2b3 -eq '1' ];then
			echo -e " Assertion event condition for ${color_green}lower non-recoverable going high${color_reset} occurred"|tee -a SE.log
		fi
		if [ $GSE2b4 -eq '1' ];then
			echo -e " Assertion event condition for ${color_red}lower non-recoverable going low${color_reset} occurred"|tee -a SE.log
		fi
		if [ $GSE2b5 -eq '1' ];then
			echo -e " Assertion event condition for ${color_green}lower critical going high${color_reset} occurred"|tee -a SE.log
		fi
		if [ $GSE2b6 -eq '1' ];then
			echo -e " Assertion event condition for ${color_red}lower critical going low${color_reset} occurred"|tee -a SE.log
		fi
		if [ $GSE2b7 -eq '1' ];then
			echo -e " Assertion event condition for ${color_green}lower non-critical going high${color_reset} occurred"|tee -a SE.log
		fi
		if [ $GSE2b8 -eq '1' ];then
			echo -e " Assertion event condition for ${color_red}lower non-critical going low${color_reset} occurred"|tee -a SE.log
		fi

		if [ $GSE3b5 -eq '1' ];then
			echo -e " Assertion event condition for ${color_red}upper non-recovable going high${color_reset} occurred"|tee -a SE.log
		fi
		if [ $GSE3b6 -eq '1' ];then
			echo -e " Assertion event condition for ${color_green}upper non-recovable going low${color_reset} occurred"|tee -a SE.log
		fi
		if [ $GSE3b7 -eq '1' ];then
			echo -e " Assertion event condition for ${color_red}upper critical going high${color_reset} occurred"|tee -a SE.log
		fi
		if [ $GSE3b8 -eq '1' ];then
			echo -e " Assertion event condition for ${color_green}upper critical going low${color_reset} occurred"|tee -a SE.log
		fi
		#Deassert
		if [ $GSE4b1 -eq '1' ];then
			echo -e " Deassertion event condition for ${color_green}upper non-critical going high${color_reset} occurred"|tee -a SE.log
		fi
		if [ $GSE4b2 -eq '1' ];then
			echo -e " Deassertion event condition for ${color_red}upper non-critical going low${color_reset} occurred"|tee -a SE.log
		fi
		if [ $GSE4b3 -eq '1' ];then
			echo -e " Deassertion event condition for ${color_red}lower non-recoverable going high${color_reset} occurred"|tee -a SE.log
		fi
		if [ $GSE4b4 -eq '1' ];then
			echo -e " Deassertion event condition for ${color_green}lower non-recoverable going low${color_reset} occurred"|tee -a SE.log
		fi
		if [ $GSE4b5 -eq '1' ];then
			echo -e " Deassertion event condition for ${color_red}lower critical going high${color_reset} occurred"|tee -a SE.log
		fi
		if [ $GSE4b6 -eq '1' ];then
			echo -e " Deassertion event condition for ${color_green}lower critical going low${color_reset} occurred"|tee -a SE.log
		fi
		if [ $GSE4b7 -eq '1' ];then
			echo -e " Deassertion event condition for ${color_red}lower non-critical going high${color_reset} occurred"|tee -a SE.log
		fi
		if [ $GSE4b8 -eq '1' ];then
			echo -e " Deassertion event condition for ${color_green}lower non-critical going low${color_reset} occurred"|tee -a SE.log
		fi

		if [ $GSE5b5 -eq '1' ];then
			echo -e " Deassertion event condition for ${color_green}upper non-recovable going high${color_reset} occurred"|tee -a SE.log
		fi
		if [ $GSE5b6 -eq '1' ];then
			echo -e " Deassertion event condition for ${color_red}upper non-recovable going low${color_reset} occurred"|tee -a SE.log
		fi
		if [ $GSE5b7 -eq '1' ];then
			echo -e " Deassertion event condition for ${color_green}upper critical going high${color_reset} occurred"|tee -a SE.log
		fi
		if [ $GSE5b8 -eq '1' ];then
			echo -e " Deassertion event condition for ${color_red}upper critical going low${color_reset} occurred"|tee -a SE.log
		fi
	else
		if [ $GSE2b1 -eq '1' ];then
			echo -e " State 7 assertion event occurred"|tee -a SE.log
		fi
		if [ $GSE2b2 -eq '1' ];then
			echo -e " State 6 assertion event occurred"|tee -a SE.log
		fi
		if [ $GSE2b3 -eq '1' ];then
			echo -e " State 5 assertion event occurred"|tee -a SE.log
		fi
		if [ $GSE2b4 -eq '1' ];then
			echo -e " State 4 assertion event occurred"|tee -a SE.log
		fi
		if [ $GSE2b5 -eq '1' ];then
			echo -e " State 3 assertion event occurred"|tee -a SE.log
		fi
		if [ $GSE2b6 -eq '1' ];then
			echo -e " State 2 assertion event occurred"|tee -a SE.log
		fi
		if [ $GSE2b7 -eq '1' ];then
			echo -e " State 1 assertion event occurred"|tee -a SE.log
		fi
		if [ $GSE2b8 -eq '1' ];then
			echo -e " State 0 assertion event occurred"|tee -a SE.log
		fi
		if [ $GSE3b2 -eq '1' ];then                                       
		        echo -e " State 14 assertion event occurred"|tee -a SE.log
		fi                                                                
		if [ $GSE3b3 -eq '1' ];then                                       
		        echo -e " State 13 assertion event occurred"|tee -a SE.log
		fi                                                                
		if [ $GSE3b4 -eq '1' ];then                                       
		        echo -e " State 12 assertion event occurred"|tee -a SE.log
		fi                                                              
		if [ $GSE3b5 -eq '1' ];then
			echo -e " State 11 assertion event occurred"|tee -a SE.log
		fi
		if [ $GSE3b6 -eq '1' ];then
			echo -e " State 10 assertion event occurred"|tee -a SE.log
		fi
		if [ $GSE3b7 -eq '1' ];then
			echo -e " State 9 assertion event occurred"|tee -a SE.log
		fi
		if [ $GSE3b8 -eq '1' ];then
			echo -e " State 8 assertion event occurred"|tee -a SE.log
		fi
		#Deassert
		if [ $GSE4b1 -eq '1' ];then
			echo -e " State 7 deassertion event occurred"|tee -a SE.log
		fi
		if [ $GSE4b2 -eq '1' ];then
			echo -e " State 6 deassertion event occurred"|tee -a SE.log
		fi
		if [ $GSE4b3 -eq '1' ];then
			echo -e " State 5 deassertion event occurred"|tee -a SE.log
		fi
		if [ $GSE4b4 -eq '1' ];then
			echo -e " State 4 deassertion event occurred"|tee -a SE.log
		fi
		if [ $GSE4b5 -eq '1' ];then
			echo -e " State 3 deassertion event occurred"|tee -a SE.log
		fi
		if [ $GSE4b6 -eq '1' ];then
			echo -e " State 2 deassertion event occurred"|tee -a SE.log
		fi
		if [ $GSE4b7 -eq '1' ];then
			echo -e " State 1 deassertion event occurred"|tee -a SE.log
		fi
		if [ $GSE4b8 -eq '1' ];then
			echo -e " State 0 deassertion event occurred"|tee -a SE.log
		fi
		if [ $GSE5b2 -eq '1' ];then                                       
		        echo -e " State 14 deassertion event occurred"|tee -a SE.log
		fi                                                                
		if [ $GSE5b3 -eq '1' ];then                                       
		        echo -e " State 13 deassertion event occurred"|tee -a SE.log
		fi                                                                
		if [ $GSE5b4 -eq '1' ];then                                       
		        echo -e " State 12 deassertion event occurred"|tee -a SE.log
		fi                                                              
		if [ $GSE5b5 -eq '1' ];then
			echo -e " State 11 deassertion event occurred"|tee -a SE.log
		fi
		if [ $GSE5b6 -eq '1' ];then
			echo -e " State 10 deassertion event occurred"|tee -a SE.log
		fi
		if [ $GSE5b7 -eq '1' ];then
			echo -e " State 9 deassertion event occurred"|tee -a SE.log
		fi
		if [ $GSE5b8 -eq '1' ];then
			echo -e " State 8 deassertion event occurred"|tee -a SE.log
		fi
	fi
	
	echo -e "${color_blue} Get Sensor Event Status Command finished ${color_reset}"|tee -a SE.log
fi
echo ""|tee -a SE.log
# raw 0x04 0x2d
echo " Get Sensor Reading Command" |tee -a SE.log
echo " Response below :" |tee -a SE.log
$i 0x2d $SID
if [ ! $?==0 ] ; then
	$i 0x2d $SID >> SE.log
	echo -e "${color_red} Get Sensor Reading Command failed ${color_reset}" |tee -a SE.log
	FailCounter=$(($FailCounter+1))
else
	$i 0x2d $SID >> SE.log
	read GSR1 GSR2 GSR3 GSR4 <<< $($i 0x2d $SID)
	for j in GSR{1..4}; do
		eval temp=\$$j
		temp=${D2B[$((16#$temp))]}
		read $j'b1' $j'b2' $j'b3' $j'b4' $j'b5' $j'b6' $j'b7' $j'b8' <<< "${temp:0:1} ${temp:1:1} ${temp:2:1} ${temp:3:1} ${temp:4:1} ${temp:5:1} ${temp:6:1} ${temp:7:1}"
	done
	echo -e " The sensor reading = ${color_green}$GSR1${color_reset}.(Ignore on read if sensor does not return an numeric (analog) reading.)"|tee -a SE.log
	
	if [ $GSR2b1 -eq '0' ];then
		echo -e " All Event Messages ${color_red}disabled${color_reset} from $SN"|tee -a SE.log
	fi
	if [ $GSR2b2 -eq '0' ];then
		echo -e " $SN Sensor scanning ${color_red}disabled${color_reset}"|tee -a SE.log
	fi
	if [ $GSR2b3 -eq '1' ];then
		echo -e " $SN Reading/state ${color_red}unavailable${color_reset}"|tee -a SE.log
	fi
	# check sensor is discrete or threshold type
	if [ "$(ipmitool sdr get $SN |grep -i discrete)" ];then
		if [ $GSR3b1 -eq '1' ];then
			echo "state 7 asserted"|tee -a SE.log
		fi
		if [ $GSR3b2 -eq '1' ];then
			echo "state 6 asserted"|tee -a SE.log
		fi
		if [ $GSR3b3 -eq '1' ];then
			echo "state 5 asserted"|tee -a SE.log
		fi
		if [ $GSR3b4 -eq '1' ];then
			echo "state 4 asserted"|tee -a SE.log
		fi
		if [ $GSR3b5 -eq '1' ];then
			echo "state 3 asserted"|tee -a SE.log
		fi
		if [ $GSR3b6 -eq '1' ];then
			echo "state 2 asserted"|tee -a SE.log
		fi
		if [ $GSR3b7 -eq '1' ];then
			echo "state 1 asserted"|tee -a SE.log
		fi
		if [ $GSR3b8 -eq '1' ];then
			echo "state 0 asserted"|tee -a SE.log
		fi
	else
		if [ $GSR3b3 -eq '1' ];then
			echo -e " Reach or over ${color_red}upper non-recoverable${color_reset} threshold"|tee -a SE.log
		fi
		if [ $GSR3b4 -eq '1' ];then
			echo -e " Reach or over ${color_red}upper critical threshold${color_reset}"|tee -a SE.log
		fi
		if [ $GSR3b5 -eq '1' ];then
			echo -e " Reach or over ${color_red}upper non-critical threshold${color_reset}"|tee -a SE.log
		fi
		if [ $GSR3b6 -eq '1' ];then
			echo -e " Reach or under ${color_red}lower non-recoverable threshold${color_reset}"|tee -a SE.log
		fi
		if [ $GSR3b7 -eq '1' ];then
			echo -e " Reach or under ${color_red}lower critical threshold${color_reset}"|tee -a SE.log
		fi
		if [ $GSR3b8 -eq '1' ];then
			echo -e " Reach or under ${color_red}lower non-critical threshold${color_reset}"|tee -a SE.log
		fi
	fi
	if [ ! $GSR4 -eq '00' ];then 
		if [ $GSR4b2 -eq '1' ];then
			echo "state 14 asserted"|tee -a SE.log
		fi
		if [ $GSR4b3 -eq '1' ];then
			echo "state 13 asserted"|tee -a SE.log
		fi
		if [ $GSR4b4 -eq '1' ];then
			echo "state 12 asserted"|tee -a SE.log
		fi
		if [ $GSR4b5 -eq '1' ];then
			echo "state 11 asserted"|tee -a SE.log
		fi
		if [ $GSR4b6 -eq '1' ];then
			echo "state 10 asserted"|tee -a SE.log
		fi
		if [ $GSR4b7 -eq '1' ];then
			echo "state 9 asserted"|tee -a SE.log
		fi
		if [ $GSR4b8 -eq '1' ];then
			echo "state 8 asserted"|tee -a SE.log
		fi
	fi
	echo -e "${color_blue} Get Sensor Reading Command finished${color_reset}"|tee -a SE.log
fi

echo ""|tee -a SE.log

# raw 0x04 0x2f	
echo " Get Sensor Type Command" |tee -a SE.log
echo " Response below :" |tee -a SE.log
$i 0x2f $SID
if [ ! $? -eq '0' ] ; then
	$i 0x2f $SID >> SE.log
	echo -e "${color_red} Get Sensor Type Command failed ${color_reset}"|tee -a SE.log
	FailCounter=$(($FailCounter+1))
else
	$i 0x2f $SID >> SE.log
	read GST1 GST2 <<< $($i 0x2f $SID)
	for j in GST{1,2}; do
		eval temp=\$$j
		temp=${D2B[$((16#$temp))]}
		read $j'b1' $j'b2' $j'b3' $j'b4' $j'b5' $j'b6' $j'b7' $j'b8' <<< "${temp:0:1} ${temp:1:1} ${temp:2:1} ${temp:3:1} ${temp:4:1} ${temp:5:1} ${temp:6:1} ${temp:7:1}"
	done
	case $GST1 in
	01) echo -e " $SN is ${color_green}Temperature type${color_reset}"|tee -a SE.log;;
	02) echo -e " $SN is ${color_green}Voltage type${color_reset}"|tee -a SE.log;;
	03) echo -e " $SN is ${color_green}Current type${color_reset}"|tee -a SE.log;;
	04) echo -e " $SN is ${color_green}Fan type${color_reset}"|tee -a SE.log;;
	05) echo -e " $SN is ${color_green}Physical Security type${color_reset}"|tee -a SE.log
		echo " Event Offset"|tee -a SE.log
		echo " 
		 00h
		 General Chassis Intrusion
		 01h
		 Drive Bay intrusion
		 02h
		 I/O Card area intrusion
		 03h
		 Processor area intrusion
		 04h
		 LAN Leash Lost (system is unplugged from LAN)
		 The Event Data 2 field can be used to identify which network controller the leash was lost on where 00h corresponds to the first (or only) network controller.
		 05h
		 Unauthorized dock
		 06h
		 FAN area intrusion (supports detection of hot plug fan tampering)${color_reset}"|tee -a SE.log;;
	06) echo -e " $SN is ${color_green}Platform Security Violation Attempt type${color_reset}"|tee -a SE.log
		echo " Event Offset"|tee -a SE.log
		echo " 
		 00h
		 Secure Mode (Front Panel Lockout) Violation attempt.
		 01h
		 Pre-boot Password Violation - user password.
		 02h
		 Pre-boot Password Violation attempt - setup password.
		 03h
		 Pre-boot Password Violation - network boot password.
		 04h
		 Other pre-boot Password Violation.
		 05h
		 Out-of-band Access Password Violation."|tee -a SE.log;;
	07) echo -e " $SN is ${color_green}Processor type${color_reset}"|tee -a SE.log
		echo " Event Offset"|tee -a SE.log
		echo " 
		 00h
		 IERR
		 01h
		 Thermal Trip
		 02h
		 FRB1/BIST failure
		 03h
		 FRB2/Hang in POST failure (used hang is believed to be due or related to a processor failure. Use System Firmware Progress sensor for other BIOS hangs.)
		 04h
		 FRB3/Processor Startup/Initialization failure (CPU didn’t start)
		 05h
		 Configuration Error
		 06h
		 SM BIOS ‘Uncorrectable CPU-complex Error’
		 07h
		 Processor Presence detected
		 08h
		 Processor disabled
		 09h
		 Terminator Presence Detected
		 0Ah
		 Processor Automatically Throttled (processor throttling triggered by a hardware-based mechanism operating independent from system software, such as automatic thermal throttling or throttling to limit power consumption.)
		 0Bh
		 Machine Check Exception (Uncorrectable)
		 0Ch
		 Correctable Machine Check Error"|tee -a SE.log;;
	08) echo -e " $SN is ${color_green}Power Supply type${color_reset}"|tee -a SE.log
		echo " Event Offset"|tee -a SE.log
		echo " 
		 00h
		 Presence detected
		 01h
		 Power Supply Failure detected
		 02h
		 Predictive Failure
		 03h
		 Power Supply input lost (AC/DC)[2]
		 04h
		 Power Supply input lost or out-of-range
		 05h
		 Power Supply input out-of-range, but present
		 06h
		 Configuration error. The Event Data 3 field provides a more detailed definition of the error:
			 7:4 = Reserved for future definition, set to 0000b
			 3:0 = Error Type, one of
			 0h = Vendor mismatch, for power supplies that include this status. (Typically, the system OEM defines the vendor compatibility criteria that drives this status).
			 1h = Revision mismatch, for power supplies that include this status. (Typically, the system OEM defines the vendor revision compatibility that drives this status).
			 2h = Processor missing. For processor power supplies (typically DC-to-DC converters or VRMs), there's usually a one-to-one relationship between the supply and the CPU. This offset can indicate the situation where the power supply is present but the processor is not. This offset can be used for reporting that as an unexpected or unsupported condition.
			 3h = Power Supply rating mismatch. The power rating of the supply does not match the system's requirements.
			 4h = Voltage rating mismatch. The voltage rating of the supply does not match the system's requirements.
			 Others = Reserved for future definition
		 07h
		 Power Supply Inactive (in standby state). Power supply is in a standby state where its main outputs have been automatically deactivated because the load is being supplied by one or more other power supplies."|tee -a SE.log;;
	09) echo -e " $SN is ${color_green}Power Unit type${color_reset}"|tee -a SE.log
		echo " Event Offset"|tee -a SE.log
		echo " 
		 00h
		 Power Off / Power Down
		 01h
		 Power Cycle
		 02h
		 240VA Power Down
		 03h
		 Interlock Power Down
		 04h
		 AC lost / Power input lost (The power source for the power unit was lost)
		 05h
		 Soft Power Control Failure (unit did not respond to request to turn on)
		 06h
		 Power Unit Failure detected
		 07h
		 Predictive Failure"|tee -a SE.log;;
	'0a') echo -e " $SN is ${color_green}Cooling Device type${color_reset}"|tee -a SE.log;;
	'0b') echo -e " $SN is ${color_green}Other Units-based Sensor type${color_reset}(per units given in SDR)"|tee -a SE.log;;
	'0c') echo -e " $SN is ${color_green}Memory type${color_reset}"|tee -a SE.log
		  echo " Event Offset"|tee -a SE.log
		  echo " 
		 00h
		 Correctable ECC / other correctable memory error
		 01h
		 Uncorrectable ECC / other uncorrectable memory error
		 02h
		 Parity
		 03h
		 Memory Scrub Failed (stuck bit)
		 04h
		 Memory Device Disabled
		 05h
		 Correctable ECC / other correctable memory error logging limit reached
		 06h
		 Presence detected. Indicates presence of entity associated with the sensor. Typically the entity will be a ‘memory module’ or other entity representing a physically replaceable unit of memory.
		 07h
		 Configuration error. Indicates a memory configuration error for the entity associated with the sensor. This can include when a given implementation of the entity is not supported by the system (e.g., when the particular size of the memory module is unsupported) or that the entity is part of an unsupported memory configuration (e.g. the configuration is not supported because the memory module doesn’t match other memory modules).
		 08h
		 Spare. Indicates entity associated with the sensor represents a ‘spare’ unit of memory.
		 The Event Data 3 field can be used to provide an event extension code, with the following definition:
		 Event Data 3
			 [7:0] - Memory module/device (e.g. DIMM/SIMM/RIMM) identification, relative to the entity that the sensor is associated with (if SDR provided for this sensor).
		 09h
		 Memory Automatically Throttled. (memory throttling triggered by a hardware-based mechanism operating independent from system software, such as automatic thermal throttling or throttling to limit power consumption.)
		 0Ah
		 Critical Overtemperature. Memory device has entered a critical overtemperature state, exceeding specified operating conditions. Memory devices in this state may produce errors or become inaccessible."|tee -a SE.log;;
	'0d') echo -e " $SN is ${color_green}Drive Slot type(Bay)${color_reset}"|tee -a SE.log
		  echo " Event Offset" |tee -a SE.log
		  echo " 
		 00h
         Drive Presence
		 01h
		 Drive Fault
		 02h
		 Predictive Failure
		 03h
		 Hot Spare
		 04h
		 Consistency Check / Parity Check in progress
		 05h
		 In Critical Array
		 06h
		 In Failed Array
		 07h
		 Rebuild/Remap in progress
		 08h
		 Rebuild/Remap Aborted (was not completed normally)"|tee -a SE.log;;
	'0e') echo -e " $SN is ${color_green}POST Memory Resize type${color_reset}"|tee -a SE.log;;
	'0f') echo -e " $SN is ${color_green}System Firmware Progress type(formerly POST Error)${color_reset}"|tee -a SE.log
		  echo " Event Offset"|tee -a SE.log
		  echo " 
		 00h
		 System Firmware Error (POST Error)
		 The Event Data 2 field can be used to provide an event extension code, with the following definition:
		 Event Data 2
			 00h Unspecified.
			 01h No system memory is physically installed in the system.
			 02h No usable system memory, all installed memory has experienced an unrecoverable failure.
			 03h Unrecoverable hard-disk/ATAPI/IDE device failure.
			 04h Unrecoverable system-board failure.
			 05h Unrecoverable diskette subsystem failure.
			 06h Unrecoverable hard-disk controller failure.
			 07h Unrecoverable PS/2 or USB keyboard failure.
			 08h Removable boot media not found
			 09h Unrecoverable video controller failure
			 0Ah No video device detected
			 0Bh Firmware (BIOS) ROM corruption detected
			 0Ch CPU voltage mismatch (processors that share same supply have mismatched voltage requirements)
			 0Dh CPU speed matching failure
			 0Eh to FFh reserved
		 01h
		 System Firmware Hang (uses same Event Data 2 definition as following System Firmware Progress offset)
		 02h
		 System Firmware Progress
		 The Event Data 2 field can be used to provide an event extension code, with the following definition:
		 Event Data 2
			 00h Unspecified.
			 01h Memory initialization.
			 02h Hard-disk initialization
			 03h Secondary processor(s) initialization
			 04h User authentication
			 05h User-initiated system setup
			 06h USB resource configuration
			 07h PCI resource configuration
			 08h Option ROM initialization
			 09h Video initialization
			 0Ah Cache initialization
			 0Bh SM Bus initialization
			 0Ch Keyboard controller initialization
			 0Dh Embedded controller/management controller initialization
			 0Eh Docking station attachment
			 0Fh Enabling docking station
			 10h Docking station ejection
			 11h Disabling docking station
			 12h Calling operating system wake-up vector
			 13h Starting operating system boot process, e.g. calling Int 19h
			 14h Baseboard or motherboard initialization
			 15h reserved
			 16h Floppy initialization
			 17h Keyboard test
			 18h Pointing device test
			 19h Primary processor initialization
			 1Ah to FFh reserved"|tee -a SE.log;;
	10) echo -e " SN is ${color_green}Event Logging Disabled type${color_reset}"|tee -a SE.log
		echo " Event Offset"|tee -a SE.log
		echo " 
		 00h
		 Correctable Memory Error Logging Disabled
		 Event Data 2
			 [7:0] - Memory module/device (e.g. DIMM/SIMM/RIMM) identification, relative to the entity that the sensor is associated with (if SDR provided for this sensor).
		 01h
		 Event ‘Type’ Logging Disabled. Event Logging is disabled for following event/reading type and offset has been disabled.
		 Event Data 2
			 Event/Reading Type Code
		 Event Data 3
			 [7:6] - reserved. Write as 00b.
			 [5] - 1b = logging has been disabled for all events of given type
			 [4] - 1b = assertion event, 0b = deassertion event
			 [3:0] - Event Offset
		 02h
		 Log Area Reset/Cleared
		 03h
		 All Event Logging Disabled
		 04h
		 SEL Full. If this is used to generate an event, it is recommended that this be generated so that this will be logged as the last entry in the SEL. If the SEL is very small, an implementation can elect to generate this event after the last entry has been placed in the SEL to save space. In this case, this event itself would not get logged, but could still trigger actions such as an alert via PEF. Note that an application can always use the Get SEL Info command to determine whether the SEL is full or not. Since Get SEL Info is a mandatory command, this provides a cross-platform way to get that status.
		 05h
		 SEL Almost Full. If Event Data 3 is not provided, then by default this event represents the SEL has reached a point of being 75% or more full. For example, if the SEL supports 215 entries, the 75% value would be 161.25 entries. Therefore, the event would be generated on the 162nd entry. Note that if this event itself is logged, it would be logged as the 163rd entry.
		 Event Data 3
			 Contains hex value from 0 to 100 decimal (00h to 64h) representing the % of which the SEL is filled at the time the event was generated: 00h is 0% full (SEL is empty), 64h is 100% full, etc.
		 06h
		 Correctable Machine Check Error Logging Disabled
		 If the following field is not provided, then this event indicates that Correctable Machine Check error logging has been disabled for all Processor sensors.
		 Event Data 2
			 Event Data 2 may be optionally used to return an Entity Instance or a vendor selected processor number that identifies the processor associated with this event.
			 [7:0] - Instance ID number of the (processor) Entity that the sensor is associated with (if SDR provided for this sensor), or a vendor selected logical processor number if no SDR.
		 Event Data 3
			 If Event Data 2 is provided then Event Data 3 may be optionally used to indicate whether Event Data 2 is being used to hold an Entity Instance number or a vendor-specific processor number. If Event Data 2 is provided by Event Data 3 is not, then Event Data 2 is assumed to hold an Entity Instance number.
			 [7] - 0b = Entity Instance number
			 1b = Vendor-specific processor number
			 [6:0] - reserved"|tee -a SE.log;;
	11) echo -e " $SN is ${color_green}Watchdog 1 type${color_reset}"|tee -a SE.log
		echo " Event Offset"|tee -a SE.log
		echo " 
		 00h
		 BIOS Watchdog Reset
		 01h
		 OS Watchdog Reset
		 02h
		 OS Watchdog Shut Down
		 03h
		 OS Watchdog Power Down
		 04h
		 OS Watchdog Power Cycle
		 05h
		 OS Watchdog NMI / Diagnostic Interrupt
		 06h
		 OS Watchdog Expired, status only
		 07h
		 OS Watchdog pre-timeout Interrupt, non-NMI"|tee -a SE.log;;
	12) echo -e " $SN is ${color_green}System Event type${color_reset}"|tee -a SE.log
		echo " Event Offset"|tee -a SE.log
		echo " 
		 00h
		 System Reconfigured
		 01h
		 OEM System Boot Event
		 02h
		 Undetermined system hardware failure
		 (this event would typically require system-specific diagnostics to determine FRU / failure type)
		 03h
		 Entry added to Auxiliary Log
		 Event Data 2
			 [7:4] - Log Entry Action
			 0h = entry added
			 1h = entry added because event did not be map to standard IPMI event
			 2h = entry added along with one or more corresponding SEL entries
		 	 3h = log cleared
			 4h = log disabled
			 5h = log enabled
			 all other = reserved
			 [3:0] - Log Type
			 0h = MCA Log
			 1h = OEM 1
 			 2h = OEM 2
	 		 all other = reserved
		 04h
		 PEF Action
		 Event Data 2
			 The following bits reflect the PEF Actions that are about to be taken after the event filters have been matched. The event is captured before the actions are taken.
			 [7:6] - reserved
			 [5] - 1b = Diagnostic Interrupt (NMI)
			 [4] - 1b = OEM action
			 [3] - 1b = power cycle
			 [2] - 1b = reset
			 [1] - 1b = power off
	 		 [0] - 1b = Alert
		 05h
		 Timestamp Clock Synch. This event can be used to record when changes are made to the timestamp clock(s) so that relative time differences between SEL entries can be determined. See note [1].
		 Event Data 2
			 [7] - first/second
			 0b = event is first of pair.
			 1b = event is second of pair.
			 [6:4] - reserved
			 [3:0] - Timestamp Clock Type
			 0h = SEL Timestamp Clock updated. (Also used when both SEL and SDR Timestamp clocks are linked together.)
			 1h = SDR Timestamp Clock updated."|tee -a SE.log;;
	13) echo -e " $SN is ${color_green}Critical Interrupt type${color_reset}"|tee -a SE.log
		echo " Event Offset"|tee -a SE.log
		echo " 
		 00h
		 Front Panel NMI / Diagnostic Interrupt
		 01h
		 Bus Timeout
		 02h
		 I/O channel check NMI
		 03h
		 Software NMI
		 04h
		 PCI PERR
		 05h
		 PCI SERR
		 06h
		 EISA Fail Safe Timeout
		 07h
		 Bus Correctable Error
		 08h
		 Bus Uncorrectable Error
		 09h
		 Fatal NMI (port 61h, bit 7)
		 0Ah
		 Bus Fatal Error
		 0Bh
		 Bus Degraded (bus operating in a degraded performance state)"|tee -a SE.log;;
	14) echo -e " $SN is ${color_green}Button / Switch type${color_reset}"|tee -a SE.log
		echo " Event Offset"|tee -a SE.log
		echo " 
		 00h
		 Power Button pressed
		 01h
		 Sleep Button pressed
		 02h
		 Reset Button pressed
		 03h
		 FRU latch open (Switch indicating FRU latch is in ‘unlatched’ position and FRU is mechanically removable)
		 04h
		 FRU service request button (1 = pressed, service, e.g. removal/replacement, requested)"|tee -a SE.log;;
	15) echo -e " $SN is ${color_green}Module / Board type${color_reset}"|tee -a SE.log;;
	16) echo -e " $SN is ${color_green}Microcontroller / Coprocessor type${color_reset}"|tee -a SE.log;;
	17) echo -e " $SN is ${color_green}Add-in Card type${color_reset}"|tee -a SE.log;;
	18) echo -e " $SN is ${color_green}Chassis type${color_reset}"|tee -a SE.log;;
	19) echo -e " $SN is ${color_green}Chip Set${color_reset}"|tee -a SE.log
		echo " Event Offset"|tee -a SE.log
		echo " 
		 00h
		 Soft Power Control Failure (chip set did not respond to BMC request to change system power state). This offset is similar to offset 05h for a power unit, except that the power unit event is only related to a failure to power up, while this event corresponds to any system power state change directly requested via the BMC.
		 Event Data 2
			 The Event Data 2 field for this command can be used to provide additional information on the type of failure with the following definition:
			 Requested power state
			 00h = S0 / G0 “working”
			 01h = S1 “sleeping with system h/w & processor context maintained”
			 02h = S2 “sleeping, processor context lost”
			 03h = S3 “sleeping, processor & h/w context lost, memory retained.”
			 04h = S4 “non-volatile sleep / suspend-to disk”
			 05h = S5 / G2 “soft-off”
			 06h = S4 / S5 soft-off, particular S4 / S5 state cannot be determined
			 07h = G3 / Mechanical Off
			 08h = Sleeping in an S1, S2, or S3 states (used when particular S1, S2, S3 state cannot be determined)
			 09h = G1 sleeping (S1-S4 state cannot be determined)
			 0Ah = S5 entered by override
			 0Bh = Legacy ON state
			 0Ch = Legacy OFF state
			 0Dh = reserved
		 Event Data 3
			 The Event Data 3 field for this command can be used to provide additional information on the type of failure with the following definition:
			 Power state at time of request
			 00h = S0 / G0 “working”
			 01h = S1 “sleeping with system h/w & processor context maintained”
			 02h = S2 “sleeping, processor context lost”
			 03h = S3 “sleeping, processor & h/w context lost, memory retained.”
			 04h = S4 “non-volatile sleep / suspend-to disk”
			 05h = S5 / G2 “soft-off”
			 06h = S4 / S5 soft-off, particular S4 / S5 state cannot be determined
			 07h = G3 / Mechanical Off
			 08h = Sleeping in an S1, S2, or S3 states (used when particular S1, S2, S3 state cannot be determined)
			 09h = G1 sleeping (S1-S4 state cannot be determined)
			 0Ah = S5 entered by override
			 0Bh = Legacy ON state
			 0Ch = Legacy OFF state
			 0Dh = unknown
		 01h
		 Thermal Trip"|tee -a SE.log;;
	'1a') echo -e " $SN is ${color_green}Other FRU type${color_reset}"|tee -a SE.log;;
	'1b') echo -e " $SN is ${color_green}Cable / Interconnect type${color_reset}"|tee -a SE.log
		  echo " Event Offset"|tee -a SE.log
		  echo " 
		 00h
		 Cable/Interconnect is connected
		 01h
		 Configuration Error - Incorrect cable connected / Incorrect interconnection"|tee -a SE.log;;
	'1c') echo -e " $SN is ${color_green}Terminator type${color_reset}"|tee -a SE.log;;
	'1d') echo -e " $SN is ${color_green}System Boot / Restart Initiated type${color_reset}"|tee -a SE.log
		  echo " Event Offset"|tee -a SE.log
		  echo " 
		 00h
		 Initiated by power up (this would typically be generated by BIOS/EFI)
		 01h
		 Initiated by hard reset (this would typically be generated by BIOS/EFI)
		 02h
		 Initiated by warm reset (this would typically be generated by BIOS/EFI)
		 03h
		 User requested PXE boot
		 04h
		 Automatic boot to diagnostic
		 05h
		 OS / run-time software initiated hard reset
		 06h
		 OS / run-time software initiated warm reset
		 07h
		 System Restart (Intended to be used with Event Data 2 and or 3 as follows:)
		 Event Data 2
			[7:4] - reserved
			[3:0] - restart cause per Get System Restart Cause command.
		 Event Data 3
			Channel number used to deliver command that generated restart, per Get System Restart Cause command."|tee -a SE.log;;
	'1e') echo -e " $SN is ${color_green}Boot Error type${color_reset}"|tee -a SE.log
		  echo " Event Offset"|tee -a SE.log
		  echo " 
		 00h
		 No bootable media
		 01h
		 Non-bootable diskette left in drive
		 02h
		 PXE Server not found
		 03h
		 Invalid boot sector
		 04h
		 Timeout waiting for user selection of boot source"|tee -a SE.log;;
	'1f') echo -e " $SN is ${color_green}Base OS Boot / Installation Status type${color_reset}"|tee -a SE.log
		  echo " Event Offset"|tee -a SE.log
		  echo " 
		 00h
		 A: boot completed
		 01h
		 C: boot completed
		 02h
		 PXE boot completed
		 03h
		 Diagnostic boot completed
		 04h
		 CD-ROM boot completed
		 05h
		 ROM boot completed
		 06h
		 boot completed - boot device not specified
		 07h
		 Base OS/Hypervisor Installation started (Reflects Base Operating System / Hypervisor Installation, not installing/provisioning a VM.)
		 08h
		 Base OS/Hypervisor Installation completed
		 09h
		 Base OS/Hypervisor Installation aborted
		 0Ah
		 Base OS/Hypervisor Installation failed"|tee -a SE.log;;
	20) echo -e " $SN is ${color_green}OS Stop / Shutdown type${color_reset}"|tee -a SE.log
		echo " Event Offset"|tee -a SE.log
		echo " 
		 00h
		 Critical stop during OS load / initialization. Unexpected error during system startup. Stopped waiting for input or power cycle/reset.
		 01h
		 Run-time Critical Stop (a.k.a. ‘core dump’, ‘blue screen’)
		 02h
		 OS Graceful Stop (system powered up, but normal OS operation has shut down and system is awaiting reset pushbutton, power-cycle or other external input)
		 03h
		 OS Graceful Shutdown (system graceful power down by OS)
		 04h
		 Soft Shutdown initiated by PEF
		 05h
		 Agent Not Responding. Graceful shutdown request to agent via BMC did not occur due to missing or malfunctioning local agent."|tee -a SE.log;;
	21) echo -e " $SN is ${color_green}Slot / Connector type${color_reset}"|tee -a SE.log
		echo " Event Offset"|tee -a SE.log
		echo " 
		 00h
		 Fault Status asserted
		 01h
		 Identify Status asserted
		 02h
		 Slot / Connector Device installed/attached [This can include dock events]
		 03h
		 Slot / Connector Ready for Device Installation - Typically, this means that the slot power is off. The Ready for Installation, Ready for Removal, and Slot Power states can transition together, depending on the slot implementation.
		 04h
		 Slot/Connector Ready for Device Removal
		 05h
		 Slot Power is Off
		 06h
		 Slot / Connector Device Removal Request - This is typically connected to a switch that becomes asserted to request removal of the device)
		 07h
		 Interlock asserted - This is typically connected to a switch that mechanically enables/disables power to the slot, or locks the slot in the ‘Ready for Installation / Ready for Removal states’ - depending on the slot implementation. The asserted state indicates that the lock-out is active.
		 08h
		 Slot is Disabled
		 09h
		 Slot holds spare device
		 The Event Data 2 & 3 fields can be used to provide an event extension code, with the following definition:
		 Event Data 2
			 7 reserved
			 6:0 Slot/Connector Type
			 0 PCI
			 1 Drive Array
			 2 External Peripheral Connector
			 3 Docking
			 4 other standard internal expansion slot
			 5 slot associated with entity specified by Entity ID for sensor
			 6 AdvancedTCA
			 7 DIMM/memory device
			 8 FAN
			 9 PCI Express™
			 10 SCSI (parallel)
			 11 SATA / SAS
			 all other = reserved
		 Event Data 3
			 7:0 Slot/Connector Number"|tee -a SE.log;;
	22) echo -e " $SN is ${color_green}System ACPI Power State type${color_reset}"|tee -a SE.log
		echo " Event Offset"|tee -a SE.log
		echo " 
		 00h
		 S0 / G0 “working”
		 01h
		 S1 “sleeping with system h/w & processor context maintained”
		 02h
		 S2 “sleeping, processor context lost”
		 03h
		 S3 “sleeping, processor & h/w context lost, memory retained.”
		 04h
		 S4 “non-volatile sleep / suspend-to disk”
		 05h
		 S5 / G2 “soft-off”
		 06h
		 S4 / S5 soft-off, particular S4 / S5 state cannot be determined
		 07h
		 G3 / Mechanical Off
		 08h
		 Sleeping in an S1, S2, or S3 states (used when particular S1, S2, S3 state cannot be determined)
		 09h
		 G1 sleeping (S1-S4 state cannot be determined)
		 0Ah
		 S5 entered by override
		 0Bh
		 Legacy ON state
		 0Ch
		 Legacy OFF state
		 0Eh
		 Unknown"|tee -a SE.log;;
	23) echo -e " $SN is ${color_green}Watchdog 2 type${color_reset}"|tee -a SE.log
		echo " Event Offset"|tee -a SE.log
		echo " 
		 00h
		 Timer expired, status only (no action, no interrupt)
		 01h
		 Hard Reset
		 02h
		 Power Down
		 03h
		 Power Cycle
		 04h-07h
		 reserved
		 08h
		 Timer interrupt
		 The Event Data 2 field for this command can be used to provide an event extension code, with the following definition:
		 7:4 interrupt type
			 0h = none
			 1h = SMI
			 2h = NMI
			 3h = Messaging Interrupt
			 Fh = unspecified
			 all other = reserved
		 3:0 timer use at expiration:
			 0h = reserved
			 1h = BIOS FRB2
			 2h = BIOS/POST
			 3h = OS Load
			 4h = SMS/OS
			 5h = OEM
			 Fh = unspecified
			 all other = reserved"|tee -a SE.log;;
	24) echo -e " $SN is ${color_green}Platform Alert type${color_reset}"|tee -a SE.log
		echo " Event Offset"|tee -a SE.log
		echo " 
		 00h
		 platform generated page
		 01h
		 platform generated LAN alert
		 02h
		 Platform Event Trap generated, formatted per IPMI PET specification
		 03h
		 platform generated SNMP trap, OEM format"|tee -a SE.log;;
	25) echo -e " $SN is ${color_green}Entity Presence type${color_reset}"|tee -a SE.log
		echo " Event Offset"|tee -a SE.log
		echo " 
		 00h
		 Entity Present. This indicates that the Entity identified by the Entity ID for the sensor is present.
		 01h
		 Entity Absent. This indicates that the Entity identified by the Entity ID for the sensor is absent. If the entity is absent, system management software should consider all sensors associated with that Entity to be absent as well - and ignore those sensors.
		 02h
		 Entity Disabled. The Entity is present, but has been disabled. A deassertion of this event indicates that the Entity has been enabled."|tee -a SE.log;;
	26) echo -e " $SN is ${color_green}Monitor ASIC / IC type${color_reset}"|tee -a SE.log;;
	27) echo -e " $SN is ${color_green}LAN type${color_reset}"|tee -a SE.log
		echo " Event Offset"|tee -a SE.log
		echo "  
		 00h
		 LAN Heartbeat Lost
		 01h
		 LAN Heartbeat"|tee -a SE.log;;
	28) echo -e " $SN is ${color_green}Management Subsystem Healthtype${color_reset}"|tee -a SE.log
		echo " Event Offset"|tee -a SE.log
		echo " 
		 00h
		 sensor access degraded or unavailable (A sensor that is degraded will still return valid results, but may be operating with a slower response time, or may not detect certain possible states. A sensor that is unavailable is not able to return any results (scanning is disabled,)
		 01h
		 controller access degraded or unavailable (The ability to access the controller has been degraded, or access is unavailable, but the party that is doing the monitoring cannot determine which.)
		 02h
		 management controller off-line (controller cannot be accessed for normal operation because it has been intentionally taken off-line for a non-error condition. Note that any commands that are available must function according to specification.)
		 03h
		 management controller unavailable (controller cannot be accessed because of an error condition)
		 04h
		 Sensor failure (the sensor is known to be in error. It may still be accessible by software)
		 Event Data 2
		 The Event Data 2 field for this offset can be used to provide additional information on the type of failure with the following definition:
			 [7:0] - Sensor Number. Number of the failed sensor corresponding to event offset 04h or 00h.
		 05h
		 FRU failure
		 The Event Data 2 and 3 fields for this offset can be used to provide additional information on the type of failure with the following definition:
		 Event Data 2
			 [7] - logical/physical FRU device
			 0b = device is not a logical FRU Device
			 1b = device is logical FRU Device (accessed via FRU commands to mgmt. controller)
			 [6:5] - reserved.
			 [4:3] - LUN for Master Write-Read command or FRU Command. 00b if device is non-intelligent device directly on IPMB.
			 [2:0] - Private bus ID if bus = Private. 000b if device directly on IPMB, or device is a logical FRU Device.
		 Event Data 3
			 For LOGICAL FRU DEVICE (accessed via FRU commands to mgmt. controller):
			 [7:0] - FRU Device ID within controller that generated the event.FFh = reserved.
			 For non-intelligent FRU device:
			 [7:1] - 7-bit I2C Slave Address of FRU device . This is relative to the bus the device is on. For devices on the IPMB, this is the slave address of the device on the IPMB. For devices on a private bus, this is the slave address of the device on the private bus.
			 [0] - reserved."|tee -a SE.log;;
	29) echo -e " $SN is ${color_green}Battery type${color_reset}"|tee -a SE.log
		echo " Event Offset"|tee -a SE.log
		echo " 
		 00h
		 battery low (predictive failure)
		 01h
		 battery failed battery presence detected
		 02h
		 battery presence detected"|tee -a SE.log;;
	'2a') echo -e " $SN is ${color_green}Session Audit type${color_reset}"|tee -a SE.log
		  echo " Event Offset"|tee -a SE.log
		  echo " 
		 00h
		 Session Activated
		 01h
		 Session Deactivated
		 02h
		 Invalid Username or Password
		 An Invalid Username or Password was received during the session establishment process.
		 03h
		 Invalid password disable.
		 A user's access has been disabled due to a series of bad password attempts. This offset can be used in conjunction with the Bad Password Threshold option. Refer to the LAN or serial/modem configuration parameter for 'Bad Password Threshold' for more information.
		 The Event Data 2 & 3 fields can be used to provide an event extension code for the preceding offsets, with the following definition:
		 Event Data 2
	  	  	 7:6 reserved
			 5:0 User ID for user that activated session. 00_0000b = unspecified.
		 Event Data 3
			 7:6 reserved
			 5:4 Deactivation cause
			 00b = Session deactivatation cause unspecified. This value is also used for Session Activated events.
			 01b = Session deactivated by Close Session command
			 10b = Session deactivated by timeout
			 11b = Session deactivated by configuration change
			 3:0 Channel number that session was activated/deactivated over. Use channel number that session was activated over if a session was closed for an unspecified reason, a timeout, or a configuration change."|tee -a SE.log;;
	'2b') echo -e " $SN is ${color_green}Version Change type${color_reset}"|tee -a SE.log
		  echo " Event Offset"|tee -a SE.log
		  echo " 
		 00h
		 Hardware change detected with associated Entity. Informational. This offset does not imply whether the hardware change was successful or not. Only that a change occurred.
		 01h
		 Firmware or software change detected with associated Entity. Informational. Success or failure not implied.
		 02h
		 Hardware incompatibility detected with associated Entity.
		 03h
		 Firmware or software incompatibility detected with associated Entity.
		 04h
		 Entity is of an invalid or unsupported hardware version.
		 05h
		 Entity contains an invalid or unsupported firmware or software version.
		 06h
		 Hardware Change detected with associated Entity was successful. (deassertion event means ‘unsuccessful’).
		 07h
		 Software or F/W Change detected with associated Entity was successful. (deassertion event means ‘unsuccessful’)Event data 2 can be used for additional event information on the type of version change, with the following definition:
		 Event Data 2
			 7:0 Version change type
			 00h unspecified
			 01h management controller device ID (change in one or more fields from ‘Get Device ID’)
			 02h management controller firmware revision
			 03h management controller device revision
			 04h management controller manufacturer ID
			 05h management controller IPMI version
			 06h management controller auxiliary firmware ID
			 07h management controller firmware boot block
			 08h other management controller firmware
			 09h system firmware (EFI / BIOS) change
			 0Ah SMBIOS change
			 0Bh operating system change
			 0Ch operating system loader change
			 0Dh service or diagnostic partition change
			 0Eh management software agent change
			 0Fh management software application change
			 10h management software middleware change
			 11h programmable hardware change (e.g. FPGA)
			 12h board/FRU module change (change of a module plugged into associated entity)
			 13h board/FRU component change (addition or removal of a replaceable component on the board/FRU that is not tracked as a FRU)
			 14h board/FRU replaced with equivalent version
			 15h board/FRU replaced with newer version
			 16h board/FRU replaced with older version
			 17h board/FRU hardware configuration change (e.g. strap, jumper, cable change, etc.)"|tee -a SE.log;;
	'2c') echo -e " $SN is ${color_green}FRU State type${color_reset}"|tee -a SE.log
		  echo " Event Offset"|tee -a SE.log
		  echo " 
		 00h
		 FRU Not Installed
		 01h
		 FRU Inactive (in standby or ‘hot spare’ state)
		 02h
		 FRU Activation Requested
		 03h
		 FRU Activation In Progress
		 04h
		 FRU Active
		 05h
		 FRU Deactivation Requested
		 06h
		 FRU Deactivation In Progress
		 07h
		 FRU Communication Lost
		 The Event Data 2 field for this command can be used to provide the cause of the state change and the previous state:
			 7:4 Cause of state change
			 0h = Normal State Change.
			 1h = Change Commanded by software external to FRU.
			 2h = State Change due to operator changing a Handle latch.
			 3h = State Change due to operator pressing the hot swap push button.
			 4h = State Change due to FRU programmatic action.
			 5h = Communication Lost.
			 6h = Communication Lost due to local failure.
			 7h = State Change due to unexpected extraction.
			 8h = State Change due to operator intervention/update.
			 9h = Unable to compute IPMB address.
			 Ah = Unexpected Deactivation.
			 Fh = State Change, Cause Unknown.
			 All other = reserved
			 3:0 Previous state offset value (return offset for same state as present state if previous state is unknown)
			 All other = reserved."|tee -a SE.log;;
	*) echo -e " $SN is ${color_green}Reserved or OEM type, check the Spec please${color_reset}"|tee -a SE.log;;
	esac

	case $GST2 in
	01) echo -e " $SN is ${color_green}Threshold(0x01) Event/Reading class${color_reset}"|tee -a SE.log
		echo " Generic Offset"|tee -a SE.log
		echo " 
		 00h
		 Lower Non-critical - going low
		 01h
		 Lower Non-critical - going high
		 02h
		 Lower Critical - going low
	 	 03h
		 Lower Critical - going high
		 04h
		 Lower Non-recoverable - going low
		 05h
		 Lower Non-recoverable - going high
		 06h
		 Upper Non-critical - going low
		 07h
		 Upper Non-critical - going high
		 08h
		 Upper Critical - going low
		 09h
		 Upper Critical - going high
		 0Ah
		 Upper Non-recoverable - going low
		 0Bh
		 Upper Non-recoverable - going high"|tee -a SE.log;;
	02) echo -e " $SN is ${color_green}Discrete(0x02) Event/Reading class${color_reset}"|tee -a SE.log
		echo " DMI-based “Usage State” STATES"|tee -a SE.log
		echo " Generic Offset"|tee -a SE.log
		echo " 
		 00h
		 Transition to Idle
		 01h
		 Transition to Active
		 02h
		 Transition to Busy"|tee -a SE.log;;
	03) echo -e " $SN is ${color_green}'digital' Discrete(0x03) Event/Reading class${color_reset}"|tee -a SE.log
		echo " DIGITAL/DISCRETE EVENT STATES"|tee -a SE.log
		echo " Generic Offset"|tee -a SE.log
		echo " 
		 00h
		 State Deasserted
		 01h
		 State Asserted"|tee -a SE.log;;
	04) echo -e " $SN is ${color_green}'digital' Discrete(0x04) Event/Reading class${color_reset}"|tee -a SE.log
		echo " DIGITAL/DISCRETE EVENT STATES"|tee -a SE.log
		echo " Generic Offset"|tee -a SE.log
		echo " 
		 00h
		 Predictive Failure deasserted
		 01h
		 Predictive Failure asserted"|tee -a SE.log;;
	05) echo -e " $SN is ${color_green}'digital' Discrete(0x05) Event/Reading class${color_reset}"|tee -a SE.log
		echo " DIGITAL/DISCRETE EVENT STATES"|tee -a SE.log
		echo " Generic Offset"|tee -a SE.log
		echo " 
		 00h
		 Limit Not Exceeded
		 01h
		 Limit Exceeded"|tee -a SE.log;;
	06) echo -e " $SN is ${color_green}'digital' Discrete(0x06) Event/Reading class${color_reset}"|tee -a SE.log
		echo " DIGITAL/DISCRETE EVENT STATES"|tee -a SE.log
		echo " Generic Offset"|tee -a SE.log
		echo " 
		 00h
		 Performance Met
		 01h
		 Performance Lags"|tee -a SE.log;;
	07) echo -e " $SN is ${color_green}Discrete(0x07) Event/Reading class${color_reset}"|tee -a SE.log
		echo " SEVERITY EVENT STATES"|tee -a SE.log
		echo " Generic Offset"|tee -a SE.log
		echo " 
		 00h
		 transition to OK
		 01h
		 transition to Non-Critical from OK
		 02h
		 transition to Critical from less severe
		 03h
		 transition to Non-recoverable from less severe
		 04h
		 transition to Non-Critical from more severe
		 05h
		 transition to Critical from Non-recoverable
		 06h
		 transition to Non-recoverable
		 07h
		 Monitor
		 08h
		 Informational"|tee -a SE.log;;
	08) echo -e " $SN is ${color_green}'digital' Discrete(0x08) Event/Reading class${color_reset}"|tee -a SE.log
		echo " AVAILABILITY STATUS STATES"|tee -a SE.log
		echo " Generic Offset"|tee -a SE.log
		echo " 
		 00h
		 Device Removed / Device Absent
		 01h
		 Device Inserted / Device Present"|tee -a SE.log;;
	09) echo -e " $SN is ${color_green}'digital' Discrete(0x09) Event/Reading class${color_reset}"|tee -a SE.log
		echo " AVAILABILITY STATUS STATES"|tee -a SE.log
		echo " Generic Offset"|tee -a SE.log
		echo " 
		 00h
		 Device Disabled
		 01h
		 Device Enabled"|tee -a SE.log;;
	'0a') echo -e " $SN is ${color_green}Discrete(0x0a) Event/Reading class${color_reset}"|tee -a SE.log
		  echo " AVAILABILITY STATUS STATES"|tee -a SE.log
		  echo " Generic Offset"|tee -a SE.log
		  echo " 
		 00h
		 transition to Running
		 01h
		 transition to In Test
		 02h
		 transition to Power Off
		 03h
		 transition to On Line
		 04h
		 transition to Off Line
		 05h
		 transition to Off Duty
		 06h
		 transition to Degraded
		 07h
		 transition to Power Save
		 08h
		 Install Error"|tee -a SE.log;;
	'0b') echo -e " $SN is ${color_green}Discrete(0x0b) Event/Reading class${color_reset}"|tee -a SE.log
		  echo " Other AVAILABILITY STATUS STATES"|tee -a SE.log
		  echo " Generic Offset"|tee -a SE.log
		  echo " 
		 Redundancy States
		 00h
		 Fully Redundant (formerly “Redundancy Regained”) Indicates that full redundancy has been regained.
		 01h
		 Redundancy Lost Entered any non-redundant state, including Non-redundant:Insufficient Resources.
		 02h
		 Redundancy Degraded Redundancy still exists, but at a less than full level. For example, a system has four fans, and can tolerate the failure of two of them, and presently one has failed.
		 03h
		 Non-redundant:Sufficient Resources from Redundant Redundancy has been lost but unit is functioning with minimum resources needed for ‘normal’ operation. Entered from Redundancy Degraded or Fully Redundant.
		 04h
		 Non-redundant:Sufficient Resources from Insufficient Resources Unit has regained minimum resources needed for ‘normal’ operation. Entered from Non-redundant:Insufficient Resources.
		 05h
		 Non-redundant:Insufficient Resources Unit is non-redundant and has insufficient resources to maintain normal operation.
		 06h
		 Redundancy Degraded from Fully Redundant Unit has lost some redundant resource(s) but is still in a redundant state. Entered by a transition from Fully Redundant condition.
		 07h
		 Redundancy Degraded from Non-redundant Unit has regained some resource(s) and is redundant but not fully redundant. Entered from Non-redundant:Sufficient Resources or Non-redundant:Insufficient Resources."|tee -a SE.log;;
	'0c') echo -e " $SN is ${color_green}Discrete(0x0c) Event/Reading class${color_reset}"|tee -a SE.log
		 echo " Other AVAILABILITY STATUS STATES"|tee -a SE.log
		 echo " Generic Offset"|tee -a SE.log
		 echo " 
		 ACPI Device Power States
		 00h
		 D0 Power State
		 01h
		 D1 Power State
		 02h
		 D2 Power State
		 03h
		 D3 Power State"|tee -a SE.log;;
	esac

	echo -e "${color_blue} Get Sensor Type Command finished ${color_reset}"|tee -a SE.log
fi

echo ""|tee -a SE.log

# raw 0x04 0x2e 0x0c 0x0c OEM sensor type and discrete event/reading type
echo " Set Sensor Type Command"|tee -a SE.log
echo " Response below :" |tee -a SE.log
$i 0x2e $SID 0x0c 0x0c 
if [ ! $?==0 ] ; then
	$i 0x2e $SID 0x0c 0x0c >> SE.log
	echo -e " ${color_red} Set Sensor Type Command failed ${color_reset}"|tee -a SE.log
	FailCounter=$(($FailCounter+1))
else
	$i 0x2e $SID 0x0c 0x0c >> SE.log
	if [ "$($i 0x2f $SID)"=="0c 0c" ];then
		echo -e "${color_blue} Set Sensor Type Command finished${color_reset}"|tee -a SE.log
		echo " Restore sensor type and event/reading type to default..."
		$i 0x2e $SID 0x$GST1 0x$GST2
		echo " Restore finished..."
	else
		echo -e " ${color_red} Set Sensor Type Command failed ${color_reset}"|tee -a SE.log
		FailCounter=$(($FailCounter+1))
	fi
fi

echo ""|tee -a SE.log
echo ===============================================================================================|tee -a SE.log
echo ""|tee -a SE.log
if [ ! $FailCounter == 0 ]; then
	echo -e "${color_red} Sensor&Event function test finished but has some command failed check the SE.log please.${color_reset}"
else
	echo -e "${color_blue} Sensor&Event function test finished. Please check the SE.log${color_reset}"
fi
