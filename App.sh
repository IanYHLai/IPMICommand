#!/bin/bash

echo Start App function raw command...
i="ipmitool raw 0x06"
sleep 1
color_reset='\e[0m'
color_green='\e[32m'
color_red='\e[31m'
color_convert='\e[7m'
echo -e "$color_redRemove and backup the previous log as date format...${color_reset}"
if [ -f "App.log" ]; then
	cp App.log $(date +%Y%m%d_%T)_App.log && rm -f App.log
fi
date |tee -a App.log
FailCounter=0
#printf '\x5F' | xxd -b | cut -d' ' -f2 
#$((#16$hex))
##Convert Hex to Binary
D2B=({0..1}{0..1}{0..1}{0..1}{0..1}{0..1}{0..1}{0..1})
function CHB () {                                                                              
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
echo ""
echo ""
echo "------------------------------------------------------------------------------------------------"
echo Get Device ID >> App.log
echo "Response below :" >> App.log
$i 0x01
if [ ! $? -eq '0' ] ; then
	echo -e "${color_red}Get Device ID failed ${color_reset}"
	$i 0x01 >> App.log
	echo -e "${color_red}Get Device ID $i 0x01 fail${color_reset} " >> App.log
	FailCounter=$(($FailCounter+1))
	
else
	echo =====================Device ID info======================== |tee -a app.log
	$i 0x01 >> App.log
	echo '' |tee -a App.log
	read DI1 DI2 DI3 DI4 DI5 DI6 DI7 DI8 DI9 DI10 DI11 DI12 DI13 DI14 DI15 <<< $($i 0x01)
	echo -e "${color_green}The SUT device ID is $DI1 (hex)${color_reset}" |tee -a App.log
	echo "" |tee -a App.log
	for j in DI{2..15}; do
		eval temp=\$$j
		temp=${D2B[$((16#$temp))]}
		read $j'b1' $j'b2' $j'b3' $j'b4' $j'b5' $j'b6' $j'b7' $j'b8' <<< "${temp:0:1} ${temp:1:1} ${temp:2:1} ${temp:3:1} ${temp:4:1} ${temp:5:1} ${temp:6:1} ${temp:7:1}"
	done
	
	DR=$((2#$DI2b5$DI2b6$DI2b7$DI2b8))
	echo '' |tee -a App.log
	# DI5 IPMI version 
	echo -e "${color_green}*IPMI Version*${color_reset}" |tee -a App.log
	if [ $DI5 -eq "51" ];then
		echo "This SUT's IPMI version is 1.5." |tee -a App.log
	elif [ $DI5 -eq "02" ];then
		echo "This SUT's IPMI version is 2.0." |tee -a App.log
	fi
	echo ''
	#DI2 Device Revision
	echo -e "${color_green}*Device Revision*${color_reset}" |tee -a App.log
	echo "This device revision is $DR." |tee -a App.log
	if [ $DI2b1 -eq "1" ];then
		echo "This device provides Device SDRs." |tee -a App.log
	else
		echo "This device doesn't provide Device SDRs." |tee -a App.log
	fi
	echo '' |tee -a App.log
	#DI3 DI4 Firmware revision
	echo -e "${color_green}*Firmware Revision*${color_reset}" |tee -a App.log
	if [ $DI3b1 -eq "1" ];then
		echo "Device firmware, SDR Repository update or self-initialization in progress." |tee -a App.log
	else
		echo "Normal operation." |tee -a App.log
	fi
	FR=$((2#$DI3b2$DI3b3$DI3b4$DI3b5$DI3b6$DI3b7$DI3b8))
	echo "BMC firmware version : $FR $DI4" |tee -a App.log
	echo '' |tee -a App.log
	#DI6 IPMI command and function support list
	echo -e "${color_green}*Additional Device Support*${color_reset}" |tee -a App.log
	echo "This Device support the command and function below :" |tee -a App.log
	if [ $DI6b1 -eq "1" ] ;then 
		echo "Chassis Device (device functions as chassis device per ICMB spec.)" |tee -a App.log
	fi
	if [ $DI6b2 -eq "1" ];then 
		echo "Bridge (device responds to Bridge NetFn commands)" |tee -a App.log
	fi
	if [ $DI6b3 -eq "1" ];then 
		echo "IPMB Event Generator (device generates event messages [platform event request messages] onto the IPMB)" |tee -a App.log
	fi
	if [ $DI6b4 -eq "1" ];then 
		echo "IPMB Event Receiver (device accepts event messages [platform event request messages] from the IPMB)" |tee -a App.log
	fi
	if [ $DI6b5 -eq "1" ];then 
		echo "FRU Inventory Device" |tee -a App.log
	fi
	if [ $DI6b6 -eq "1" ];then 
		echo "SEL Device" |tee -a App.log
	fi
	if [ $DI6b7 -eq "1" ];then 
		echo "SDR Repository Device" |tee -a App.log
	fi
	if [ $DI6b8 -eq "1" ];then 
		echo "Sensor Device" |tee -a App.log
	fi
	echo '' |tee -a App.log
	#DI7 DI8 DI9 Manufacturer ID 
	echo -e "${color_green}*Manufacturer ID*${color_reset}" |tee -a App.log
	MI=$((16#$DI9$DI8$DI7))
	echo "Manufacturer ID is : $MI | Please goto https://www.iana.org/assignments/enterprise-numbers/enterprise-numbers to chekc with the Enterprise number" |tee -a App.log
	echo '' |tee -a App.log
	#DI10 DI11 Product ID
	echo -e "${color_green}*Product ID*${color_reset}" |tee -a App.log
	echo "Product ID is $DI11 $DI10" |tee -a App.log
	echo ''
	#DI12 DI13 DI14 DI15 Auxiliary Firmware Revision Information
	echo -e "${color_green}*Auxiliary Firmware Revision Information*${color_reset}" |tee -a App.log
	echo "Auxiliary Firmware Revision Information is defined by Manufacturer ID : $DI12 $DI13 $DI14 $DI15" |tee -a App.log
	echo '' |tee -a App.log
	echo "Get Device ID finished" |tee -a App.log
fi
