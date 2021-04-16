#!/bin/bash
#1419/1427/1425 Regrex Pattern

echo -e '\nSelect Function to Filter Trace File(1/2):'
echo -e "\n1 : ErrorLLD(1427) in Clean Cup\n2 : ErrorLLD(1419) in Special Location\n3 : ErrorLLD(1427) in Special Location\n>>\c"
read select_func
echo $select_func
if [ "$select_func" -eq 1 ] ; then 
    grep -E "\|Reagent Arm\|Clean Step - Start\|.*\|7\|0\|0\||\|Reagent Arm\|LLD est\. ms\||\|Reagent Arm\|AspLldCheck\|" append.csv | grep -A 2 -E "\|Clean Step - Start\|" > LldCleanCupR1.csv
	grep -E "\|Reagent Arm\|Clean Step - Start\|.*\|7\|0\|0\||\|GenLog\|.*\|1427\|REAGENT 1\|" append.csv | grep -B 1 -E "\|GenLog\|" > ER1427LldCleanCupR1.csv
    grep -E "\|Start Arm\|Clean Step - Start\|.*\|7\|0\|0\||\|Start Arm\|LLD est\. ms\||\|Start Arm\|AspLldCheck\|" append.csv | grep -A 2 -E "\|Clean Step - Start\|" > LldCleanCupR2.csv
	grep -E "\|Start Arm\|Clean Step - Start\|.*\|7\|0\|0\||\|GenLog\|.*\|1427\|REAGENT 2\|" append.csv | grep -B 1 -E "\|GenLog\|" > ER1427LldCleanCupR2.csv
elif [ "$select_func" -eq 2 ] ; then
    echo -e "Select the Area(6 for Reagent Area):\c"
	read area
	echo -e "Select the Rack(15-20 for R1-R6):\c"
	read rack
	echo -e "Select the Position(0-5 for Position1-Position6 ):\c"
	read position
	if [ $rack -lt 18 ] ; then
		grep -E "\|Reagent Arm\|ASPIRATE\|.*\|"$area"\|"$rack"\|"$position"\||\|Reagent Arm\|LLD est\. ms\||\|Reagent Arm\|AspLldCheck\|" append.csv | grep -A 2 -E "\|ASPIRATE\|" > ErrorLld_R"$((rack-14))"_P"$((position+1))".txt
		grep -E "\|Reagent Arm\|ASPIRATE\|.*\|"$area"\|"$rack"\|"$position"\||\|GenLog\|.*\|1419\|" append.csv | grep -B 1 -E "\|GenLog\|.*\|1419\|REAGENT 1\|$((position+1))\|R$((rack-14))\|" > ErrorLldER1419_R"$((rack-14))"_P"$((position+1))".txt
	else 
		grep -E "\|Start Arm\|ASPIRATE\|.*\|"$area"\|"$rack"\|"$position"\||\|Start Arm\|LLD est\. ms\||\|Start Arm\|AspLldCheck\|" append.csv | grep -A 2 -E "\|ASPIRATE\|" > ErrorLld_R"$((rack-14))"_P"$((position+1))".txt
		grep -E "\|Start Arm\|ASPIRATE\|.*\|"$area"\|"$rack"\|"$position"\||\|GenLog\|.*\|1419\|" append.csv | grep -B 1 -E "\|GenLog\|.*\|1419\|REAGENT 2\|$((position+1))\|R$((rack-14))\|" > ErrorLldER1419_R"$((rack-14))"_P"$((position+1))".txt
	fi
elif [ "$select_func" -eq 3 ] ; then
    echo -e "Select the Area(6 for Reagent Area):\c"
	read area
	echo -e "Select the Rack(15-20 for R1-R6):\c"
	read rack
	echo -e "Select the Position(0-5 for Position1-Position6 ):\c"
	read position
	if [ $rack -lt 18 ] ; then
		grep -E "\|Reagent Arm\|ASPIRATE\|.*\|"$area"\|"$rack"\|"$position"\||\|Reagent Arm\|LLD est\. ms\||\|Reagent Arm\|AspLldCheck\|" append.csv | grep -A 2 -E "\|ASPIRATE\|" > ErrorLld_R"$((rack-14))"_P"$((position+1))".txt
		grep -E "\|Reagent Arm\|ASPIRATE\|.*\|"$area"\|"$rack"\|"$position"\||\|GenLog\|.*\|1425\|" append.csv | grep -B 1 -E "\|GenLog\|.*\|1425\|REAGENT 1\|$((position+1))\|R$((rack-14))\|" > ErrorLldER1425_R"$((rack-14))"_P"$((position+1))".txt
	else 
		grep -E "\|Start Arm\|ASPIRATE\|.*\|"$area"\|"$rack"\|"$position"\||\|Start Arm\|LLD est\. ms\||\|Start Arm\|AspLldCheck\|" append.csv | grep -A 2 -E "\|ASPIRATE\|" > ErrorLld_R"$((rack-14))"_P"$((position+1))".txt
		grep -E "\|Start Arm\|ASPIRATE\|.*\|"$area"\|"$rack"\|"$position"\||\|GenLog\|.*\|1425\|" append.csv | grep -B 1 -E "\|GenLog\|.*\|1425\|REAGENT 2\|$((position+1))\|R$((rack-14))\|" > ErrorLldER1425_R"$((rack-14))"_P"$((position+1))".txt
	fi
fi
