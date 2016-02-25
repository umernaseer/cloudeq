#!/bin/bash
# CentralTimeSyncVersion 
ret=''
function trim {

	trimmed=$1
	trimmed=`echo $trimmed|sed 's/^ *//g' | sed 's/\r*//g' | sed 's/\n*//g' | sed 's/ *$//g'`
	ret=$trimmed

}

echo $1

if [ "$1" == "0" ]; then
	STATE="Boot"
elif [ "$1" == "1" ]; then
	STATE="Reboot"
else
	STATE="Manual"
fi

echo "$STATE: Before Central Time Sync hwclock / date: " `hwclock` " / " `date` >> /eq/hwSyncTimeLog
trim `cat /eq/eq_config.txt | grep TIME_ZONE\= | tr ' ' '+' | cut -d= -f2`
tz=$ret
echo "tz=$tz"
trim `cat /eq/eq_config.txt | grep TIME_ZONE_DAY_LIGHT_SAVING_DISABLE | cut -d= -f2`
dstDisable=$ret
trim `cat /eq/rtc_config.txt | grep -i url | cut -d= -f2`
urlBase=$ret
trim "$urlBase/PgGetTime.aspx?zone=$tz&disableDST=$dstDisable&"
url=$ret
echo "fetching $url"
t1=`date +%s`

wget --tries=3 --timeout=5 -O /tmp/tm.tz $url
if [ ! $? -eq 0 ]; then
	echo  "$STATE: Central Server unresponsive. Aborting central time sync." >> /eq/hwSyncTimeLog
	hwclock --hctosys
	exit 1
fi


t2=`date +%s`

if [ -e /tmp/tm.tz ]
then

	output=`cat /tmp/tm.tz`
	trim `echo $output|cut -d\| -f1`
	stat=$ret

	if [ "$stat" = 'OK' ]
	then
		ret=$((($t2-$t1)/2))
		delay=$ret

		trim `echo $output|cut -d\| -f2`
		year=$ret

		trim `echo $output|cut -d\| -f3`
		mon=$ret

		trim `echo $output|cut -d\| -f4`
		day=$ret

		trim `echo $output|cut -d\| -f5`
		hour=$ret

		trim `echo $output|cut -d\| -f6`
		min=$ret

		trim `echo $output|cut -d\| -f7`
		sec=$ret
		
		date $mon$day$hour$min$year.$sec
		
		trim `date '+%m%d%H%M%Y.%S' --date "now +$delay sec"`
		newDate=$ret
	
		rm /etc/adjtime
		
		date $ret
		
		hwclock --systohc
		
		/eq/system/wsengine_run
		
		echo "$STATE: After Central Time Sync hwclock / date: " `hwclock` " / " `date` >> /eq/hwSyncTimeLog
	else
		echo "$STATE: Incorrect reply from Central Server." `hwclock` " / " `date` >> /eq/hwSyncTimeLog
		hwclock --hctosys
	fi
	rm /tmp/tm.tz

else
	echo "$STATE: No reply from Central Server." `hwclock` " / " `date` >> /eq/hwSyncTimeLog
	hwclock --hctosys
fi



