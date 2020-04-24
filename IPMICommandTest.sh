#!/bin/bash

###################################################################################################
#																								  #
#			 		This bash script is for ipmitool command test 								  #
#  					Editor : IanYH_Lai	version v 1.0											  #
# 		Using this script with input the argument that which Netfn and platform be tested    	  #
# 																								  #
# 0 = chassis function 																			  #
# 2 = bridge (not inplement yet) 																  #
# 4 = S/E 																						  #
# 6 = App																						  #
# 8 = firmware  																				  #
# a = storage 																					  #
# c = transport																					  #
# all 																							  #
#																								  #
# *project name* will implement oem command test 												  #
# 																								  #
#																								  #
#																								  #
###################################################################################################
echo "Backup the SEL and clear it..."
read -t 10 -p "Wait for 10 seconds to clear..."
ipmitool -v sel elist > $(date +%Y%m%d_%T)_SELBeforeTest
ipmitool sel clear

color_reset='\e[0m'
color_green='\e[32m'
color_blue='\e[34m'
color_red='\e[31m'
color_convert='\e[7m'
clear
echo ""
echo ""
echo -e "  ${color_green}0 = chassis function.${color_reset} Most command of this function need to verify by human so automation on this function is not efficient.(Not recommand)"
echo -e "  ${color_green}2 = bridge function.${color_reset} This function is not implement yet due to there's no ICMB environment currently"
echo -e "  ${color_green}4 = S/E function.${color_reset}" 																						
echo -e "  ${color_green}6 = App function."																				  
echo -e "  8 = firmware function."
echo -e "  a = storage function."									  
echo -e "  c = transport function."
echo -e "  ${color_green}For all function just type all.${color_reset}"
echo  "  help or h or ? for script info"

function Test_Fuction () {
	read -t 10 -p "Please select the Netfn use the space key to distinguash the multiple function(default : Chassis,App,S/E) : " Netfn
	Netfn=$(Netfn:="0 4 6")
	#Read Netfn in to upto 7 function being selected
	read Fn1 Fn2 Fn3 Fn4 Fn5 Fn6 Fn7 <<< "$Netfn"
	#Function array for check which function being selected
	Fn=(0 0 0 0 0 0 0)
	#Fn Counter
	FnC=0
	for i in Fn{1..7}
	do
		eval Temp=\$$i
		case $Temp in
			'bye' | 'exit' | 'esc' | 'Exit' | 'Bye' | 'EXIT' | 'BYE' | 'q' | 'Q') echo " Bye, $USER quit the test..." && exit ;;
			'help'|'h'|'?') clear & more help.txt && Test_Fuction;;
			all | All | ALL ) echo Test All Netfn... & ./All.sh && break;;
			'') break;;
			chassis | "0" | 0x00) echo Select chassis Netfn command & Fn[0]=1 && continue ;;
			bridge | "2" | 0x02) echo Select Bridge Netfn command & Fn[1]=1 && continue ;;
			SE | "4" | 0x04) echo Select SE Netfn command & Fn[2]=1 && continue ;;
			App | "6" | 0x06) echo Select App Netfn command & Fn[3]=1 && continue ;;
			firmware | "8" | 0x08) echo Select Firmware Netfn command & Fn[4]=1 && continue ;;
			Storage | "a" | 0x0a) echo Select Storage Netfn command & Fn[5]=1 && continue ;;
			transport | "c" | 0x0c) echo Select Transport Netfn command & Fn[6]=1 && continue ;;
			*) echo -e "${color_red} Could not identify the function please enter the function agan...${color_reset}" & exit;;
		esac
	done
	echo""
	for i in {0..6};
	do
		if [ ${Fn[$i]} -eq 1 ];then
			FnC=1 && break;
		fi
	done
		
	if [ $FnC -eq 1 ];then
		echo -e "${color_blue}Start Testing selected function...${color_reset}"
	else
		clear && echo -e "${color_red}No Netfn select, end testing...${color_reset}" 
	fi
	if [ ${Fn[0]} -eq '1' ];then
		./Chassis.sh
	fi
	if [ ${Fn[1]} -eq '1' ];then
		./Bridge.sh
	fi
	if [ ${Fn[2]} -eq '1' ];then
		./SE.sh
	fi
	if [ ${Fn[3]} -eq '1' ];then
		./App.sh
	fi
	if [ ${Fn[4]} -eq '1' ];then
		./Firmware.sh
	fi
	if [ ${Fn[5]} -eq '1' ];then
		./Storage.sh
	fi
	if [ ${Fn[6]} -eq '1' ];then
		./Transport.sh
	fi
}

Test_Fuction
