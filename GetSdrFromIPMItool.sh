#!/bin/bash
c=ipmitool sensor get
#Get all sensor name from sdr 
ipmitool sdr | cut -d\| -f 1 --output-delimiter='\n' > AllSensorName.txt
# Get sensor status from sensor get "SensorName" and redirect to sdr.log
while read i ;do
	$c "$i" >> sdr.log
done
