#!/bin/bash
#1427 regrex pattern
grep -E "\|Reagent Arm\|Clean Step - Start\|.*\|7\|0\|0\||\|Reagent Arm\|AspLldCheck\|" append.csv | grep -A 1 -E "\|Clean Step - Start\|" > CleanCupR1.csv
grep -E "\|Start Arm\|Clean Step - Start\|.*\|7\|0\|0\||\|Start Arm\|AspLldCheck\|" append.csv | grep -A 1 -E "\|Clean Step - Start\|" > CleanCupR2.csv
