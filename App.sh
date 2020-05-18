#!/bin/bash

echo -e "${color_red}Remove and backup the previous log as date format...${color_reset}"
read -t 10 -p "Wait for 10 seconds to clear..."
if [ -f "App.log" ]; then
	cp App.log $(date +%Y%m%d_%T)_App.log && rm -f App.log
fi

date|tee -a App.log
read OSInfo <<< $(cat /etc/redhat-release)
echo "$USER start testing in $OSInfo..."|tee -a App.sh.log

#read -p "Enter the BMC channel with 0XFF format: " Ch
Ch="$ipmi 0x06 0x42 0x0e|cut -d " " -f 2"
i="ipmitool raw 0x06"
sleep 1
color_reset='\e[0m'
color_green='\e[32m'
color_red='\e[31m'
color_convert='\e[7m'
color_blue='\e[34m'
date |tee -a App.log
FailCounter=0
#printf '\x5F' | xxd -b | cut -d' ' -f2 
#$((#16$hex))
##Convert Dec to Binary
D2B=({0..1}{0..1}{0..1}{0..1}{0..1}{0..1}{0..1}{0..1})
##Convert Dec to Binary with space
D2BS=({0..1}' '{0..1}' '{0..1}' '{0..1}' '{0..1}' '{0..1}' '{0..1}' '{0..1})
function H2B () {                                                                              
        L=${1:0:1}                                                                             
        R=${1:1:1}                                                                             
        if grep '^[[:digit:]]*$' <<< "$L" ; then                                               
                let L1=$(($L/2/2/2%2)) L2=$(($L/2/2%2)) L3=$(($L/2%2)) L4=$(($L%2))            
        else                                                                                   
                let L1=$((16#$L/2/2/2%2)) L2=$((16#$L/2/2%2)) L3=$((16#$L/2%2)) L4=$((16#$L%2))
        fi                                                                                     
        if grep '^[[:digit:]]*$' <<< "$R"; then                                                
                let R1=$(($R/2/2/2%2)) R2=$(($R/2/2%2)) R3=$(($R/2%2)) R4=$(($R%2))            
        else                                                                                   
                let R1=$((16#$R/2/2/2%2)) R2=$((16#$R/2/2%2)) R3=$((16#$R/2%2)) R4=$((16#$R%2))
        fi                                                                                     
        echo $L$R                                                                              
        echo $L1$L2$L3$L4$R1$R2$R3$R4                                                          
}

#Watchdog

echo -e " ${color_convert} Set Watchdog timer Command${color_reset} " |tee -a  App.log
echo " Response below :" |tee -a App.log
echo " Test BIOS FRB2, BIOS/POST, 011b = OS Load, 100b = SMS/OS timer" |tee -a App.log
for j in {1..4};do
	for k in 10 20 30;
		$i 0x24 0x0$j 0x$k 0x01 0x3e 0x01 0x00
		if [ ! $? -eq '0' ] ; then
			$i 0x24 0x0$j 0x$k 0x01 0x3e 0x01 0x00 >> App.log
			echo "timer use : $j, pre-timeout interrupt : $k"|tee -a App.log
			echo -e "${color_red} Set Watchdog timer Command failed ${color_reset}"|tee -a App.log
			FailCounter=$(($FailCounter+1))
			Fail24=1
		else
			echo "Reset Watchdog timer.."|tee -a App.log
			$i 0x22 
			sleep 3 
			if [ -n "$($i sel elist |grep -i watchdog)" ];then
				echo -e "${color_blue} Set & Reset Watchdog Command finished.${color_reset}"|tee -a App.log
				$i sel clear
			else
				echo "timer use : $j, pre-timeout interrupt : $k"|tee -a App.log
				echo -e "${color_red} Watchdog timer doesn't log ${color_reset}"|tee -a App.log
				FailCounter=$(($FailCounter+1))
				Fail24=1
			fi
		fi
	done
done
echo ""|tee -a App.log

# raw 0x06 0x01
echo ""|tee -a App.log
echo -e " ${color_convert}Get Device ID${color_reset} " |tee -a  App.log
echo " Response below :" |tee -a App.log
$i 0x01
if [ ! $? -eq '0' ] ; then
	$i 0x01 >> App.log
	echo -e "${color_red} Get Device ID failed ${color_reset}"|tee -a App.log
	FailCounter=$(($FailCounter+1))
	Fail1=1
else
	$i 0x01 >> App.log
	echo =====================Device ID info======================== |tee -a App.log
	read DI1 DI2 DI3 DI4 DI5 DI6 DI7 DI8 DI9 DI10 DI11 DI12 DI13 DI14 DI15 <<< $($i 0x01)
	echo -e " The SUT device ID is ${color_green}$DI1${color_reset} (hex)" |tee -a App.log
	echo "" |tee -a App.log
	for j in DI{2..15}; do
		eval temp=\$$j
		temp=${D2B[$((16#$temp))]}
		read $j'b1' $j'b2' $j'b3' $j'b4' $j'b5' $j'b6' $j'b7' $j'b8' <<< "${temp:0:1} ${temp:1:1} ${temp:2:1} ${temp:3:1} ${temp:4:1} ${temp:5:1} ${temp:6:1} ${temp:7:1}"
	done
	DR=$((2#$DI2b5$DI2b6$DI2b7$DI2b8))
	echo '' |tee -a App.log
	# DI5 IPMI version 
	if [ $DI5 -eq "51" ];then
		echo " This SUT's IPMI version is 1.5." |tee -a App.log
	elif [ $DI5 -eq "02" ];then
		echo " This SUT's IPMI version is 2.0." |tee -a App.log
	fi
	echo ''|tee -a App.log
	#DI2 Device Revision
	echo -e " This device revision is ${color_green}$DR.${color_reset}" |tee -a App.log
	if [ $DI2b1 -eq "1" ];then
		echo -e " ${color_green}This device provides Device SDRs${color_reset}." |tee -a App.log
	else
		echo -e " ${color_red}This device doesn't provide Device SDRs.${color_reset}" |tee -a App.log
	fi
	echo '' |tee -a App.log
	#DI3 DI4 Firmware revision
	if [ $DI3b1 -eq "1" ];then
		echo " Device firmware, SDR Repository update or self-initialization in progress." |tee -a App.log
	else
		echo " Normal operation." |tee -a App.log
	fi
	FR=$((2#$DI3b2$DI3b3$DI3b4$DI3b5$DI3b6$DI3b7$DI3b8))
	echo -e " BMC firmware version : ${color_green}$FR $DI4${color_reset}"|tee -a App.log
	echo '' |tee -a App.log
	#DI6 IPMI command and function support list
	echo " This Device support the command and function below :" |tee -a App.log
	if [ $DI6b1 -eq "1" ] ;then 
		echo " Chassis Device (device functions as chassis device per ICMB spec.)" |tee -a App.log
	fi
	if [ $DI6b2 -eq "1" ];then 
		echo " Bridge (device responds to Bridge NetFn commands)" |tee -a App.log
	fi
	if [ $DI6b3 -eq "1" ];then 
		echo " IPMB Event Generator (device generates event messages [platform event request messages] onto the IPMB)" |tee -a App.log
	fi
	if [ $DI6b4 -eq "1" ];then 
		echo " IPMB Event Receiver (device accepts event messages [platform event request messages] from the IPMB)" |tee -a App.log
	fi
	if [ $DI6b5 -eq "1" ];then 
		echo " FRU Inventory Device" |tee -a App.log
	fi
	if [ $DI6b6 -eq "1" ];then 
		echo " SEL Device" |tee -a App.log
	fi
	if [ $DI6b7 -eq "1" ];then 
		echo " SDR Repository Device" |tee -a App.log
	fi
	if [ $DI6b8 -eq "1" ];then 
		echo " Sensor Device" |tee -a App.log
	fi
	echo '' |tee -a App.log
	#DI7 DI8 DI9 Manufacturer ID
	MI=$((16#$DI9$DI8$DI7))
	echo -e " Manufacturer ID is : ${color_green}$MI${color_reset} | Please goto https://www.iana.org/assignments/enterprise-numbers/enterprise-numbers to chekc with the Enterprise number" |tee -a App.log
	echo '' |tee -a App.log
	#DI10 DI11 Product ID
	echo -e " Product ID is ${color_green}$DI11 $DI10${color_reset}" |tee -a App.log
	echo '' |tee -a App.log
	#DI12 DI13 DI14 DI15 Auxiliary Firmware Revision Information
	echo -e " Auxiliary Firmware Revision Information is defined by Manufacturer ID : ${color_green}$DI12 $DI13 $DI14 $DI15${color_reset}" |tee -a App.log
	echo '' |tee -a App.log
	echo -e " ${color_blue}Get Device ID finished${color_reset}" |tee -a App.log
fi
echo ""|tee -a App.log
# raw 0x06 0x02 
echo -e " ${color_convert}BMC Cold Rest ${color_reset}" |tee -a  App.log
echo " Response below :" |tee -a App.log
$i 0x02
if [ ! $? -eq '0' ] ; then
	echo -e "${color_red} BMC Cold Reset failed ${color_reset}"|tee -a App.log
	FailCounter=$(($FailCounter+1))
	Fail2=1
else
	echo " BMC Cold Restting... Wait for BMC initializing..."
	sleep 180
	CRC=0
	while [ ! "$($i 0x01)" ] && [ $CRC -le 35 ]
	do
		sleep 5
		let CRC=$CRC+1
	done
	echo -e "${color_blue} BMC Cold Rest finished.${color_reset}"|tee -a App.log
fi
echo ""|tee -a App.log
# raw 0x06 0x03
#echo -e " ${color_convert}BMC Warm Rest${color_reset} " |tee -a  App.log
#echo " Response below :" |tee -a App.log
#$i 0x03
#if [ ! $? -eq '0' ] ; then
#	echo -e "${color_red} BMC Warm Reset failed ${color_reset}"|tee -a App.log
#	FailCounter=$(($FailCounter+1))
#else
#	echo " BMC Warm Restting... Wait for BMC initializing..."
#	sleep 90
#	WRC=0
#	while [ ! "$($i 0x01)" ] && [ $WRC -le 35 ]
#	do
#		sleep 5
#		let WRC=$WRC+1
#	done
#		echo -e " ${color_blue}BMC Warm Rest finished${color_reset}."|tee -a App.log
#fi
echo ""|tee -a App.log
# raw 0x06 0x04
echo -e " ${color_convert}BMC Self Test${color_reset} " |tee -a  App.log
echo " Response below :" |tee -a App.log
$i 0x04
if [ ! $? -eq '0' ] ; then
	$i 0x04 >> App.log
	echo -e "${color_red} BMC Self Test failed ${color_reset}"|tee -a App.log
	FailCounter=$(($FailCounter+1))
	Fail4=1
else
	$i 0x04 >> App.log
	read BST1 BST2 <<< $($i 0x04)
	for j in BST{1..2}; do
		eval temp=\$$j
		temp=${D2B[$((16#$temp))]}
		read $j'b1' $j'b2' $j'b3' $j'b4' $j'b5' $j'b6' $j'b7' $j'b8' <<< "${temp:0:1} ${temp:1:1} ${temp:2:1} ${temp:3:1} ${temp:4:1} ${temp:5:1} ${temp:6:1} ${temp:7:1}"
	done
	case $BST1 in
	'55') echo -e " ${color_green}No error${color_reset}. All Self Tests Passed${color_reset}."|tee -a App.log;;
	'56') echo -e " ${color_red}Self Test function not implemented in this controller${color_reset}."|tee -a App.log;;
	'57') echo -e " ${color_red}Corrupted or inaccessible data or devices${color_reset}"|tee -a App.log
	      FailCounter=$(($FailCounter+1))
		  if [ $BST2b1 -eq '1' ];then
			echo -e " ${color_red}Cannot access SEL device${color_reset}"|tee -a App.log
		  else
		    echo -e " ${color_red}SEL device Unknown fail${color_rest}"|tee -a App.log
		  fi
		  if [ $BST2b2 -eq '1' ];then
			echo -e " ${color_red}Cannot access SDR Repository${color_reset}"|tee -a App.log
		  else
		    echo -e " ${color_red}SDR Repository Unknown fail${color_rest}"|tee -a App.log
		  fi
		  if [ $BST2b3 -eq '1' ];then
			echo -e " ${color_red}Cannot access BMC FRU device${color_reset}"|tee -a App.log
		  else
		    echo -e " ${color_red}FRU device Unknown fail${color_rest}"|tee -a App.log
		  fi
		  if [ $BST2b4 -eq '1' ];then
			echo -e " ${color_red}IPMB signal lines do not respond${color_reset}"|tee -a App.log
		  else
		    echo -e " ${color_red}IPMB signal Unknown fail${color_rest}"|tee -a App.log
		  fi
		  if [ $BST2b5 -eq '1' ];then
			echo -e " ${color_red}SDR Repository empty${color_reset}"|tee -a App.log
		  fi
		  if [ $BST2b6 -eq '1' ];then
			echo -e " ${color_red}Internal Use Area of BMC FRU corrupted${color_reset}"|tee -a App.log
		  fi
		  if [ $BST2b7 -eq '1' ];then
			echo -e " ${color_red}controller update ‘boot block’ firmware corrupted${color_reset}"|tee -a App.log
		  fi
		  if [ $BST2b8 -eq '1' ];then
			echo -e " ${color_red}controller operational firmware corrupted${color_reset}"|tee -a App.log
		  fi;;
	'58') echo -e " ${color_red}Fatal hardware error (system should consider BMC inoperative). This will indicate that the controller hardware (including associated devices such as sensor hardware or RAM) may need to be repaired or replaced${color_reset}."|tee -a App.log 
	FailCounter=$(($FailCounter+1));;
	.) echo -e " ${color_green}Device-specific ‘internal’ failure. Refer to the particular device’s specification for definition${color_reset}."|tee -a App.log 
	   FailCounter=$(($FailCounter+1));;
	esac
fi

echo ""|tee -a App.log

# raw 0x06 0x05
echo -e " ${color_convert} Manufacturing Test On Command${color_reset} "|tee -a App.log
echo " Response below :" |tee -a App.log
$i 0x05
if [ ! $? -eq '0' ] ; then
	echo -e "${color_red} Manufacturing Test On failed ${color_reset}"|tee -a App.log
	FailCounter=$(($FailCounter+1))
	Fail5=1
else
	echo -e "${color_blue} Manufacturing Test On finished.${color_reset}"|tee -a App.log
fi
echo ""|tee -a App.log

# raw 0x06 0x06
echo -e " ${color_convert} Set ACPI Power State Command${color_reset} " |tee -a  App.log
echo " Response below :" |tee -a App.log
ACPI="80 81 82 83 84 85 86 87 88 89 8a a0 a1 aa ff"
ACPID="80 81 82 83 aa ff"
ACPIFailCounter=0
for j in $ACPI
do
	for k in $ACPID 
	do 
		$i 0x06 0x$j 0x$k > /dev/null
		if [ ! $? -eq '0' ] ; then
			echo -e "${color_red} Set ACPI Power State 0x$j 0x$k failed ${color_reset}"|tee -a App.log
			ACPIFailCounter=$(($ACPIFailCounter+1))
			FailCounter=$(($FailCounter+1))
			Fail6=1
		fi
	done
done
if [ $ACPIFailCounter -eq '0' ];then
	$i 0x06 0x80 0x80
	echo -e "${color_blue} Set all ACPI Power State finished.${color_reset}"|tee -a App.log
	echo " Set APCI Power State to S0 and Device Power State D0..."
fi

# raw 0x06 0x07
echo -e " ${color_convert} Get ACPI Power State Command${color_reset} " |tee -a  App.log
echo " Response below :" |tee -a App.log
$i 0x07
if [ ! $? -eq '0' ] ; then
	$i 0x07 >> App.log
	echo -e "${color_red} Get ACPI Power State Command failed ${color_reset}"|tee -a App.log
	FailCounter=$(($FailCounter+1))
	Fail7=1
else
	if [ "$i 0x07"=="00 00" ];then
		$i 0x07 >> App.log
		echo -e "${color_blue} Get ACPI Power State Command finished.${color_reset}"|tee -a App.log
	fi
echo ""|tee -a App.log
fi

# raw 0x06 0x08
echo -e " ${color_convert} Get Device GUID Command${color_reset} " |tee -a  App.log
echo " Response below :" |tee -a App.log
$i 0x08
if [ ! $? -eq '0' ] ; then
	$i 0x08 >> App.log
	echo -e "${color_red} Get Device GUID Command failed ${color_reset}"|tee -a App.log
	FailCounter=$(($FailCounter+1))
	Fail8=1
else
	echo -e "${color_blue} Get Device GUID Command finished.${color_reset}"|tee -a App.log
fi
echo ""|tee -a App.log

# raw 0x06 0x09
echo -e " ${color_convert} Get NetFn Support Command${color_reset} " |tee -a  App.log
echo " Response below :" |tee -a App.log
$i 0x09 0x$Ch
if [ ! $? -eq '0' ] ; then
	$i 0x09 0x$Ch >> App.log
	echo -e "${color_red} Get NetFn Support in channel $Ch Command failed ${color_reset}"|tee -a App.log
	FailCounter=$(($FailCounter+1))
	Fail9=1
else
	$i 0x09 0x$Ch >> App.log
	read GNS1 GNS2 GNS3 GNS4 GNS5 GNS6 GNS7 GNS8 GNS9 GNS10 GNS11 GNS12 GNS13 GNS14 GNS15 GNS16 GNS17 <<< $($i 0x09 $Ch)
	for j in GNS{1..17}; do
		eval temp=\$$j
		temp=${D2B[$((16#$temp))]}
		read $j'b1' $j'b2' $j'b3' $j'b4' $j'b5' $j'b6' $j'b7' $j'b8' <<< "${temp:0:1} ${temp:1:1} ${temp:2:1} ${temp:3:1} ${temp:4:1} ${temp:5:1} ${temp:6:1} ${temp:7:1}"
	done
	case $GNS1b1$GNS1b2 in
		00) echo -e " ${color_green} No LUN 3 (11b) support${color_reset}"|tee -a App.log;;
		01) echo -e " ${color_green} Base IPMI Commands exist on LUN 3 (11b) support${color_reset}"|tee -a App.log;;
		10) echo -e " ${color_green} Commands exist on LUN 3 (11b) support but some commands/operations may be restricted by firewall configuration ${color_reset}"|tee -a App.log;;
		11) echo -e " ${color_red} LUN 3 (11b) support but this byte is reserved please check the Spec.${color_reset}"|tee -a App.log;;
	esac
	case $GNS1b3$GNS1b4 in
		00) echo -e " ${color_green} No LUN 2 (10b) support${color_reset}"|tee -a App.log;;
		01) echo -e " ${color_green} Base IPMI Copmmands exist on LUN 2 (10b) support${color_reset}"|tee -a App.log;;
		10) echo -e " ${color_green} Commands exist on LUN 2 (10b) support but some commands/operations may be restricted by firewall configuration ${color_reset}"|tee -a App.log;;
		11) echo -e " ${color_red} LUN 2 (10b) support but this byte is reserved please check the Spec.${color_reset}"|tee -a App.log;;
	esac
	case $GNS1b5$GNS1b6 in
		00) echo -e " ${color_green} No LUN 1 (01b) support${color_reset}"|tee -a App.log;;
		01) echo -e " ${color_green} Base IPMI Commands exist on LUN 1 (01b) support${color_reset}"|tee -a App.log;;
		10) echo -e " ${color_green} Commands exist on LUN 1 (01b) support but some commands/operations may be restricted by firewall configuration ${color_reset}"|tee -a App.log;;
		11) echo -e " ${color_red} LUN 1 (01b) support but this byte is reserved please check the Spec.${color_reset}"|tee -a App.log;;
	esac
	case $GNS1b7$GNS1b8 in
		00) echo -e " ${color_green} No LUN 0 (00b) support${color_reset}"|tee -a App.log;;
		01) echo -e " ${color_green} Base IPMI Commands exist on LUN 0 (00b) support${color_reset}"|tee -a App.log;;
		10) echo -e " ${color_green} Commands exist on LUN 0 (00b) support but some commands/operations may be restricted by firewall configuration ${color_reset}"|tee -a App.log;;
		11) echo -e " ${color_red} LUN 0 (00b) support but this byte is reserved please check the Spec.${color_reset}"|tee -a App.log;;
	esac
	echo ""|tee -a App.log
	if [ ! $GNS1b7$GNS1b8 -eq "00" ];then
		tmp="${D2BS[$((16#$GNS2))]} ${D2BS[$((16#$GNS3))]} ${D2BS[$((16#$GNS4))]} ${D2BS[$((16#$GNS5))]}"
		ArrayNetFn=($tmp)
		NetFnCounter0=0
		for k in {0..31}
		do
			if [ ${ArrayNetFn[$k]} -eq "1" ];then
				read htmp <<< `echo "obase=16; $(($k*2))"|bc`
				#read htmp1 <<< `echo "obase=16; $((($k*2)+1))"|bc`
				NetFnLUN0="$NetFnLUN0 0x$htmp"
				NetFnCounter0=$(($NetFnCounter0+1))
			fi
		done
		
		echo -e " ${color_green} NetFn pairs $NetFnLUN0 is used for LUN 00b${color_reset}"|tee -a App.log
		echo ""|tee -a App.log
	fi
	if [ ! $GNS1b5$GNS1b6 -eq "00" ];then
		tmp="${D2BS[$((16#$GNS6))]} ${D2BS[$((16#$GNS7))]} ${D2BS[$((16#$GNS8))]} ${D2BS[$((16#$GNS9))]}"
		ArrayNetFn=($tmp)
		NetFnCounter1=0
		for k in {0..31}
		do
			if [ ${ArrayNetFn[$k]} -eq "1" ];then
				read htmp <<< `echo "obase=16; $(($k*2))"|bc`
				#read htmp1 <<< `echo "obase=16; $((($k*2)+1))"|bc`
				NetFnLUN1="$NetFnLUN1 0x$htmp"
				NNetFnCounter1=$(($NetFnCounter1+1))
			fi
		done
		echo -e " ${color_green} NetFn pairs$NetFnLUN1 is used for LUN 01b${color_reset}"|tee -a App.log
		echo ""|tee -a App.log
	fi
	if [ ! $GNS1b3$GNS1b4 -eq "00" ];then
		tmp="${D2BS[$((16#$GNS10))]} ${D2BS[$((16#$GNS11))]} ${D2BS[$((16#$GNS12))]} ${D2BS[$((16#$GNS13))]}"
		ArrayNetFn=($tmp)
		for k in {0..31}
		do
			if [ ${ArrayNetFn[$k]} -eq "1" ];then
				read htmp <<< `echo "obase=16; $(($k*2))"|bc`
				#read htmp1 <<< `echo "obase=16; $((($k*2)+1))"|bc`
				NetFnLUN2="$NetFnLUN2 0x$htmp"
				NetFnCounter2=$(($NetFnCounter2+1))
			fi
		done
		echo -e " ${color_green} NetFn pairs$NetFnLUN2 is used for LUN 10b${color_reset}"|tee -a App.log
		echo ""|tee -a App.log
	fi
	if [ ! $GNS1b1$GNS1b2 -eq "00" ];then
		tmp="${D2BS[$((16#$GNS14))]} ${D2BS[$((16#$GNS15))]} ${D2BS[$((16#$GNS16))]} ${D2BS[$((16#$GNS17))]}"
		ArrayNetFn=($tmp)
		for k in {0..31}
		do
			if [ ${ArrayNetFn[$k]} -eq "1" ];then	
				read htmp <<< `echo "obase=16; $(($k*2))"|bc`
				#read htmp1 <<< `echo "obase=16; $((($k*2)+1))"|bc`
				NetFnLUN3="$NetFnLUN3 0x$htmp"
				NetFnCounter3=$(($NetFnCounter3+1))
			fi
		done
		echo -e " ${color_green} NetFn pairs$NetFnLUN3 is used for LUN 11b${color_reset}"|tee -a App.log
		echo ""|tee -a App.log
	fi
	echo -e "${color_blue} Get NetFn Support in channel 0x$Ch Command finished.${color_reset}"|tee -a App.log
fi

echo ""|tee -a App.log

# raw 0x06 0x0a
#echo -e " ${color_convert} Get Command Support Command ${color_reset} " |tee -a  App.log
#echo  " This command will test which Netfn the SUT support "|tee -a App.log
#echo " Response below :" |tee -a App.log
#if [ ! $GNS1b7$GNS1b8 -eq "00" ];then
#	#eval read NFS{1..$NetFnCounter0} <<< "$NetFnLUN0"
#	for j in $NetFnLUN0
#	do
#		read NFS{1..16} <<< $($i 0x0a $Ch $j 0x00)
#		tmp="${D2BS[$((16#$NFS1))]} ${D2BS[$((16#$NFS2))]} ${D2BS[$((16#$NFS3))]} ${D2BS[$((16#$NFS4))]} ${D2BS[$((16#$NFS5))]} ${D2BS[$((16#$NFS6))]} ${D2BS[$((16#$NFS7))]} ${D2BS[$((16#$NFS8))]}"
#		tmp1=" ${D2BS[$((16#$NFS9))]} ${D2BS[$((16#$NFS10))]} ${D2BS[$((16#$NFS11))]} ${D2BS[$((16#$NFS12))]} ${D2BS[$((16#$NFS13))]} ${D2BS[$((16#$NFS14))]} ${D2BS[$((16#$NFS15))]} ${D2BS[$((16#$NFS16))]}"
#		echo $tmp$tmp1
#		#寫到都不知道在寫甚麼了.. 崩潰 By Lily_Hou 
#		ArrayNFS=($tmp$tmp1)
#		for k in {0..127}
#		do
#			if [ ${ArrayNFS[$k]} -eq "0" ];then
#				read htmp <<< `echo "obase=16; $k"|bc`
#				#讀取每個NetFn的可用command
#				CmdLUN0="$CmdLUN0 0x$htmp"
#			fi
#		done
#		read l <<< `echo "obase=16;$(($j+0x40))"|bc`
#		echo $l
#		read NFS{1..16} <<< $($i 0x0a $Ch 0x$l 0x00)
#		tmp=
#		tmp1=
#		ArrayNFS=
#		tmp="${D2BS[$((16#$NFS1))]} ${D2BS[$((16#$NFS2))]} ${D2BS[$((16#$NFS3))]} ${D2BS[$((16#$NFS4))]} ${D2BS[$((16#$NFS5))]} ${D2BS[$((16#$NFS6))]} ${D2BS[$((16#$NFS7))]} ${D2BS[$((16#$NFS8))]}"
#		tmp1=" ${D2BS[$((16#$NFS9))]} ${D2BS[$((16#$NFS10))]} ${D2BS[$((16#$NFS11))]} ${D2BS[$((16#$NFS12))]} ${D2BS[$((16#$NFS13))]} ${D2BS[$((16#$NFS14))]} ${D2BS[$((16#$NFS15))]} ${D2BS[$((16#$NFS16))]}"
#		ArrayNFS=($tmp$tmp1)
#		for k in {0..127}
#		do
#			if [ ${ArrayNFS[$k]} -eq "0" ];then
#				read htmp <<< `echo "obase=16; $(($k+0x80))"|bc`
#				#讀取每個NetFn的可用command
#				CmdLUN0="$CmdLUN0 0x$htmp"
#			fi
#		done
#
#		echo -e " ${color_green} NetFn $j available command :$CmdLUN0 ${color_reset}"|tee -a App.log
#	done	
#fi
#for j in {0..13}
#do
#case $j in
#	0) tmp="Chassis Request";;
#	1) tmp="Chassis Respond";;
#	2) tmp="Bridge Request";;
#	3) tmp="Bridge Respond";;
#	4) tmp="Sensor/Event Request";;
#	5) tmp="Sensor/Event Respond";;
#	6) tmp="App Request";;
#	7) tmp="App Responde";;
#	8) tmp="Firmware Request";;
#	9) tmp="Firmware Respond";;
#	10) tmp="Storage Request" && j=a;;
#	11) tmp="Storage Respond" && j=b;;
#	12) tmp="Transport Request" && j=c;;
#	13) tmp="Transport Respond" && j=d;;
#esac
#$i 0x0a $Ch 0x$j 0x00
#if [ ! $? -eq '0' ] ; then
#	$i 0x0a $Ch 0x$j 0x00 >> App.log
#	echo -e "${color_red} Get $tmp (0x0$j) Command Support Command (0x00-0x7f) failed ${color_reset}"|tee -a App.log
#	FailCounter=$(($FailCounter+1))
#else
#	Cmd[]=()
#	read  GCS{1..16} <<< $($i 0x0a $Ch 0x$j 0x00)
#	for j in GCS{1..16}; do
#		eval temp=\$$j
#		temp=${D2B[$((16#$temp))]}
#		read $j'b1' $j'b2' $j'b3' $j'b4' $j'b5' $j'b6' $j'b7' $j'b8' <<< "${temp:0:1} ${temp:1:1} ${temp:2:1} ${temp:3:1} ${temp:4:1} ${temp:5:1} ${temp:6:1} ${temp:7:1}"
#	for k in GCS$j'b{1..8}' 
#	do
#		eval temp=\$$k
#		if [ $temp -eq '0' ];then
#			Cmd[]+=$k
#		fi
#	done
#	echo $Cmd 
#	echo -e "${color_green} Get command support $Cmd ${color_reset}"|tee -a App.log
#	echo "Depending on the value of the “Operation” parameter passed in the request:"
#	echo "byte 1, bit 0 corresponds to command 00h"
#	echo "byte 1, bit 7 corresponds to command 07h"
#	echo "…"
#	echo "byte 16, bit 0 correspond to command 78h"
#	echo "byte 16, bit 7 corresponds to command 7Fh"
#fi
#	read k <<< `echo "obase=16; $((0x$j+0x40))"|bc`
#	$i 0x0a $Ch 0x$k 0x00
#	if [ ! $? -eq '0' ] ; then
#		$i 0x0a $Ch 0x$k 0x00 >> App.log
#		echo -e "${color_red} Get $tmp (0x$k) Command Support Command (0x80-0xff) failed ${color_reset}"|tee -a App.log
#		FailCounter=$(($FailCounter+1))
#	else
#		Cmd[]=()
#		read  GCS{1..16} <<< $($i 0x0a $Ch 0x$k 0x00)
#		for j in GCS{1..16}; do
#		eval temp=\$$j
#		temp=${D2B[$((16#$temp))]}
#		read $j'b1' $j'b2' $j'b3' $j'b4' $j'b5' $j'b6' $j'b7' $j'b8' <<< "${temp:0:1} ${temp:1:1} ${temp:2:1} ${temp:3:1} ${temp:4:1} ${temp:5:1} ${temp:6:1} ${temp:7:1}"
#		for k in GCS$j'b{1..8}' 
#		do
#			eval temp=\$$k
#			if [ $temp -eq '0' ];then
#				Cmd[]+=$k
#			fi
#		done
#		echo $Cmd 
#		echo -e "${color_green} Get command support $Cmd ${color_reset}"|tee -a App.log
#		echo "Depending on the value of the “Operation” parameter passed in the request:"
#		echo "byte 1, bit 0 corresponds to command 80h"
#		echo "byte 1, bit 7 corresponds to command 87h"
#		echo "…"
#		echo "byte 16, bit 0 corresponds to command F8h"
#		echo "byte 16, bit 7 corresponds to command FFh"
#		echo -e "${color_blue} Get $tmp (0x$k) Command Support Comand finished.${color_reset}"|tee -a App.log
#	fi
#	done
#done
#echo ""|tee -a App.log
#done 
# raw 0x06 0x0b
#echo -e " ${color_convert} Get Command Sub-function Support ${color_reset} " |tee -a  App.log
#echo " Response below :" |tee -a App.log
#for j in {0..13}
#do
#case $j in
#	0) tmp="Chassis Request";;
#	1) tmp="Chassis Respond";;
#	2) tmp="Bridge Request";;
#	3) tmp="Bridge Respond";;
#	4) tmp="Sensor/Event Request";;
#	5) tmp="Sensor/Event Respond";;
#	6) tmp="App Request";;
#	7) tmp="App Responde";;
#	8) tmp="Firmware Request";;
#	9) tmp="Firmware Respond";;
#	10) tmp="Storage Request" && j=a;;
#	11) tmp="Storage Respond" && j=b;;
#	12) tmp="Transport Request" && j=c;;
#	13) tmp="Transport Respond" && j=d;;
#esac
#$i 0x0a $Ch 0x0$j 0x00
#if [ ! $? -eq '0' ] ; then
#	$i 0x0a $Ch 0x0$j 0x00 >> App.log
#	echo -e "${color_red} Get $tmp (0x0$j) Command Support Command (0x00-0x7f) failed ${color_reset}"|tee -a App.log
#	FailCounter=$(($FailCounter+1))
#else
#	read  GCS{1..16} <<< $($i 0x0a $Ch 0x$j 0x00)
#	for j in GCS{1..16}; do
#		eval temp=\$$j
#		temp=${D2B[$((16#$temp))]}
#		read $j'b1' $j'b2' $j'b3' $j'b4' $j'b5' $j'b6' $j'b7' $j'b8' <<< "${temp:0:1} ${temp:1:1} ${temp:2:1} ${temp:3:1} ${temp:4:1} ${temp:5:1} ${temp:6:1} ${temp:7:1}"
#	done
#
#	m=0
#	for k in {0..127} 
#	do
#		if [ ${ArrayGCS[$k]} -eq '0' ];then
#			read htemp <<< `echo "obase=16; $k"|bc`
#			Cmd[$m]="$htemp"
#			let m=$m+1
#		fi
#	done
#	echo $Cmd 
#fi

#done
echo ""|tee -a App.log




#Set BMC Global Enable
echo -e " ${color_convert} Set BMC Global Enables Command to all enable ${color_reset} " |tee -a  App.log
echo " Response below :" |tee -a App.log
$i 0x2e 0x0f
if [ ! $? -eq '0' ] ; then
			$i 0x2e 0x0f >> App.log
			echo -e "${color_red} Set BMC Global Enables Command to all enable failed ${color_reset}"|tee -a App.log
			FailCounter=$(($FailCounter+1))
			Failf=1
		else
			if [ "$($i 0x2f)"=="0f"]; then
				echo -e "${color_green} Set BMC Global Enables Command to all enable success ${color_reset}"|tee -a App.log
			else
				echo -e "${color_red} Set BMC Global Enables Command to all enable fail that response not correct ${color_reset}"|tee -a App.log
				FailCounter=$(($FailCounter+1))
				Failf=1	
			fi
fi
echo -e "${color_blue} Set BMC Global all Enable Command finished.${color_reset}"|tee -a App.log
echo ""|tee -a App.log

#Clear Message flags command
echo -e " ${color_convert} Clear Message Flags Command ${color_reset} " |tee -a  App.log
echo " Response below :" |tee -a App.log
$i 0x2e 0x30 0x0b
if [ ! $? -eq '0' ] ; then
			$i 0x2e 0x30 0x0b >> App.log
			echo -e "${color_red} Clear Message Flags Command failed ${color_reset}"|tee -a App.log
			FailCounter=$(($FailCounter+1))
			Fail30=1
		else
			if [ "$($i 0x31)"=="0b"]; then
				echo -e "${color_green} Clear Message Flags Command success ${color_reset}"|tee -a App.log
			else
				echo -e "${color_red} Clear Message Flags Command fail that response not correct ${color_reset}"|tee -a App.log
				FailCounter=$(($FailCounter+1))
				Fail30=1
			fi
fi
echo -e "${color_blue} Clear Message Flags Command finished.${color_reset}"|tee -a App.log
echo ""|tee -a App.log

#Enable Message Channel Receive Command
echo -e " ${color_convert} Enable Message Channel Receive Command ${color_reset} " |tee -a  App.log
echo " Response below :" |tee -a App.log
$i 0x2e 0x32 0x$Ch 0x10
if [ ! $? -eq '0' ] ; then
			$i 0x2e 0x32 0x10 >> App.log
			echo -e "${color_red} Enable Message Channel Receive Command failed ${color_reset}"|tee -a App.log
			FailCounter=$(($FailCounter+1))
			Fail32=1
		else
			if [ "$($i 0x32 $Ch 0x10)"=="$Ch 01"]; then
				echo -e "${color_green} Channel 0x$Ch is enable to Receive Message${color_reset}"|tee -a App.log
			else
				if [ "$($i 0x32 $Ch 0x10)"=="$Ch 00"]; then
				echo -e "${color_red} Channel $Ch is disable to Receive Message ${color_reset}"|tee -a App.log
			fi
fi
echo -e "${color_blue} Enable Message Channel Receive command finished.${color_reset}"|tee -a App.log
echo ""|tee -a App.log

#Send & Get messages
echo -e " ${color_convert} Send & Get messages Command ${color_reset} " |tee -a  App.log
echo " Response below :" |tee -a App.log
$i 0x34 0x0f 0x01
if [ ! $? -eq '0' ] ; then
			$i 0x34 0x0f 0x01 >> App.log
			echo -e "${color_red} Send & Get messages Command failed ${color_reset}"|tee -a App.log
			FailCounter=$(($FailCounter+1))
			Fail34=1
		else
			if [ "$($i 0x33)"=="0f 01"]; then
				echo -e "${color_green} Send & Get messages success ${color_reset}"|tee -a App.log
			else
				echo -e "${color_red} Send & Get messages Command fail that response not correct ${color_reset}"|tee -a App.log
				FailCounter=$(($FailCounter+1))
				Fail34=1
			fi
fi
echo -e "${color_blue} Send & Get messages command finished.${color_reset}"|tee -a App.log
echo ""|tee -a App.log

#Read Event Message Buffer Command
echo -e " ${color_convert} Read Event Message Buffer Command ${color_reset} " |tee -a  App.log
echo " Response below :" |tee -a App.log
ipmitool event 1 
$i 0x35
if [ ! $? -eq '0' ] ; then
		$i 0x35 >> App.log
		echo -e "${color_red} Read Event Message Buffer Command failed ${color_reset}"|tee -a App.log
		FailCounter=$(($FailCounter+1))
		Fail35=1
	else
		$i 0x35 |tee -a App.log
		echo -e "${color_green} Read Event Message Buffer Command success ${color_reset}"|tee -a App.log
fi
echo -e "${color_blue} Read Event Message Buffer Command finished ${color_reset}"|tee -a App.log
echo ""|tee -a App.log

#Get Get BT Interface Capabilities
echo -e " ${color_convert} Get BT Interface Capabilities Command ${color_reset} " |tee -a  App.log
echo " Response below :" |tee -a App.log
$i 0x36
if [ ! $? -eq '0' ] ; then
		$i 0x36 >> App.log
		echo -e "${color_red} Get BT Interface Capabilities Command failed ${color_reset}"|tee -a App.log
		FailCounter=$(($FailCounter+1))
		Fail36=1
	else
		read GBI1 GBI2 GBI3 GBI4 GBI5 <<< $($i 0x36)
		for j in GBI{1..5}; do
			eval temp=\$$j
			temp=${D2B[$((16#$temp))]}
			read $j'b1' $j'b2' $j'b3' $j'b4' $j'b5' $j'b6' $j'b7' $j'b8' <<< "${temp:0:1} ${temp:1:1} ${temp:2:1} ${temp:3:1} ${temp:4:1} ${temp:5:1} ${temp:6:1} ${temp:7:1}"
		done
		echo -e "${color_green} There's $((16#$GBI1)) Number of outstanding requests supported ${color_reset}"|tee -a App.log
		echo -e "${color_green} The largest value input allowed in first byte is $((16#$GBI2)) ${color_reset}"|tee -a App.log
		echo -e "${color_green} The largest value output allowed in first byte is $((16#$GBI3))${color_reset}"|tee -a App.log
		echo -e "${color_green} BMC Request-to-Response time is $((16#$GBI4))(in seconds) ${color_reset}"|tee -a App.log
		echo -e "${color_green} Recommended retries is $((#16$GBI5))${color_reset}"|tee -a App.log
		echo -e "${color_green} Get BT Interface Capabilities Command success ${color_reset}"|tee -a App.log
fi
echo -e "${color_blue} Get Get BT Interface Capabilities Command finished ${color_reset}"|tee -a App.log
echo ""|tee -a App.log

#Get Device GUID Command
echo -e " ${color_convert} Get Device GUID Command ${color_reset} " |tee -a  App.log
echo " Response below :" |tee -a App.log
$i 0x37
if [ ! $? -eq '0' ] ; then
		$i 0x37 >> App.log
		echo -e "${color_red} Get Device GUID Command failed ${color_reset}"|tee -a App.log
		FailCounter=$(($FailCounter+1))
		Fail37=1
	else
		$i 0x37 |tee -a App.log
		echo -e "${color_green} Get Device GUID Command success ${color_reset}"|tee -a App.log
fi
echo -e "${color_blue} Get Device GUID Command finished ${color_reset}"|tee -a App.log
echo ""|tee -a App.log

#Get Channel Authentication Capabilities Command
echo -e " ${color_convert} Get Channel Authentication Capabilities Command ${color_reset} " |tee -a  App.log
echo " Response below :" |tee -a App.log
echo -e " ${color_convert} Channel Authentication Capabilities of Backward compatible with IPMI v1.5 Command ${color_reset} " |tee -a  App.log
for $j in {1..4}; do
	case $j in 
	1) Auth=Callback;;
	2) Auth=User;;
	3) Auth=Operator;;
	4) Auth=Admin;;
	esac
	$i 0x38 0x01 0x0$j
	if [ ! $? -eq '0' ] ; then
		$i 0x38 0x01 0x0$j >> App.log
		echo -e "${color_red} Get Channel Authentication Capabilities Command failed with Backward compatible with IPMI v1.5 in $Auth level${color_reset}"|tee -a App.log
		FailCounter=$(($FailCounter+1))
		Fail38=1
	else
		$i 0x38 0x01 0x0$j |tee -a App.log
		for k in GCAC{1..8}; do
			eval temp=\$$j
			temp=${D2B[$((16#$temp))]}
			read $k'b1' $k'b2' $k'b3' $k'b4' $k'b5' $k'b6' $k'b7' $k'b8' <<< "${temp:0:1} ${temp:1:1} ${temp:2:1} ${temp:3:1} ${temp:4:1} ${temp:5:1} ${temp:6:1} ${temp:7:1}"
		done
		echo -e "${color_green} Channel number $GCAC1 ${color_reset}"|tee -a App.log
		if [ $GCAC2b1 -eq '1' ]
			echo -e "${color_green} IPMI v2.0+ extended capabilities available ${color_reset}"|tee -a App.log
		fi
		if [ $GCAC2b1 -eq '0' ]
			echo -e "${color_green} IPMI v1.5 support only ${color_reset}"|tee -a App.log
		fi
		echo -e "${color_green} IPMI v1.5 Authentication type(s) enabled for given Requested Maximum Privilege Level${color_reset}"|tee -a App.log
		if [ $GCAC2b3 -eq '1' ]
			echo -e "${color_green} OEM proprietary is support ${color_reset}"|tee -a App.log
		else
			echo -e "${color_red} OEM proprietary is not support ${color_reset}"|tee -a App.log
		fi
		if [ $GCAC2b4 -eq '1' ]
			echo -e "${color_green} straight password / key is support ${color_reset}"|tee -a App.log
		else
			echo -e "${color_red} straight password / key is not support ${color_reset}"|tee -a App.log
		fi
		if [ $GCAC2b6 -eq '1' ]
			echo -e "${color_green} MD5 is support ${color_reset}"|tee -a App.log
		else
			echo -e "${color_red} MD5 is not support ${color_reset}"|tee -a App.log
		fi
		if [ $GCAC2b7 -eq '1' ]
			echo -e "${color_green} MD2 is support ${color_reset}"|tee -a App.log
		else
			echo -e "${color_red} MD2 is not support ${color_reset}"|tee -a App.log
		fi		
		if [ $GCAC3b4 -eq '1' ]
			echo -e "${color_red} Per-message Authentication is disabled ${color_reset}"|tee -a App.log
		else 
			echo -e "${color_green} Per-message Authentication is enabled ${color_reset}"|tee -a App.log
		fi
		if [ $GCAC3b5 -eq '1' ]
			echo -e "${color_red} User Level Authentication is disabled ${color_reset}"|tee -a App.log
		else 
			echo -e "${color_green} User Level Authentication is enabled ${color_reset}"|tee -a App.log
		fi
		if [ $GCAC3b6 -eq '1' ]
			echo -e "${color_red} Non-null usernames enabled ${color_reset}"|tee -a App.log
		fi
		if [ $GCAC3b7 -eq '1' ]
			echo -e "${color_green} Null usernames enabled ${color_reset}"|tee -a App.log
		fi
		if [ $GCAC3b8 -eq '1' ]
			echo -e "${color_green} Anonymous Login enabled ${color_reset}"|tee -a App.log
		fi
		
		echo -e "${color_green} Get Channel Authentication Capabilities Command success with Backward compatible with IPMI v1.5 in $Auth level${color_reset}"|tee -a App.log
	fi
	
	echo -e " ${color_convert} Channel Authentication Capabilities of IPMI v2.0+ ${color_reset} " |tee -a  App.log	$i 0x38 0x81 0x0$j
	if [ ! $? -eq '0' ] ; then
		$i 0x38 0x81 0x0$j >> App.log
		echo -e "${color_red} Get Channel Authentication Capabilities Command failed with Backward compatible with IPMI v1.5 in $Auth level${color_reset}"|tee -a App.log
		FailCounter=$(($FailCounter+1))
		Fail38=1
	else
		$i 0x38 0x81 0x0$j |tee -a App.log
		for k in GCAC{1..8}; do
			eval temp=\$$j
			temp=${D2B[$((16#$temp))]}
			read $k'b1' $k'b2' $k'b3' $k'b4' $k'b5' $k'b6' $k'b7' $k'b8' <<< "${temp:0:1} ${temp:1:1} ${temp:2:1} ${temp:3:1} ${temp:4:1} ${temp:5:1} ${temp:6:1} ${temp:7:1}"
		done
		echo -e "${color_green} Channel number $GCAC1 ${color_reset}"|tee -a App.log
		if [ $GCAC2b1 -eq '1' ]
			echo -e "${color_green} IPMI v2.0+ extended capabilities available ${color_reset}"|tee -a App.log
		fi
		if [ $GCAC2b1 -eq '0' ]
			echo -e "${color_green} IPMI v1.5 support only ${color_reset}"|tee -a App.log
		fi
		echo -e "${color_green} IPMI v1.5 Authentication type(s) enabled for given Requested Maximum Privilege Level${color_reset}"|tee -a App.log
		if [ $GCAC2b3 -eq '1' ]
			echo -e "${color_green} OEM proprietary is support ${color_reset}"|tee -a App.log
		else
			echo -e "${color_red} OEM proprietary is not support ${color_reset}"|tee -a App.log
		fi
		if [ $GCAC2b4 -eq '1' ]
			echo -e "${color_green} straight password / key is support ${color_reset}"|tee -a App.log
		else
			echo -e "${color_red} straight password / key is not support ${color_reset}"|tee -a App.log
		fi
		if [ $GCAC2b6 -eq '1' ]
			echo -e "${color_green} MD5 is support ${color_reset}"|tee -a App.log
		else
			echo -e "${color_red} MD5 is not support ${color_reset}"|tee -a App.log
		fi
		if [ $GCAC2b7 -eq '1' ]
			echo -e "${color_green} MD2 is support ${color_reset}"|tee -a App.log
		else
			echo -e "${color_red} MD2 is not support ${color_reset}"|tee -a App.log
		fi		
		if [ $GCAC3b3 -eq '1' ]
			echo -e "${color_red} KG status (two-key login status) is set to non-zero value ${color_reset}"|tee -a App.log
		else 
			echo -e "${color_green} KG status (two-key login status) is set to default (all 0’s) ${color_reset}"|tee -a App.log
		fi
		if [ $GCAC3b4 -eq '1' ]
			echo -e "${color_red} Per-message Authentication is disabled ${color_reset}"|tee -a App.log
		else 
			echo -e "${color_green} Per-message Authentication is enabled ${color_reset}"|tee -a App.log
		fi
		if [ $GCAC3b5 -eq '1' ]
			echo -e "${color_red} User Level Authentication is disabled ${color_reset}"|tee -a App.log
		else 
			echo -e "${color_green} User Level Authentication is enabled ${color_reset}"|tee -a App.log
		fi
		if [ $GCAC3b6 -eq '1' ]
			echo -e "${color_red} Non-null usernames enabled ${color_reset}"|tee -a App.log
		fi
		if [ $GCAC3b7 -eq '1' ]
			echo -e "${color_green} Null usernames enabled ${color_reset}"|tee -a App.log
		fi
		if [ $GCAC3b8 -eq '1' ]
			echo -e "${color_green} Anonymous Login enabled ${color_reset}"|tee -a App.log
		fi
		if [ $GCAC4b7 -eq '1' ]
			echo -e "${color_green} Channel supports IPMI v2.0 connections ${color_reset}"|tee -a App.log
		fi
		if [ $GCAC4b8 -eq '1' ]
			echo -e "${color_green} Channel supports IPMI v1.5 connections ${color_reset}"|tee -a App.log
		fi
		echo -e "${color_green} Get Channel Authentication Capabilities Command success with Backward compatible with IPMI v1.5 in $Auth level${color_reset}"|tee -a App.log
	fi
done

echo ""|tee -a App.log

#Get session Information
echo -e " ${color_convert} Get session Information command${color_reset} " |tee -a  App.log
echo " Response below :" |tee -a App.log
$i 0x3d 0x00
if [ ! $? -eq '0' ] ; then
		$i 0x3d 0x00 >> App.log
		echo -e "${color_red} Get session Information failed ${color_reset}"|tee -a App.log
		FailCounter=$(($FailCounter+1))
		Fail3d=1
	else
		read GSI1 GSI2 GSI3 GSI4 GSI5 GSI6 <<< $($i 0x3d 0x00)
		for j in GSI{1..6}; do
			eval temp=\$$j
			temp=${D2B[$((16#$temp))]}
			read $j'b1' $j'b2' $j'b3' $j'b4' $j'b5' $j'b6' $j'b7' $j'b8' <<< "${temp:0:1} ${temp:1:1} ${temp:2:1} ${temp:3:1} ${temp:4:1} ${temp:5:1} ${temp:6:1} ${temp:7:1}"
		done
		if [ "$GSI1"=="00" ]
			echo -e " There's ${color_green}no session handle assigned to active session${color_reset} presently. "|tee -a App.log
			echo -e " There's ${color_green}$((16#$GSI2)) possible active sessions${color_reset} in SUT. "|tee -a App.log
			echo -e " There's ${color_green}no active session${color_reset} currently. "|tee -a App.log
		else 		
			echo -e " There's ${color_green}$((16#$GSI1)) session handle ${color_reset}to active session presently. "|tee -a App.log
			echo -e " There's ${color_green}$((16#$GSI2)) possible active sessions${color_reset} in SUT. "|tee -a App.log
			echo -e " There's ${color_green}$((16#$GSI3)) active sessions ${color_reset}in SUT currently. "|tee -a App.log
			echo -e " The UserID for this session is ${color_green}$((16#$GSI4)). ${color_reset}"|tee -a App.log
			echo -e " Operating Privilege Level is ${color_green}0x$GSI5. ${color_reset}"|tee -a App.log
			if [ $GSI6b4 -eq '1' ]
				echo -e " The session is ${color_green}IPMI v2.0/RMCP+ protocol. ${color_reset}"|tee -a App.log
				echo -e " The session is established via channel ${color_green}$((16#$GSI6b5$GSI6b6$GSI6b7$GSI6b8)). ${color_reset}"|tee -a App.log
			fi
		fi
fi
echo -e "${color_blue} Get session Information command finished ${color_reset}"|tee -a App.log
echo ""|tee -a App.log

#Get Channel Info Command
echo -e " ${color_convert} Get Channel Info Command command${color_reset} " |tee -a  App.log
echo " Response below :" |tee -a App.log
$i 0x42 0x$Ch
if [ ! $? -eq '0' ] ; then
		$i 0x42 0x$Ch >> App.log
		echo -e "${color_red} Get Channel Info Command failed ${color_reset}"|tee -a App.log
		FailCounter=$(($FailCounter+1))
		Fail42=1
	else
		read GCI1 GCI2 GCI3 GCI4 GCI5 GCI6 GCI7 GCI8 GCI9 <<< $($i 0x42 0x$Ch)
		for j in GCI{1..9}; do
			eval temp=\$$j
			temp=${D2B[$((16#$temp))]}
			read $j'b1' $j'b2' $j'b3' $j'b4' $j'b5' $j'b6' $j'b7' $j'b8' <<< "${temp:0:1} ${temp:1:1} ${temp:2:1} ${temp:3:1} ${temp:4:1} ${temp:5:1} ${temp:6:1} ${temp:7:1}"
		done
		echo -e " Actual channel number is ${color_green}0x$GCI1. ${color_reset}"|tee -a App.log
		case $k in $GCI2
			'01')CT="IPMB (I2C)";;
			'02')CT="ICMB v1.0";;
			'03')CT="ICMB v0.9";;
			'04')CT="802.3 LAN";;
			'05')CT="Asynch. Serial/Modem (RS-232)";;
			'06')CT="Other LAN";;
			'07')CT="PCI SMBus";;
			'08')CT="SMBus v1.0/1.1";;
			'09')CT="SMBus v2.0";;
			'0a')CT="reserved for USB 1.x";;
			'0b')CT="reserved for USB 2.x";;
			'0c')CT="System Interface (KCS, SMIC, or BT)";;
		esac
		echo -e " $Ch Channel Type is ${color_green}$CT. ${color_reset}"|tee -a App.log
		case $k in $GCI3b4$GCI3b5$GCI3b6$GCI3b7$GCI3b8
			'00001')CT="IPMB-1.0, Used for IPMB, serial/modem Basic Mode, and LAN";;
			'00010')CT="ICMB v1.0";;
			'00011')CT="Reserve";;
			'00100')CT="IPMI-SMBus, IPMI on PCI-SMBus / SMBus 1.x - 2.x";;
			'00101')CT="KCS, KCS System Interface Format";;
			'00110')CT="SMIC, SMIC System Interface Format";;
			'00111')CT="BT-10, BT System Interface Format";;
			'01000')CT="BT-15, BT System Interface Format";;
			'01001')CT="TMode, Terminal Mode";;
		esac
		echo -e " $Ch Channel protocol Type is${color_green} $CT. ${color_reset}"|tee -a App.log
		
		case $k in $GCI4b1$GCIb2
			'00')echo -e " Channel $Ch is ${color_green}session-less. ${color_reset}"|tee -a App.log;;
			'01')echo -e " Channel $Ch is ${color_green}single-session. ${color_reset}"|tee -a App.log;;
			'10')echo -e " Channel $Ch is ${color_green}multi-session. ${color_reset}"|tee -a App.log;;
			'11')echo -e " Channel $Ch is ${color_green}session-based. ${color_reset}"|tee -a App.log;;
		esac
			
		echo -e " There's ${color_green}$((2#$GSI4b3$GSI4b4$GSI4b5$GSI4b6$GSI4b7$GSI4b8)) ${color_reset}of sessions that have been activated on channel $Ch."|tee -a App.log
		echo -e " The Vendor ID (IANA Enterprise Number) for OEM/Organization that specified the Channel Protocol is ${color_green} $((16#$GCI7$GCI6$GCI5)). ${color_reset}"|tee -a App.log
		echo -e " There's ${color_green}$((16#$GSI3)) ${color_reset}active sessions in SUT currently. "|tee -a App.log
		echo -e " The UserID for this session is ${color_green}$((16#$GSI4)). ${color_reset}"|tee -a App.log
		echo -e " Operating Privilege Level is ${color_green}0x$GSI5. ${color_reset}"|tee -a App.log
		if [ $GSI6b4 -eq '1' ]
			echo -e " The session is ${color_green}IPMI v2.0/RMCP+ protocol. ${color_reset}"|tee -a App.log
			echo -e " The session is established via channel ${color_green}$((16#$GSI6b5$GSI6b6$GSI6b7$GSI6b8)). ${color_reset}"|tee -a App.log
		fi
fi
echo -e "${color_blue} Get Channel Info Command finished ${color_reset}"|tee -a App.log
echo ""|tee -a App.log

#Set user name 
echo -e " ${color_convert} Set user name Command${color_reset} " |tee -a  App.log
echo " Response below :" |tee -a App.log
#Set a new user names "sit"
$i 0x45 0x03 0x73 0x69 0x74 0 0 0 0 0 0 0 0 0 0 0 0 0
if [ ! $? -eq '0' ] ; then
	$i 0x45 0x03 0x73 0x69 0x74 0 0 0 0 0 0 0 0 0 0 0 0 0 >> App.log
	echo -e "${color_red} Set user name command failed ${color_reset}"|tee -a App.log
	FailCounter=$(($FailCounter+1))
	Fail45=1
else
	if [ -n "$($i user list $Ch|grep sit)" ];then
		echo -e "${color_blue} Set user name Command finished ${color_reset}"|tee -a App.log
	else
		echo -e "${color_red} Set user name command failed ${color_reset}"|tee -a App.log
		FailCounter=$(($FailCounter+1))
		Fail45=1
	fi
fi

#Get user name 
echo -e " ${color_convert} Set user name Command${color_reset} " |tee -a  App.log
echo " Response below :" |tee -a App.log

$i 0x46 0x03
if [ ! $? -eq '0' ] ; then
	$i 0x46 0x03 >> App.log
	echo -e "${color_red} Get user name command failed ${color_reset}"|tee -a App.log
	FailCounter=$(($FailCounter+1))
	Fail46=1
else
	if [ "$($i 0x46)"=="73 69 74 00 00 00 00 00 00 00 00 00 00 00 00 00" ];then
		echo -e "${color_blue} Get user name Command finished ${color_reset}"|tee -a App.log
	else
		echo -e "${color_red} Get user name command failed ${color_reset}"|tee -a App.log
		FailCounter=$(($FailCounter+1))
		Fail46=1
	fi
fi

echo -e " ${color_convert} Set user password Command${color_reset} " |tee -a  App.log
echo " Response below :" |tee -a App.log

$i 0x47 0x83 0x02 0x21 0x71 0x61 0x7a 0x32 0x77 0x73 0x58 0 0 0 0 0 0 0 0 0 0 0 0
if [ ! $? -eq '0' ] ; then
	$i 0x47 0x83 0x02 0x21 0x71 0x61 0x7a 0x32 0x77 0x73 0x58 0 0 0 0 0 0 0 0 0 0 0 0 >> App.log
	echo -e "${color_red} Set user password command failed ${color_reset}"|tee -a App.log
	FailCounter=$(($FailCounter+1))
	Fail47=1
else
	$i 0x47 0x83 0x03 0x21 0x71 0x61 0x7a 0x32 0x77 0x73 0x58 0 0 0 0 0 0 0 0 0 0 0 0
	if [ ! $? =eq 0 ];then
		echo -e "${color_blue} Set user password Command finished ${color_reset}"|tee -a App.log
	else
		echo -e "${color_red} Set user password command failed ${color_reset}"|tee -a App.log
		FailCounter=$(($FailCounter+1))
		Fail47=1
	fi
fi

