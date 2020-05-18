  #!/bin/bash

#Backup and rename previous log 
#echo -e "Remove and backup the previous log as date format..."
#if [ -f "Chassis.log" ]; then
#	cp Chassis.log $(date +%Y%m%d)_Chassis.log && rm -f Chassis.log
#fi

#Print user and os info
date|tee -a Chassis.log
read OSInfo <<< $(cat /etc/redhat-release)
echo "$USER start testing in $OSInfo..."|tee -a Chassis.log

echo ''
i="ipmitool raw 0x00"
sleep 1
color_reset='\e[0m'
color_green='\e[32m'
color_red='\e[31m'
color_convert='\e[7m'
color_blue='\e[34m'
FailCounter=0
D2B=({0..1}{0..1}{0..1}{0..1}{0..1}{0..1}{0..1}{0..1})
FailCounter=0
echo ""
# raw 0x00 0x00
## Get Chassis capabilities
echo -e " Get Chassis Capabilities" |tee -a Chassis.log
echo " Response below :" |tee -a Chassis.log
$i 0x00
if [ $? -eq '1' ] ; then
	$i 0x00 >> Chassis.log
	echo -e " Get Chassis Capabilities failed" |tee -a Chassis.log
	FailCounter=$(($FailCounter+1))
	Fail0=1
else
	$i 0x00 >> Chassis.log
	read CC1 CC2 CC3 CC4 CC5 CC6 <<< $($i 0x00)
	for j in CC{1..6}; do
		eval temp=\$$j
		temp=${D2B[$((16#$temp))]}
		read $j'b1' $j'b2' $j'b3' $j'b4' $j'b5' $j'b6' $j'b7' $j'b8' <<< "${temp:0:1} ${temp:1:1} ${temp:2:1} ${temp:3:1} ${temp:4:1} ${temp:5:1} ${temp:6:1} ${temp:7:1}"
	done
	#Capabilities Flags
	echo -e "*Capabilities Flags*" |tee -a Chassis.log
	echo " This SUT provides capabilities below :"
	if [ $CC1b5 -eq '1' ];then
		echo " Power interlock (IPMI1.5)."|tee -a Chassis.log
	fi
	if [ $CC1b6 -eq '1' ];then
		echo " Diagnostic Interrupt (FP NMI)(IPMI1.5)."|tee -a Chassis.log
	fi
	if [ $CC1b7 -eq '1' ];then
		echo " Front Panel Lockout."|tee -a Chassis.log
	fi
	if [ $CC1b8 -eq '1' ];then
		echo " Chassis intrusion sensor(physical security)."|tee -a Chassis.log
	fi
	echo ''|tee -a Chassis.log
	#Chassis FRU info Device Address
	echo " All IPMB address used in this command are have the 7-bit I2C slave address as the most-significant 7-bits and the least significant bit set to 0b."|tee -a Chassis.log
	echo -e " The FRU info Device address is $CC2." |tee -a Chassis.log
	#Chassis SDR device Address
	echo ""|tee -a Chassis.log
	echo -e " The SDR Device address is $CC3." |tee -a Chassis.log
	#Chassis SEL device Address
	echo ""|tee -a Chassis.log
	echo -e " The SEL Device address is $CC4." |tee -a Chassis.log
	#Chassis System Management Device device Address
	echo ""|tee -a Chassis.log
	echo -e " The SDR Device address is $CC5." |tee -a Chassis.log
	#Chassis Bridge Device Address
	echo ""|tee -a Chassis.log
	if [ -z $CC6 ];then
		echo -e " This SUT doesn't provide this address, but the adderes is assumed to be the BMC adderess 20h generally."|tee -a Chassis.log
	else
		echo -e " The Bridge Device adderess is $CC6."|tee -a Chassis.log
	fi
	echo ""|tee -a Chassis.log
	echo -e " The SDR Device address is $CC5." |tee -a Chassis.log
	echo ""|tee -a Chassis.log
	echo -e " Get Chassis Capabiliteis command finished"|tee -a Chassis.log
fi

### raw 0x00 0x01
echo ""|tee -a Chassis.log
###Get Chassis status
echo -e "*Get Chassis Status*" |tee -a Chassis.log
echo " Response below :" |tee -a Chassis.log
$i 0x01
if [ $? -eq '1' ] ; then
	$i 0x01 >>Chassis.log
	echo -e " Get Chassis Status failed"|tee -a Chassis.log
	FailCounter=$(($FailCounter+1))
	Fail1=1
else
	$i 0x01 >>Chassis.log
	read CS1 CS2 CS3 CS4 <<< $($i 0x01)
	for j in CS{1..4}; do
		eval temp=\$$j
		temp=${D2B[$((16#$temp))]}
		read $j'b1' $j'b2' $j'b3' $j'b4' $j'b5' $j'b6' $j'b7' $j'b8' <<< "${temp:0:1} ${temp:1:1} ${temp:2:1} ${temp:3:1} ${temp:4:1} ${temp:5:1} ${temp:6:1} ${temp:7:1}"
	done
	#Current Power State
	case "$CS1b2$CS1b3" in 
		"00")echo -e " Power Policy is Always off after AC/mains."|tee -a Chassis.log;;
		"01")echo -e " Power Policy is Previous status after AC/mains."|tee -a Chassis.log;;
		"02")echo -e " Power Policy is Always on after AC/mains."|tee -a Chassis.log;;
		"11")echo -e " Power Policy is Unknown."|tee -a Chassis.log;;
	esac
	#Power Control Fault
	if [ "$CS1b4" -eq '1' ];then
		echo -e " Controller attempted to turn system power on or off, but system did not enter desired state."|tee -a Chassis.log
	else
		echo -e " No Power Control Fault." |tee -a Chassis.log
	fi
	#Power Fault
	if [ "$CS1b5" -eq '1' ];then
		echo -e " Fault detected in main power subsystem." |tee -a Chassis.log
	else 
		echo -e " No Power Fault."|tee -a Chassis.log
	fi
	#Interlock
	if [ "$CS1b6" -eq '1' ];then
		echo -e " Power Interlock (Chassis is presently shut down because a Chassis panel interlock switch is active). (IPMI 1.5)"|tee -a Chassis.log
	else
		echo -e " No Power Interlock."|tee -a Chassis.log
	fi
	#Power overload
	if [ "$CS1b7" -eq '1' ];then
		echo -e " System shutdown because of power overload condition."|tee -a Chassis.log
	else
		echo -e " No Power Overload."|tee -a Chassis.log
	fi
	#Power status
	if [ "$CS1b8" -eq '1' ];then
		echo -e " System Power is on."|tee -a Chassis.log
	else
		echo -e " System Power is off."|tee -a Chassis.log
	fi
	echo ''
	if [ "$CS1b4$CS1b5$CS1b6$CS1b7"=="0000" ];then
		echo -e " Power state is normall."|tee -a Chassis.log
	else
		echo -e " There's error in Power state."|tee -a Chassis.log
	fi
	echo ''
	#Last power event
	if [ "$CS2b4" -eq '1' ] ;then
		echo -e " The last 'Power is on' state was entered via IPMI command"|tee -a Chassis.log
	fi
	case "$CS2b3$CS2b2$CS2b1$CS2b0" in
		0000) echo -e " No Last Power Event"|tee -a Chassis.log;;
		0001) echo -e " The Last Power down caused by AC Faild"|tee -a Chassis.log;;
		0010) echo -e " The Last Power down caused by a Power overload"|tee -a Chassis.log ;;
		0100) echo -e " The Last Power down caused by a Power interlock being activated"|tee -a Chassis.log ;;
		1000) echo -e " The Last Power down caused by a Power fault"|tee -a Chassis.log;;
	esac
	echo ''|tee -a Chassis.log
	#Misc. Chassis State
	if [ "$CS3b2" -eq '1' ];then 
		echo " Chassis Identify command and state info supported. (Optional)"|tee -a Chassis.log
	else
		echo " Chassis Identify command support unspecified via this command. (The Get Command Support command, if implemented, would still indicate support for the Chassis Identify command)"|tee -a Chassis.log
	fi
	case "$CS3b3$CS3b4" in 
		00) echo -e " Chassis identify state = Off"|tee -a Chassis.log;;
		01) echo -e " Chassis identify state = Temporary On"|tee -a Chassis.log;;
		10) echo -e " Chassis identify state = Indefinite On"|tee -a Chassis.log;;
		11) echo -e " This bit is Reserve."|tee -a Chassis.log;;
	esac
	if [ "$CS3b5" -eq '1' ];then
		echo -e " Cooling/fan fault detected."|tee -a Chassis.log
	else 
		echo -e " Cooling/fan works good."|tee -a Chassis.log
	fi
	echo ''|tee -a Chassis.log
	if [ "$CS3b6" -eq '1' ];then
		echo -e " Drive Fault detected."|tee -a Chassis.log
	else 
		echo -e " All Drives works good."|tee -a Chassis.log
	fi
	echo ''|tee -a Chassis.log
	if [ "$CS3b7" -eq '1' ];then
		echo -e " Front Panel Lockout active (power off and reset via Chassis push-buttons disabled.)"|tee -a Chassis.log
	else 
		echo -e " Front Panel Lockout deactive (power off and reset via Chassis push-buttons ensabled.)"|tee -a Chassis.log
	fi
	echo '' |tee -a Chassis.log
		if [ "$CS3b8" -eq '1' ];then
		echo -e " Chassis intrusion active."|tee -a Chassis.log
	else 
		echo -e " Chassis intrusion deactive."|tee -a Chassis.log
	fi
	echo ''|tee -a Chassis.log
	#Front Panel Button Capabilities and disable/enable status (Optional)(“Button” actually refers to the ability for the local user to be able to perform the specified functions via a pushbutton, switch, or other ‘front panel’ control built into the system Chassis.)
	if [ -z "$CS4b1" ];then
		echo -e " The SUT doesn't support getting 'Front Panel Button Capabilities and disable/enable status'"
	fi
	
	if [ "$CS4b1" -eq '1' ];then
		echo -e " Standby (sleep) button disable allowed."|tee -a Chassis.log
	else
		echo -e " Standby (sleep) button disable not allowed."|tee -a Chassis.log
	fi
	if [ "$CS4b2" -eq '1' ];then
		echo -e " Diagnostic Interrupt button disable allowed."|tee -a Chassis.log
	else
		echo -e " Diagnostic Interrupt button disable not allowed."|tee -a Chassis.log
	fi
	if [ "$CS4b3" -eq '1' ];then
		echo -e " Reset button disable allowed."|tee -a Chassis.log
	else
		echo -e " Reset button disable not allowed."|tee -a Chassis.log
	fi
	if [ "$CS4b4" -eq '1' ];then
		echo -e " Power off button disable allowed (in the case there is a single combined power/standby (sleep) button, disabling power off also disables sleep requests via that button.)."|tee -a Chassis.log
	else
		echo -e " Power off button disable not allowed (in the case there is a single combined power/standby (sleep) button, disabling power off also disables sleep requests via that button.)."|tee -a Chassis.log
	fi
	if [ "$CS4b5" -eq '1' ];then
		echo -e " Standby (sleep) button disabled."|tee -a Chassis.log
	else
		echo -e " Standby (sleep) button enabled."|tee -a Chassis.log
	fi
	if [ "$CS4b6" -eq '1' ];then
		echo -e " Diagnostic Interrupt button disabled."|tee -a Chassis.log
	else
		echo -e " Diagnostic Interrupt button enabled."|tee -a Chassis.log
	fi
	if [ "$CS4b7" -eq '1' ];then
		echo -e " Reset button disabled."|tee -a Chassis.log
	else
		echo -e " Reset button enabled."|tee -a Chassis.log
	fi
	if [ "$CS4b8" -eq '1' ];then
		echo -e " Power off button disabled(in the case there is a single combined power/standby (sleep) button, then this indicates that sleep requests via that button are also disabled.)."|tee -a Chassis.log
	else
		echo -e " Power off button enabled(in the case there is a single combined power/standby (sleep) button, then this indicates that sleep requests via that button are also disabled.)."|tee -a Chassis.log
	fi
	echo ''|tee -a Chassis.log	
	echo -e " Get Chassis Status finished" |tee -a Chassis.log
fi

# raw 0x00 0x02 Set Power control (Power off, Power on, Power cycle, Diagnostic interrupt, Power soft)
#echo ""
#echo ""
#echo "------------------------------------------------------------------------------------------------"
#echo Chassis Control >> Chassis.log
#for j in {0..5}; do
#	$i 0x02 0x0$j
#if [ ! $?==0 ] ; then
#		echo Chassis Control failed in bit $j
#		$i 0x02 0x0$j >> Chassis.log
#		echo " Chassis Control $i 0x02 0x0$j fail " >> Chassis.log
#		sleep 300
#	else
#		echo Get Chassis Capabilities success
#		$i 0x00 >> Chassis.log
#		echo " Chassis Control $i 0x02 0x0$j success " >> Chassis.log
#		sleep 300
#	fi
#done

#raw 0x00 0x03 Set for ICMB Chassis reset (System Hard reset)
#echo ""
#echo ""
#echo "------------------------------------------------------------------------------------------------"
#echo Chassis Rest >> Chassis.log
#echo "Response below :" >> Chassis.log
#$i 0x03
#if [ ! $?==0 ] ; then
#	echo Chassis Rest failed 
#	$i 0x03 >> Chassis.log
#	echo " Chassis Rest $i 0x03 fail " >> Chassis.log
#	$FailCounter=$(($FailCounter+1))
#	Fail3=1
#else
#	echo Chassis Rest success
#	$i 0x01 >> Chassis.log
#	echo " Chassis Rest $i 0x03 success " >> Chassis.log
#fi

# raw 0x00 0x04
echo ""|tee -a Chassis.log
echo -e "*Chassis Identify command*" |tee -a Chassis.log
echo -e "Check the Identify LED......"
echo " Response below :" |tee -a Chassis.log
# Set Force identify LED on you can enter raw 0x00 0x04 0x00 for turn off the LED.
$i 0x04 0x00 0x01
if [ $? -eq '1' ] ; then
	$i 0x0a 0x04 0x00 0x01 >> Chassis.log
	echo -e " Chassis Identify command failed"|tee -a Chassis.log
	FailCounter=$(($FailCounter+1))
	Fail4=1
else
	echo " Check the identify LED solid on of not..."
	echo -e " Chassis Identify finished" |tee -a Chassis.log
fi

# raw 0x00 0x0a
echo ""|tee -a Chassis.log
echo -e "*Set Front Panel Enables*" |tee -a Chassis.log
echo " Check all front panel button including power button reset button and diagnostic interrupt button(if support) should can't perform action......"|tee -a Chassis.log
echo " Response below :" |tee -a Chassis.log
# Set all button disable
$i 0x0a 0x0f 
if [ $? -eq '1' ] ; then
	$i 0x0a 0x0f >> Chassis.log
	echo -e " Set Front Panel Enables failed"|tee -a Chassis.log
	FailCounter=$(($FailCounter+1))
	Faila=1
else
	echo -e " Set all Front Panel Button disabled finished " | tee -a Chassis.log
fi

# raw 0x00 0x05
echo ""|tee -a Chassis.log
echo -e "*Set Chassis Capabilities Command*" |tee -a Chassis.log
	R=$(ipmitool raw 0x00 0x00)
	R1=$(echo $R|awk '{print$1}')
	R2=$(echo $R|awk '{print$2}')
	R3=$(echo $R|awk '{print$3}')
	R4=$(echo $R|awk '{print$4}')
	R5=$(echo $R|awk '{print$5}')
	R6=$(echo $R|awk '{print$6}')
echo " Response below :" |tee -a Chassis.log
$i 0x05 0x00 0x20 0x20 0x20 0x20 0x28 # Set some FRU SDR SEL SM Bridge address you may need to restore the setting.
if [ $? -eq '1' ] ; then
	$i 0x05 0x00 0x20 0x20 0x20 0x20 0x28 >> Chassis.log
	echo -e " Set Chassis Capabilities Command failed "|tee -a Chassis.log
	FailCounter=$(($FailCounter+1))
	Fail5=1
else
	$i 0x05 0x00 0x20 0x20 0x20 0x20 0x28 >> Chassis.log
	if [ "$($i 0x00)"=="00 20 20 20 20 28" ] ;then
		echo -e " Set Chassis Capabilities Command finished"|tee -a Chassis.log
	else
		echo -e " Set Chassis Capabilities Command failed "|tee -a Chassis.log
		FailCounter=$(($FailCounter+1))
	fi
		echo " Restore setting..."
		$i 0x05 0x$R1 0x$R2 0x$R3 0x$R4 0x$R5 0x$R6 #Restore the cabilities
		echo "Restore finished."
fi

# raw 0x00 0x06
echo ""|tee -a Chassis.log
echo -e "*Set Power Restore Policy Command*"|tee -a Chassis.log
echo " Response below :" |tee -a Chassis.log
$i 0x06 0x00 # Set Power policy always off after AC on.
if [ $? -eq '1' ] ; then
	$i 0x06 0x00 |tee -a Chassis.log
	echo -e " Set Power Restore Policy Command failed "|tee -a Chassis.log
	FailCounter=$(($FailCounter+1))
	Fail6=1
else
	if [ "$(ipmitool raw 0x00 0x01|awk '{print$1}')"=="01" ]; then
		$i 0x06 0x00 |tee -a Chassis.log
		echo -e " Set Power Restore Policy Command finished"|tee -a Chassis.log
	else
		$i 0x06 0x00 |tee -a Chassis.log
		echo -e " Set Power Restore Policy Command failed "|tee -a Chassis.log
		$FailCounter=$(($FailCounter+1))
		Fail6=1
	fi
fi

# raw 0x00 0x0b
echo ""|tee -a Chassis.log
echo -e "*Set Power cycle interval Command*"|tee -a Chassis.log
echo " Response below :" |tee -a Chassis.log
$i 0x0b 0x0a # Set Power cycle interval as 10sec.
if [ $? -eq '1' ] ; then
	$i 0x0b 0x0a |tee -a Chassis.log
	echo -e " Set Power cycle interval Command failed "|tee -a Chassis.log
	FailCounter=$(($FailCounter+1))
	Failb=1
else
	$i 0x0b 0x0a |tee -a Chassis.log
	echo -e " Set Power cycle interval Command finished"|tee -a Chassis.log
fi

# raw 0x00 0x07
echo ""|tee -a Chassis.log
echo -e "*Get System Restart Cause Command*"|tee -a Chassis.log
echo " Response below :" |tee -a Chassis.log
$i 0x07 # Get System Restart Cause.
if [ $? -eq '1' ] ; then
	$i 0x07 >> Chassis.log
	echo -e " Get System Restart Cause Command failed "|tee -a Chassis.log
	FailCounter=$(($FailCounter+1))
	Fail7=1
else
	$i 0x07 >> Chassis.log
	#Get Restart Cause response byte
	read RS1 RS2 <<< $($i 0x07)
	for j in RS{1,2}; do
		eval temp=\$$j
		temp=${D2B[$((16#$temp))]}
		read $j'b1' $j'b2' $j'b3' $j'b4' $j'b5' $j'b6' $j'b7' $j'b8' <<< "${temp:0:1} ${temp:1:1} ${temp:2:1} ${temp:3:1} ${temp:4:1} ${temp:5:1} ${temp:6:1} ${temp:7:1}"
	done
	#Restart Cause
	case $RS1b5$RS1b6$RS1b7$RS1b8 in
		0000) echo -e " Unknown(system start/restart detected, but cause unknown)"|tee -a Chassis.log;;
		0001) echo -e " Chassis Control command"|tee -a Chassis.log;;
		0010) echo -e " Reset via pushbutton"|tee -a Chassis.log;;
		0011) echo -e " Power-up via power pushbutton"|tee -a Chassis.log;;
		0100) echo -e " Watchdog expiration (see watchdog flags) [required]"|tee -a Chassis.log;;
		0101) echo -e " OEM"|tee -a Chassis.log;;
		0110) echo -e " Automatic power-up on AC being applied due to ‘always restore’ power restore policy"|tee -a Chassis.log;;
		0111) echo -e " Automatic power-up on AC being applied due to ‘restore previous power state’ power restore policy"|tee -a Chassis.log;;
		1000) echo -e " Reset via PEF"|tee -a Chassis.log;;
		1001) echo -e " Power-cycle via PEF"|tee -a Chassis.log;;
		1010) echo -e " Soft reset"|tee -a Chassis.log;;
		1011) echo -e " Power-up via RTC"|tee -a Chassis.log;;
		1100) echo -e " This byte is Reserved check the Spec please"|tee -a Chassis.log;;
		1101) echo -e " This byte is Reserved check the Spec please"|tee -a Chassis.log;;
		1110) echo -e " This byte is Reserved check the Spec please"|tee -a Chassis.log;;
		1111) echo -e " This byte is Reserved check the Spec please"|tee -a Chassis.log;;
	esac
	echo ""|tee -a Chassis.log
	#Channel number that command was recived over
	echo -e " This command was recieved via channel $RS2"|tee -a Chassis.log
	echo ""|tee -a Chassis.log
	echo -e " Get System Restart Cause Command finished"|tee -a Chassis.log
fi

# raw 0x00 0x08
echo ""|tee -a Chassis.log
echo -e "*Set System Boot Options Command*"|tee -a Chassis.log
echo " Response below :" |tee -a Chassis.log
$i 0x08 0x05 0xe0 0x18 0x00 0x00 0x00  # Set boot option that force boot into BIOS every time.
if [ $? -eq '1' ] ; then
	$i 0x08 0x05 0xe0 0x18 0x00 0x00 0x00 |tee -a Chassis.log
	echo -e " Set System Boot Options Command failed "|tee -a Chassis.log
	FailCounter=$(($FailCounter+1))
	Fail8=1
else
	$i 0x08 0x05 0xe0 0x18 0x00 0x00 0x00 |tee -a Chassis.log
	echo -e " Set System Boot Options Command finished"|tee -a Chassis.log
fi

# raw 0x00 0x09
echo ""|tee -a Chassis.log
echo -e "*Get System Boot Options Command*"|tee -a Chassis.log
echo "Response below :" |tee -a Chassis.log
$i 0x09 0x05 0x00 0x00  # Get System Boot Options.
if [ $? -eq '1' ] ; then
	$i 0x09 0x05 0x00 0x00 |tee -a Chassis.log 
	echo -e " Get System Boot Options Command failed "|tee -a Chassis.log
	FailCounter=$(($FailCounter+1))
	Fail9=1
else
	if [ "$($i 0x09 0x05 0x00 0x00)"=="01 05 e0 18 00 00" ]; then # Check the value match the setting.
		$i 0x09 0x05 0x00 0x00 |tee -a Chassis.log
		echo -e " Get System Boot Options Command finished"|tee -a Chassis.log
	else
		$i 0x09 0x05 0x00 0x00 |tee -a Chassis.log
		echo -e " Get System Boot Options Command failed "
		$FailCounter=$(($FailCounter+1))
		Fai9=1
	fi
fi

# raw 0x00 0x0f
echo ""|tee -a Chassis.log
echo -e " *Get POH Counter Command*" |tee -a Chassis.log
echo " Response below :" |tee -a Chassis.log
$i 0x0f # Get POH time.
if [ $? -eq '1' ] ; then
	$i 0x0f |tee -a Chassis.log
	echo -e " Get POH Counter Command failed "|tee -a Chassis.log
	FailCounter=$(($FailCounter+1))
	Failf=1
else
	$i 0x0f |tee -a Chassis.log
	#Get POH response byte
	read POH1 POH2 POH3 POH4 POH5 <<< $($i 0x0f)
	for j in POH{1..5}; do
		eval temp=\$$j
		temp=${D2B[$((16#$temp))]}
		read $j'b1' $j'b2' $j'b3' $j'b4' $j'b5' $j'b6' $j'b7' $j'b8' <<< "${temp:0:1} ${temp:1:1} ${temp:2:1} ${temp:3:1} ${temp:4:1} ${temp:5:1} ${temp:6:1} ${temp:7:1}"
	done
	#POH time
	let POHDay=$(((((16#$POH5$POH4$POH3$POH2)*$((16#$POH1)))/60/24)))
	let POHHour=$(((((16#$POH5$POH4$POH3$POH2)*$((16#$POH1)))/60%24)))
	let POHMin=$(((((16#$POH5$POH4$POH3$POH2)*$((16#$POH1)))%60)))
	let POHCount="Days","Hours","minutes" #快寫到不知道在寫甚麼了...
	echo -e " The POH counter per $((16#$POH1)) minutes a count"|tee -a Chassis.log
	echo -e " POH counter : $POHCount"|tee -a Chassis.log
	echo -e " Get POH Counter Command finished"|tee -a Chassis.log
fi
echo ""|tee -a Chassis.log

if [ $FailCounter -eq '0' ]; then
	echo -e " Chassis function test pass."|tee -a Result
else
	echo -e " Chassis function test finished but has some command failed check the Chassis.log please."| tee -a Result
	echo "Fail command below :"|tee -a Result
	for i in {0,1,2,3,4,5,6,7,8,9,a,b,c,d,e,f};
	do
		temp=fail$i
		eval temp=\$$temp
		if [ $temp -eq 1 ];then
			echo "0x00 0x$i"|tee -a Result
		fi
	done
fi

