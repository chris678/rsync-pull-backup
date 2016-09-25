#!/bin/bash

#######################################################################
# Title      :    checkLogfile.sh
# Author     :    chris678
# Date       :    2016-08-14
# Requires   :    nothing special
# Category   :    Backup tools
#######################################################################
# Description
#   script checks the log files for errors
# 
#######################################################################
#
# License
#
# The MIT License (MIT)
#
# Copyright (c) 2016 chris678
#
# Permission is hereby granted, free of charge, to any person obtaining a copy of this software and associated documentation files (the "Software"), 
# to deal in the Software without restriction, including  without limitation the rights to use, copy, modify, merge, publish, distribute, sublicense, 
# and/or sell copies of the Software, and to permit persons to whom the Software is furnished to do so, subject  to the following conditions:
#
# The above copyright notice and this permission notice shall be included in all copies or substantial portions of the Software.
#
# THE SOFTWARE IS PROVIDED "AS IS", WITHOUT WARRANTY OF ANY KIND, EXPRESS OR IMPLIED, INCLUDING BUT NOT LIMITED TO THE WARRANTIES OF MERCHANTABILITY, 
# FITNESS FOR A PARTICULAR PURPOSE AND NONINFRINGEMENT.  IN NO EVENT SHALL THE AUTHORS OR COPYRIGHT HOLDERS BE LIABLE FOR ANY CLAIM, DAMAGES OR OTHER LIABILITY, 
# WHETHER IN AN ACTION OF CONTRACT, TORT OR OTHERWISE, ARISING FROM, OUT OF OR IN CONNECTION WITH THE SOFTWARE OR THE USE OR OTHER DEALINGS IN THE SOFTWARE.
#

APPNAME=$(basename $0 | sed "s/\.sh$//")
PID=$$

# -----------------------------------------------------------------------------
# Check input variables
# -----------------------------------------------------------------------------

while getopts "p:d:" opt ; do
	case $opt in
		p) 	BASE_PATH=$OPTARG
		;;
		d) 	LOG_AGE_TO_CHECK=$OPTARG
		;;
	esac
done


if [ "$BASE_PATH" = "" ]; then
	# base path needs to be a parameter because we cannot derive it from any other path
	if [ -f "$HOME/.rsbackup.conf" ]; then
		# read from configuration file
		source $HOME/.rsbackup.conf
	else
		# No parameter --> exit
		echo ""
		echo "Missing parameter." 
		echo "Usage: $APPNAME.sh [-d <log file age to ckeck in days>] [ -p <base path>]"
		echo ""
		echo "Parameters:"
		echo "-d                   - Optional, log file age to ckeck in days, default is 1 day"
		echo "-p <base path>       - base path for backups."
		echo "                       Optional, if <base path> is not omitted and $HOME/.rsbackup.conf exists <base path> will be read from there"
		echo "                       The file $HOME/.rsbackup.conf must contain the line BASE_PATH=<base path>"
		echo ""
		exit 255
	fi
fi

if [ "$LOG_AGE_TO_CHECK" = "" ]; then
	# set to default one day
	LOG_AGE_TO_CHECK=1
fi

if [ ! -d "$BASE_PATH" ]; then
	# base path does not exist
	echo ""
	echo "Base path $BASE_PATH does not exist. Exit"
	echo ""
	exit 2
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
						echo ""
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

