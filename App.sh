#!/bin/bash

echo -e "${color_red}Remove and backup the previous log as date format...${color_reset}"
if [ -f "App.log" ]; then
	cp App.log $(date +%Y%m%d_%T)_App.log && rm -f App.log
fi
clear
date|tee -a App.log
read OSInfo <<< $(cat /etc/os-release|grep -i pretty|cut -d = -f 2)
echo "$USER start testing in $OSInfo..."|tee -a chassis.log
i="ipmitool raw 0x06"
sleep 1
color_reset='\e[0m'
color_green='\e[32m'
color_red='\e[31m'
color_convert='\e[7m'
date |tee -a App.log
FailCounter=0
#printf '\x5F' | xxd -b | cut -d' ' -f2 
#$((#16$hex))
##Convert Hex to Binary
D2B=({0..1}{0..1}{0..1}{0..1}{0..1}{0..1}{0..1}{0..1})
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
# raw 0x06 0x01
echo ""|tee -a App.log
echo " Get Device ID " |tee -a  App.log
echo " Response below :" |tee -a App.log
$i 0x01
if [ ! $? -eq '0' ] ; then
	$i 0x01 >> App.log
	echo -e "${color_red} Get Device ID failed ${color_reset}"|tee -a App.log
	FailCounter=$(($FailCounter+1))
else
	$i 0x01 >> App.log
	echo =====================Device ID info======================== |tee -a app.log
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
echo " BMC Cold Rest " |tee -a  App.log
echo " Response below :" |tee -a App.log
$i 0x02
if [ ! $? -eq '0' ] ; then
	echo -e "${color_red} BMC Cold Reset failed ${color_reset}"|tee -a App.log
	FailCounter=$(($FailCounter+1))
else
	echo " BMC Cold Restting... Wait for BMC initializing..."
	sleep 90
	CRC=0
	while [ ! $($i 0x01) ] && [ $CRC -le 35 ]
	do
		sleep 5
		let CRC=$CRC+1
	done
	echo "${color_blue} BMC Cold Rest finished.${color_reset}"|tee -a App.log
fi
echo ""|tee -a App.log
# raw 0x06 0x03
echo " BMC Warm Rest " |tee -a  App.log
echo " Response below :" |tee -a App.log
$i 0x03
if [ ! $? -eq '0' ] ; then
	echo -e "${color_red} BMC Warm Reset failed ${color_reset}"|tee -a App.log
	FailCounter=$(($FailCounter+1))
else
	echo " BMC Warm Restting... Wait for BMC initializing..."
	sleep 90
	WRC=0
	while [ ! $($i 0x01) ] && [ $WRC -le 35 ]
	do
		sleep 5
		let WRC=$WRC+1
	done
		echo -e " ${color_blue}BMC Warm Rest finished${color_reset}."|tee -a App.log
fi
echo ""
# raw 0x06 0x04
echo " BMC Self Test " |tee -a  App.log
echo " Response below :" |tee -a App.log
$i 0x04
if [ ! $? -eq '0' ] ; then
	$i 0x04 >> App.log
	echo -e "${color_red} BMC Self Test failed ${color_reset}"|tee -a App.log
	FailCounter=$(($FailCounter+1))
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
	'58') echo -e " ${color_red}Fatal hardware error (system should consider BMC inoperative). This will indicate that the controller hardware (including associated devices such as sensor hardware or RAM) may need to be repaired or replaced${color_reset}."|tee -a App.log;;
	.) echo -e " ${color_green}Device-specific ‘internal’ failure. Refer to the particular device’s specification for definition${color_reset}."|tee -a App.log;;
	esac
	
fi


