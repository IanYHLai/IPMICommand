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
color_reset='\e[0m'
color_green='\e[32m'
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
echo -e "  ${color_reset}Other any character or none argument for all function. Except the chassis and bridge function that may modify the system setting."
echo -e "  help or h or ? for script info"

function Test_Fuction () {
	read -p "Please select the Netfn :" Netfn
	case $Netfn in 
	chassis | 0 | 0x00) echo Test chassis Netfn command...  & ./chassis.sh;;
	bridge | 2 | 0x02) echo Test Bridge Netfn command...  & ./bridge.sh;;
	SE | 4 | 0x04) echo Test SE Netfn command...  & ./SE.sh;;
	App | 6 | 0x06) echo Test App Netfn command...  & ./App.sh;;
	firmware | 8 | 0x08) echo Test Firmware Netfn command... & ./firmware.sh;;
	Storage | 'a' | 0x0a) echo Test Storage Netfn command... & ./Storage.sh;;
	transport | 'c' | 0x0c) echo Test Transport Netfn command... & ./transport.sh;;
	'bye' | 'exit' | 'esc' | 'Exit' | 'Bye' | 'EXIT' | 'BYE' | 'q' | 'Q') echo " Bye, $USER quit the test..." & exit ;;
	'help'|'h'|'?') clear & ./help.sh;;
	all | '') echo Test All Netfn... & ./All.sh;;
	*) echo "can not identify the function please enter the function agan..." & echo "" & Test_Fuction;;
	esac
}

Test_Fuction
