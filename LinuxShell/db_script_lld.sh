#!/bin/bash
#1419/1427/1425 Regrex Pattern

get_location(){
	echo -e "Select the Area(6 for Reagent Area):\c"
	read area
	echo -e "Select the Rack(1-6 for R1-R6):\c"
	read rack
	echo -e "Select the Position(1-6 for P1-P6):\c"
	read position
}

zSlippage_filter(){
	if [ "$1" -eq 4 ] ; then
		arm="LAS"
	elif [ "$1" -eq 5 ] ; then
		arm="Sample"
	elif [ "$1" -eq 6 ] ; then
		arm="Reagent"
	elif [ "$1" -eq 7 ] ; then
		arm="Start"
	else 
		echo "wrong para"
	fi
	grep -E "\|"$arm" Arm\|NewPos\||\|EH\|.*\|1367\|$1\|" append.csv | grep -B 1 -E "\|EH\|" > "$arm"_zSlippage.csv
	grep -E "\|"$arm" Arm\|NewPos\|" append.csv > "$arm"_XYZ_Location.csv
}

lld_filter(){
	if [ $rack -lt 4 ] ; then
		grep -E "\|Reagent Arm\|ASPIRATE\|.*\|"$area"\|"$((rack+14))"\|"$((position-1))"\||\|Reagent Arm\|LLD est\. ms\||\|Reagent Arm\|AspLldCheck\|" append.csv | grep -A 2 -E "\|ASPIRATE\|" > ErrorLld_R"$rack"_P"$position".txt
		grep -E "\|Reagent Arm\|ASPIRATE\|.*\|"$area"\|"$((rack+14))"\|"$((position-1))"\||\|GenLog\|.*\|$1\|" append.csv | grep -B 1 -E "\|GenLog\|.*\|$1\|REAGENT 1\|$position\|R$rack\|" > ErrorLldER"$1"_R"$rack"_P"$position".txt
	else 
		grep -E "\|Start Arm\|ASPIRATE\|.*\|"$area"\|"$((rack+14))"\|"$((position-1))"\||\|Start Arm\|LLD est\. ms\||\|Start Arm\|AspLldCheck\|" append.csv | grep -A 2 -E "\|ASPIRATE\|" > ErrorLld_R"$rack"_P"$position".txt
		grep -E "\|Start Arm\|ASPIRATE\|.*\|"$area"\|"$((rack+14))"\|"$((position-1))"\||\|GenLog\|.*\|$1\|" append.csv | grep -B 1 -E "\|GenLog\|.*\|$1\|REAGENT 2\|$position\|R$rack\|" > ErrorLldER"$1"_R"$rack"_P"$position".txt
	fi
}

while true; do
	echo -e "\nSelect Function to Filter Trace File(1/2):"
	echo -e "\n1 : ErrorLLD(1427) in Clean Cup\n2 : ErrorLLD(1419) in Special Location\n3 : ErrorLLD(1427) in Special Location\n4 : LAS Z-Slippage\n5 : Sample Z-Slippage\n6 : Reagent Z-Slippage\n7 : Start Z-Slippage\n8 : exit\n>>:\c"
	read select_func
	if [ "$select_func" -eq 1 ] ; then 
		grep -E "\|Reagent Arm\|Clean Step - Start\|.*\|7\|0\|0\||\|Reagent Arm\|LLD est\. ms\||\|Reagent Arm\|AspLldCheck\|" append.csv | grep -A 2 -E "\|Clean Step - Start\|" > LldCleanCupR1.csv
		grep -E "\|Reagent Arm\|Clean Step - Start\|.*\|7\|0\|0\||\|GenLog\|.*\|1427\|REAGENT 1\|" append.csv | grep -B 1 -E "\|GenLog\|" > ER1427LldCleanCupR1.csv
		grep -E "\|Start Arm\|Clean Step - Start\|.*\|7\|0\|0\||\|Start Arm\|LLD est\. ms\||\|Start Arm\|AspLldCheck\|" append.csv | grep -A 2 -E "\|Clean Step - Start\|" > LldCleanCupR2.csv
		grep -E "\|Start Arm\|Clean Step - Start\|.*\|7\|0\|0\||\|GenLog\|.*\|1427\|REAGENT 2\|" append.csv | grep -B 1 -E "\|GenLog\|" > ER1427LldCleanCupR2.csv
	elif [ "$select_func" -eq 2 ] ; then
		get_location
		lld_filter 1419
	elif [ "$select_func" -eq 3 ] ; then
		get_location
		lld_filter 1425
	elif [ "$select_func" -eq 4 ] ; then
		zSlippage_filter 4
	elif [ "$select_func" -eq 5 ] ; then
		zSlippage_filter 5
	elif [ "$select_func" -eq 6 ] ; then
		zSlippage_filter 6
	elif [ "$select_func" -eq 7 ] ; then
		zSlippage_filter 7
	elif [ "$select_func" -eq 8 ] ; then
		exit
	else
		echo -e "\nPlease Input 1-4 Next Run!!"
	fi
done


