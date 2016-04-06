#!/bin/bash
#
# script checks the log files for errors
#

APPNAME=$(basename $0 | sed "s/\.sh$//")
PID=$$

# -----------------------------------------------------------------------------
# Check input variables
# -----------------------------------------------------------------------------

# base path needs to be a parameter because we cannot derive it from any other path
BASE_PATH=$1
LOG_AGE_TO_CHECK=$2

if [ "$BASE_PATH" = "" ]; then
	# No parameter --> exit
	echo ""
	echo "Missing parameter. Usage: $APPNAME.sh <base path> [<log file age to ckeck in days, default is 1 day>]"
	echo ""
	exit 255
fi

if [ "$LOG_AGE_TO_CHECK" = "" ]; then
	# set to default one day
	LOG_AGE_TO_CHECK=1
fi

# -----------------------------------------------------------------------------
# set base path variables
# -----------------------------------------------------------------------------

LOG_PATH=$BASE_PATH/log
LOG=$BASE_PATH/log/$APPNAME.log

# -----------------------------------------------------------------------------
# Mostly needed
# -----------------------------------------------------------------------------

logger() {
	echo "$(date '+%D %T') $APPNAME[$PID]: $1" >> $LOG

}

# -----------------------------------------------------------------------------
# Make sure everything really stops when CTRL+C is pressed
# -----------------------------------------------------------------------------

fn_terminate_script() {
	echo "ERROR: SIGINT caught. Terminating"
	exit 1
}

trap 'fn_terminate_script' SIGINT

# -----------------------------------------------------------------------------
# Check log files
# -----------------------------------------------------------------------------

fn_checkLog() {
	# get date normalized to begin of the day (fileDate below is normalized the same way)
	dateToday=$(date -d $(date '+%Y%m%d') '+%s')

	# calculate the dead line (one day has 86400 seconds)
	(( CompareDate=$dateToday-$LOG_AGE_TO_CHECK*86400 ))

	for line in $(ls -t -d "$LOG_PATH"/*); do
		# determine if $line is a file (directories and sym links are out of scope)
		if [ "$(file -bi $line | cut -d ';' -f 1)" = "text/plain" ]; then
			# we have a file (now we know for sure). Take the age.
			fileDate=$(date --date $(ls --full-time -d "$line" | cut -d ' ' -f 6 | tr -d '-') '+%s')
		
			if [ $fileDate -ge $CompareDate ]; then
				# file is in scope

				if [ "$line" != "$LOG" ]; then
					# the APPNAME log file should not be checked

					# collect all errors from log file for further processing 
					ERROR=$(grep "ERROR" "$line")

					if [ "$ERROR" != "" ]; then
						echo "Errors found in $line : $ERROR"
#						echo "$ERROR"
					fi
				fi
			fi
		fi
	done

	return
}

# -----------------------------------------------------------------------------
# main program
# -----------------------------------------------------------------------------

fn_checkLog

exit 0

