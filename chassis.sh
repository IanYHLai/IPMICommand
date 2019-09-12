#!/bin/bash

echo -e "$color_redRemove and backup the previous log as date format...${color_reset}"
if [ -f "chassis.log" ]; then
	cp chassis.log $(date +%Y%m%d)_chassis.log && rm -f chassis.log
fi
date |tee -a chassis.log
echo "Start chassis raw command..."|tee -a chassis.log
echo ''
i="ipmitool raw 0x00"
sleep 1
color_reset='\e[0m'
color_green='\e[32m'
color_red='\e[31m'
color_convert='\e[7m'
FailCounter=0
D2B=({0..1}{0..1}{0..1}{0..1}{0..1}{0..1}{0..1}{0..1})
FailCounter=0
### raw 0x00 0x00
echo ""
echo "------------------------------------------------------------------------------------------------"|tee -a chassis.log
## Get chassis capabilities
echo -e "${color_convert}Get Chassis Capabilities${color_reset}" |tee -a chassis.log
echo "Response below :" |tee -a chassis.log
$i 0x00
if [ $? -eq '1' ] ; then
	echo -e "${color_red}Get Chassis Capabilities failed${color_reset}" |tee -a chassis.log
	$i 0x00 >> chassis.log
	FailCounter=$(($FailCounter+1))
else
	$i 0x00 >> chassis.log
	read CC1 CC2 CC3 CC4 CC5 CC6 <<< $($i 0x00)
	for j in CC{1..6}; do
		eval temp=\$$j
		temp=${D2B[$((16#$temp))]}
		read $j'b1' $j'b2' $j'b3' $j'b4' $j'b5' $j'b6' $j'b7' $j'b8' <<< "${temp:0:1} ${temp:1:1} ${temp:2:1} ${temp:3:1} ${temp:4:1} ${temp:5:1} ${temp:6:1} ${temp:7:1}"
	done
	#Capabilities Flags
	echo -e "${color_green}*Capabilities Flags*${color_reset}" |tee -a chassis.log
	echo "This SUT provides capabilities below :"
	if [ $CC1b5 -eq '1' ];then
		echo "Power interlock (IPMI1.5)."|tee -a chassis.log
	fi
	if [ $CC1b6 -eq '1' ];then
		echo "Diagnostic Interrupt (FP NMI)(IPMI1.5)."|tee -a chassis.log
	fi
	if [ $CC1b7 -eq '1' ];then
		echo "Front Panel Lockout."|tee -a chassis.log
	fi
	if [ $CC1b8 -eq '1' ];then
		echo "Chassis intrusion sensor(physical security)."|tee -a chassis.log
	fi
	echo ''|tee -a chassis.log
	echo " Get Chassis Capabilities finished." |tee -a chassis.log
	echo ''|tee -a chassis.log
	#Chassis FRU info Device Address
	echo -e "${color_green}*Chassis FRU info Device address*${color_reset}" |tee -a chassis.log
	echo "All IPMB address used in this command are have the 7-bit I2C slave address as the most-significant 7-bits and the least significant bit set to 0b."|tee -a chassis.log
	echo ""|tee -a chassis.log
	echo "The FRU info Device address is $CC2." |tee -a chassis.log
	#Chassis SDR device Address
	echo -e "${color_green}*Chassis SDR Device address*${color_reset}" |tee -a chassis.log
	echo ""|tee -a chassis.log
	echo "The SDR Device address is $CC3." |tee -a chassis.log
	#Chassis SEL device Address
	echo -e "${color_green}*Chassis SEL Device address*${color_reset}" |tee -a chassis.log
	echo ""|tee -a chassis.log
	echo "The SEL Device address is $CC4." |tee -a chassis.log
	#Chassis System Management Device device Address
	echo -e "${color_green}*Chassis System Management Device address*${color_reset}" |tee -a chassis.log
	echo ""|tee -a chassis.log
	echo "The SDR Device address is $CC5." |tee -a chassis.log
	#Chassis Bridge Device Address
	echo -e "${color_green}*Chassis Bridge Device address*${color_reset}" |tee -a chassis.log
	echo ""|tee -a chassis.log
	if [ -z $CC6 ];then
		echo "This SUT doesn't provide this address, but the adderes is assumed to be the BMC adderess 20h generally."|tee -a chassis.log
	else
		echo "The Bridge Device adderess is $CC6."|tee -a chassis.log
	fi
	
	echo "The SDR Device address is $CC5." |tee -a chassis.log
	echo ""|tee -a chassis.log
	echo -e "${color_green}*The Get Chassis Capabiliteis command finished${color_reset}*"|tee -a chassis.log
fi

### raw 0x00 0x01
echo ""|tee -a chassis.log
###Get chassis status
echo -e "${color_convert}*Get Chassis Status*${color_reset}" |tee -a chassis.log
echo "Response below :" |tee -a chassis.log
$i 0x01
if [ $? -eq '1' ] ; then
	echo -e "${color_red}Get Chassis Status failed${color_reset}"|tee -a chassis.log
	$i 0x01 >>chassis.log
	FailCounter=$(($FailCounter+1))
else
	$i 0x01 >>chassis.log
	read CS1 CS2 CS3 CS4 <<< $($i 0x01)
	for j in CS{1..4}; do
		eval temp=\$$j
		temp=${D2B[$((16#$temp))]}
		read $j'b1' $j'b2' $j'b3' $j'b4' $j'b5' $j'b6' $j'b7' $j'b8' <<< "${temp:0:1} ${temp:1:1} ${temp:2:1} ${temp:3:1} ${temp:4:1} ${temp:5:1} ${temp:6:1} ${temp:7:1}"
	done
	#Current Power State
	echo -e "${color_green}*Current Power State*${color_reset}"|tee -a chassis.log
	case "$CS1b2$CS1b3" in 
		"00")echo "Power Policy is Always off after AC/mains."|tee -a chassis.log;;
		"01")echo "Power Policy is Previous status after AC/mains."|tee -a chassis.log;;
		"02")echo "Power Policy is Always on after AC/mains."|tee -a chassis.log;;
		"11")echo "Power Policy is Unknown."|tee -a chassis.log;;
	esac
	#Power Control Fault
	echo -e "${color_green}*Current Power Control Fault*${color_reset}"|tee -a chassis.log
	if [ "$CS1b4" -eq '1' ];then
		echo "Controller attempted to turn system power on or off, but system did not enter desired state."|tee -a chassis.log
	else
		echo "No Power Control Fault." |tee -a chassis.log
	fi
	#Power Fault
	echo -e "${color_green}*Current Power Fault*${color_reset}"|tee -a chassis.log
	if [ "$CS1b5" -eq '1' ];then
		echo "Fault detected in main power subsystem." |tee -a chassis.log
	else 
		echo "No Power Fault."|tee -a chassis.log
	fi
	#Interlock
	echo -e "${color_green}*Current Interlock*${color_reset}"|tee -a chassis.log
	if [ "$CS1b6" -eq '1' ];then
		echo "Power Interlock (chassis is presently shut down because a chassis panel interlock switch is active). (IPMI 1.5)"|tee -a chassis.log
	else
		echo "No Power Interlock."|tee -a chassis.log
	fi
	#Power overload
	echo -e "${color_green}*Current Power Overload*${color_reset}"|tee -a chassis.log
	if [ "$CS1b7" -eq '1' ];then
		echo "system shutdown because of power overload condition."|tee -a chassis.log
	else
		echo "No Power Overload."|tee -a chassis.log
	fi
	#Power status
	echo -e "${color_green}*Current Power Status*${color_reset}"|tee -a chassis.log
	if [ "$CS1b8" -eq '1' ];then
		echo "System Power is on."|tee -a chassis.log
	else
		echo "System Power is off."|tee -a chassis.log
	fi
	echo ''
	if [ "$CS1b4$CS1b5$CS1b6$CS1b7" -eq '0000' ];then
		echo "Power state is normall."|tee -a chassis.log
	else
		echo "There's error in Power state, Check the log please."|tee -a chassis.log
	fi
	echo ''
	#Last power event
	echo -e "${color_green}*Last Power Event*${color_reset}"|tee -a chassis.log
	if [ "CS2b4" -eq '1' ] ;then
		echo "The last ‘Power is on’ state was entered via IPMI command"|tee -a chassis.log
	fi
	case "$CS2b3$CS2b2$CS2b1$CS2b0" in
		0000) echo "No Last Power Event"|tee -a chassis.log;;
		0001) echo "The Last Power down caused by AC Faild"|tee -a chassis.log;;
		0010) echo "The Last Power down caused by a Power overload"|tee -a chassis.log ;;
		0100) echo "The Last Power down caused by a Power interlock being activated"|tee -a chassis.log ;;
		1000) echo "The Last Power down caused by a Power fault"|tee -a chassis.log;;
	esac
	echo ''|tee -a chassis.log
	#Misc. Chassis State
	echo -e "${color_green}*Misc. Chassis State*${color_reset}"|tee -a chassis.log
	if [ "$CS3b2" -eq '1' ];then 
		echo "Chassis Identify command and state info supported. (Optional)"|tee -a chassis.log
	else
		echo "Chassis Identify command support unspecified via this command. (The Get Command Support command, if implemented, would still indicate support for the Chassis Identify command)"|tee -a chassis.log
	fi
	case "$CS3b3$CS3b4" in 
		00) echo "Chassis identify state = Off"|tee -a chassis.log;;
		01) echo "Chassis identify state = Temporary On"|tee -a chassis.log;;
		10) echo "Chassis identify state = Indefinite On"|tee -a chassis.log;;
		11) echo "Reserve"|tee -a chassis.log;;
	esac
	if [ "CS3b5" -eq '1' ];then
		echo "Cooling/fan fault detected."|tee -a chassis.log
	else 
		echo "Cooling/fan works good."|tee -a chassis.log
	fi
	echo ''|tee -a chassis.log
	if [ "CS3b6" -eq '1' ];then
		echo "Drive Fault detected."|tee -a chassis.log
	else 
		echo "All Drives works good."|tee -a chassis.log
	fi
	echo ''|tee -a chassis.log
	if [ "CS3b7" -eq '1' ];then
		echo "Front Panel Lockout active (power off and reset via chassis push-buttons disabled.)"|tee -a chassis.log
	else 
		echo "Front Panel Lockout deactive (power off and reset via chassis push-buttons ensabled.)"|tee -a chassis.log
	fi
	echo '' |tee -a chassis.log
		if [ "CS3b8" -eq '1' ];then
		echo "Chassis intrusion active."|tee -a chassis.log
	else 
		echo "Chassis intrusion deactive"|tee -a chassis.log
	fi
	echo ''|tee -a chassis.log
	#Front Panel Button Capabilities and disable/enable status (Optional)(“Button” actually refers to the ability for the local user to be able to perform the specified functions via a pushbutton, switch, or other ‘front panel’ control built into the system chassis.)
	if [ -z "$CS4b1" ];then
		echo "The SUT doesn't support getting 'Front Panel Button Capabilities and disable/enable status'"
	fi
	
	if [ "CS4b1" -eq '1' ];then
		echo "Standby (sleep) button disable allowed."|tee -a chassis.log
	else
		echo "Standby (sleep) button disable not allowed."|tee -a chassis.log
	fi
	if [ "CS4b2" -eq '1' ];then
		echo "Diagnostic Interrupt button disable allowed."|tee -a chassis.log
	else
		echo "Diagnostic Interrupt button disable not allowed."|tee -a chassis.log
	fi
	if [ "CS4b3" -eq '1' ];then
		echo "Reset button disable allowed."|tee -a chassis.log
	else
		echo "Reset button disable not allowed."|tee -a chassis.log
	fi
	if [ "CS4b4" -eq '1' ];then
		echo "Power off button disable allowed (in the case there is a single combined power/standby (sleep) button, disabling power off also disables sleep requests via that button.)."|tee -a chassis.log
	else
		echo "Power off button disable not allowed (in the case there is a single combined power/standby (sleep) button, disabling power off also disables sleep requests via that button.)."|tee -a chassis.log
	fi
	if [ "CS4b5" -eq '1' ];then
		echo "Standby (sleep) button disabled."|tee -a chassis.log
	else
		echo "Standby (sleep) button enabled."|tee -a chassis.log
	fi
	if [ "CS4b6" -eq '1' ];then
		echo "Diagnostic Interrupt button disabled."|tee -a chassis.log
	else
		echo "Diagnostic Interrupt button enabled."|tee -a chassis.log
	fi
	if [ "CS4b7" -eq '1' ];then
		echo "Reset button disabled."|tee -a chassis.log
	else
		echo "Reset button enabled."|tee -a chassis.log
	fi
	if [ "CS4b8" -eq '1' ];then
		echo "Power off button disabled (in the case there is a single combined power/standby (sleep) button, then this indicates that sleep requests via that button are also disabled.)."|tee -a chassis.log
	else
		echo "Power off button enabled (in the case there is a single combined power/standby (sleep) button, then this indicates that sleep requests via that button are also disabled.)."|tee -a chassis.log
	fi
	echo ''|tee -a chassis.log	
	echo -e "${color_green}*Get Chassis Status finished${color_reset}" |tee -a chassis.log
fi

# raw 0x00 0x02 Set Power control (Power off, Power on, Power cycle, Diagnostic interrupt, Power soft)
#echo ""
#echo ""
#echo "------------------------------------------------------------------------------------------------"
#echo Chassis Control >> chassis.log
#for j in {0..5}; do
#	$i 0x02 0x0$j
#if [ ! $?==0 ] ; then
#		echo Chassis Control failed in bit $j
#		$i 0x02 0x0$j >> chassis.log
#		echo " Chassis Control $i 0x02 0x0$j fail " >> chassis.log
#		sleep 300
#	else
#		echo Get Chassis Capabilities success
#		$i 0x00 >> chassis.log
#		echo " Chassis Control $i 0x02 0x0$j success " >> chassis.log
#		sleep 300
#	fi
#done

#raw 0x00 0x03 Set for ICMB chassis reset (System Hard reset)
#echo ""
#echo ""
#echo "------------------------------------------------------------------------------------------------"
#echo Chassis Rest >> chassis.log
#echo "Response below :" >> chassis.log
#$i 0x03
#if [ ! $?==0 ] ; then
#	echo Chassis Rest failed 
#	$i 0x03 >> chassis.log
#	echo " Chassis Rest $i 0x03 fail " >> chassis.log
#	$FailCounter=$(($FailCounter+1))
#	Fail3=1
#else
#	echo Chassis Rest success
#	$i 0x01 >> chassis.log
#	echo " Chassis Rest $i 0x03 success " >> chassis.log
#fi

# raw 0x00 0x04
echo ""
echo -e "${color_convert}*Chassis Identify command*${color_reset}" |tee -a chassis.log
echo -e "$color_redCheck the Identify LED......$color_reset"
echo "Response below :" |tee -a chassis.log
# Set Force identify LED on you can enter raw 0x00 0x04 0x00 for turn off the LED.
$i 0x04 0x00 0x01
if [ $? -eq '1' ] ; then
	echo -e "${color_red}Chassis Identify command failed${color_reset}"|tee -a chassis.log
	FailCounter=$(($FailCounter+1))
	$i 0x0a 0x04 0x00 0x01 |tee -a chassis.log
	Fail4=1
else
	echo "Check the identify LED solid on of not..."|tee -a chassis.log
	echo -e "${color_green}Chassis Identify finished${color_reset}" |tee -a chassis.log
fi

# raw 0x00 0x0a
echo ""
echo -e "${color_convert}*Set Front Panel Enables*${color_reset}" |tee -a chassis.log
echo "Check all front panel button including power button reset button and diagnostic interrupt button(if support) should can't perform action......"|tee -a chassis.log
echo "Response below :" >> chassis.log
# Set all button disable
$i 0x0a 0x0f 
if [ $? -eq '1' ] ; then
	echo -e "${color_red}Set Front Panel Enables failed${color_reset}"|tee -a chassis.log
	$i 0x0a 0x0f |tee -a chassis.log
	FailCounter=$(($FailCounter+1))
	Faila=1
else
	echo "${color_green}Set all Front Panel Button disabled finished${color_reset} " | tee -a chassis.log
fi

# raw 0x00 0x05
echo ""
echo -e "${color_convert}*Set Chassis Capabilities Command*${color_reset}" |tee -a chassis.log
	R=$(ipmitool raw 0x00 0x00)
	R1=$(echo $R|awk '{print$1}')
	R2=$(echo $R|awk '{print$2}')
	R3=$(echo $R|awk '{print$3}')
	R4=$(echo $R|awk '{print$4}')
	R5=$(echo $R|awk '{print$5}')
	R6=$(echo $R|awk '{print$6}')
echo "Response below :" |tee -a chassis.log
$i 0x05 0x05 0x20 0x20 0x20 0x20 0x28 # Set some FRU SDR SEL SM Bridge address you may need to restore the setting.
if [ $? -eq '1' ] ; then
	echo -e "${color_red}Set Chassis Capabilities Command failed ${color_reset}"
	$i 0x05 0x05 0x20 0x20 0x20 0x20 0x28 |tee -a chassis.log
	echo -e "${color_red}Set Chassis Capabilities Command $i 0x05 fail ${color_reset}" >> chassis.log
else
	echo -e "${color_green}Set Chassis Capabilities Command finished${color_reset}"|tee -a chassis.log
	$i 0x05 0x05 0x20 0x20 0x20 0x20 0x28 >> chassis.log
	echo "Restore setting..."
	
	$i 0x05 0x$R1 0x$R2 0x$R3 0x$R4 0x$R5 0x$R6 #Restore the cabilities
	echo "Restore finished."
fi

# raw 0x00 0x06
echo ""
echo -e "${color_convert}*Set Power Restore Policy Command*${color_reset}"|tee -a chassis.log
echo "Response below :" |tee -a chassis.log
$i 0x06 0x00 # Set Power policy always off after AC on.
if [ $? -eq '1' ] ; then
	echo -e "${color_red}Set Power Restore Policy Command failed ${color_reset}"|tee -a chassis.log
	$i 0x06 0x00 |tee -a chassis.log
	FailCounter=$(($FailCounter+1))
	Fail6=1
else
	if [ $(ipmitool raw 0x00 0x01|awk '{print$1}') -eq '01' ]; then
		echo -e "${color_green}Set Power Restore Policy Command finished${color_reset}"|tee -a chassis.log
		$i 0x06 0x00 |tee -a chassis.log
	else
		echo -e "${color_red}Set Power Restore Policy Command failed ${color_reset}"|tee -a chassis.log
		$i 0x06 0x00 |tee -a chassis.log
		$FailCounter=$(($FailCounter+1))
		Fail6=1
	fi
fi

# raw 0x00 0x0b
echo ""
echo -e "${color_convert}Set Power cycle interval Command${color_reset}"|tee -a chassis.log
echo "Response below :" |tee -a chassis.log
$i 0x0b 0x0a # Set Power cycle interval as 10sec.
if [ $? -eq '1' ] ; then
	echo -e "${color_red}Set Power cycle interval Command failed ${color_reset}"|tee -a chassis.log
	$i 0x0b 0x0a |tee -a chassis.log
	FailCounter=$(($FailCounter+1))
	Failb=1
else
	echo -e "${color_green}Set Power cycle interval Command finished${color_reset}"|tee -a chassis.log
	$i 0x0b 0x0a |tee -a chassis.log
fi

# raw 0x00 0x07
echo ""
echo -e "${color_convert}Get System Restart Cause Command${color_reset}"|tee -a chassis.log
echo "Response below :" |tee -a chassis.log
$i 0x07 # Get System Restart Cause.
if [ $? -eq '1' ] ; then
	echo -e "${color_red}Get System Restart Cause Command failed ${color_reset}"|tee -a chassis.log
	$i 0x07 |tee -a chassis.log
	FailCounter=$(($FailCounter+1))
	Fail7=1
else
	$i 0x07 |tee -a chassis.log
	#Get Restart Cause response byte
	read RS1 RS2 <<< $($i 0x07)
	for j in RS{1,2}; do
		eval temp=\$$j
		temp=${D2B[$((16#$temp))]}
		read $j'b1' $j'b2' $j'b3' $j'b4' $j'b5' $j'b6' $j'b7' $j'b8' <<< "${temp:0:1} ${temp:1:1} ${temp:2:1} ${temp:3:1} ${temp:4:1} ${temp:5:1} ${temp:6:1} ${temp:7:1}"
	done
	#Restart Cause
	case $RS1b5$RS1b6$RS1b7$RS1b8 in
		0000) echo -e "${color_green}unknown (system start/restart detected, but cause unknown)${color_reset}"|tee -a chassis.log;;
		0001) echo -e "${color_green}Chassis Control command${color_reset}"|tee -a chassis.log;;
		0010) echo -e "${color_green}reset via pushbutton${color_reset}"|tee -a chassis.log;;
		0011) echo -e "${color_green}power-up via power pushbutton${color_reset}"|tee -a chassis.log;;
		0100) echo -e "${color_green}Watchdog expiration (see watchdog flags) [required]${color_reset}"|tee -a chassis.log;;
		0101) echo -e "${color_green}OEM${color_reset}"|tee -a chassis.log;;
		0110) echo -e "${color_green}automatic power-up on AC being applied due to ‘always restore’ power restore policy${color_reset}"|tee -a chassis.log;;
		0111) echo -e "${color_green}automatic power-up on AC being applied due to ‘restore previous power state’ power restore policy${color_reset}"|tee -a chassis.log;;
		1000) echo -e "${color_green}reset via PEF${color_reset}"|tee -a chassis.log;;
		1001) echo -e "${color_green}power-cycle via PEF${color_reset}"|tee -a chassis.log;;
		1010) echo -e "${color_green}soft reset${color_reset}"|tee -a chassis.log;;
		1011) echo -e "${color_green}power-up via RTC${color_reset}"|tee -a chassis.log;;
		1100) echo -e "${color_green}Reserved${color_reset}"|tee -a chassis.log;;
		1101) echo -e "${color_green}Reserved${color_reset}"|tee -a chassis.log;;
		1110) echo -e "${color_green}Reserved${color_reset}"|tee -a chassis.log;;
		1111) echo -e "${color_green}Reserved${color_reset}"|tee -a chassis.log;;
	esac
	echo ""
	#Channel number that command was recived over
	echo "${color_green}This command was recieved via channel $RS2${color_reset}"|tee -a chassis.log
	echo -e "${color_green}Get System Restart Cause Command finished${color_reset}"|tee -a chassis.log
fi

# raw 0x00 0x08
echo ""
echo -e "${color_convert}Set System Boot Options Command${color_reset}"|tee -a chassis.log
echo "Response below :" |tee -a chassis.log
$i 0x08 0x05 0xe0 0x18 0x00 0x00 0x00  # Set boot option that force boot into BIOS every time.
if [ $? -eq '1' ] ; then
	echo -e "${color_red}Set System Boot Options Command failed ${color_reset}"|tee -a chassis.log
	$i 0x08 0x05 0xe0 0x18 0x00 0x00 0x00 |tee -a chassis.log
	FailCounter=$(($FailCounter+1))
	Fail8=1
else
	echo -e "${color_green}Set System Boot Options Command finished${color_reset}"|tee -a chassis.log
	$i 0x08 0x05 0xe0 0x18 0x00 0x00 0x00 |tee -a chassis.log
fi

# raw 0x00 0x09
echo ""
echo -e "${color_convert}Get System Boot Options Command${color_reset}"|tee -a chassis.log
echo "Response below :" |tee -a chassis.log
$i 0x09 0x05 0x00 0x00  # Get System Boot Options.
if [ $? -eq '1' ] ; then
	echo -e "${color_red}Get System Boot Options Command failed ${color_reset}"|tee -a chassis.log
	$i 0x09 0x05 0x00 0x00 |tee -a chassis.log 
	FailCounter=$(($FailCounter+1))
	Fail9=1
else
	if [ "$($i 0x09 0x05 0x00 0x00)" == " 01 05 e0 18 00 00" ]; then # Check the value match the setting.
		echo -e "${color_green}Get System Boot Options Command finished${color_reset}"|tee -a chassis.log
		$i 0x09 0x05 0x00 0x00 |tee -a chassis.log
	else
		echo -e "${color_red}Get System Boot Options Command failed ${color_reset}"
		$i 0x09 0x05 0x00 0x00 |tee -a chassis.log
		$FailCounter=$(($FailCounter+1))
		Fai9=1
	fi
fi

# raw 0x00 0x0f
echo ""
echo -e "${color_convert}Get POH Counter Command${color_reset}" |tee -a chassis.log
echo "Response below :" |tee -a chassis.log
$i 0x0f # Get POH time.
if [ $? -eq '1' ] ; then
	echo -e "${color_red}Get POH Counter Command failed ${color_reset}"|tee -a chassis.log
	$i 0x0f |tee -a chassis.log
	FailCounter=$(($FailCounter+1))
	Faif=1
else
	$i 0x0f |tee -a chassis.log
	#Get POH response byte
	read POH1 POH2 POH3 POH4 POH5 <<< $($i 0x0f)
	for j in POH{1..5}; do
		eval temp=\$$j
		temp=${D2B[$((16#$temp))]}
		read $j'b1' $j'b2' $j'b3' $j'b4' $j'b5' $j'b6' $j'b7' $j'b8' <<< "${temp:0:1} ${temp:1:1} ${temp:2:1} ${temp:3:1} ${temp:4:1} ${temp:5:1} ${temp:6:1} ${temp:7:1}"
	done
	#POH time
	let POHCount=$(((((16#$POH5$POH4$POH3$POH2)*$((16#$POH1)))/60/24)))"Days",$(((((16#$POH5$POH4$POH3$POH2)*$((16#$POH1)))/60%24)))"Hours",$(((((16#$POH5$POH4$POH3$POH2)*$((16#$POH1)))%60)))"minutes" #快寫到不知道在寫甚麼了...
	echo -e "${color_green}The POH counter per $((16#$POH1)) minutes a count${color_reset}"|tee -a chassis.log
	echo -e "${color_green}POH counter : $POHCount${color_reset}"|tee -a chassis.log
	echo -e "${color_green}Get POH Counter Command finished${color_reset}"|tee -a chassis.log
fi
echo ""
echo "------------------------------------------------------------------------------------------------"

if [ $FailCounter -eq '0' ]; then
	echo -e "${color_green}Chassis function test finished.${color_reset}" |tee -a chassis.log
else
	echo -e "${color_red}Chassis function test finished but has some command failed check the log please.${color_reset}"|tee -a chassis.log
fi

date|tee -a chassis.log
read OSInfo <<< $(cat /etc/os-release|grep -i pretty|cut -d = -f 2)
echo "$USER testing in $OSInfo finished"
