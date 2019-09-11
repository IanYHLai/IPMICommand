#!/bin/bash

echo "																								  "
echo "																								  "
echo "  This bash script is for ipmitool command test 								  "
echo "  Editor : IanYH_Lai	version v 1.0										  "
echo "  Using this script with the argument that which Netfn and platform will be tested    	  "
echo "																							  "
echo "  Input argument as '0x00' or 'chassis' or '0' => chassis function 							  "  
echo "  Input argument as '0x02' or 'bridge' or '2' => bridge (not inplement yet) function			  "
echo "  Input argument as '0x04' or 'SE' or '4' => S/E function										  "
echo "  Input argument as '0x06' or 'App' or '6' => App function 								      "
echo "  Input argument as '0x08' or 'firmware' or '8' => firmware function							  "
echo "  Input argument as '0x01' or 'storage' or 'a' => storage function							  "
echo "  Input argument as '0x0c' or 'transport' or 'c' => transport  function						  "
echo "  Input argument as 'all' or without argument => all function 													  "
echo "  Input argument as 'bye' to end the script                                                     "
echo ""
echo ""

read -p "Input 'bye' to quit the script... or press other key to continue the test script:" fq
case $fq in
	'exit'|'Exit'|'EXIT'|'q'|'Q'|'bye'|'Bye'|'BYE') echo " Bye $USER quit the test..." & exit ;;
	*) clear & echo "Reselect the Function please..." & ./IPMICommandTest.sh ;;
esac
