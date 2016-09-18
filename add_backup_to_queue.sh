#!/bin/bash

#######################################################################
# Title      :    add_backup_to_queue.sh
# Author     :    chris678
# Date       :    2016-08-14
# Requires   :    nothing special
# Category   :    Backup tools
#######################################################################
# Description
#   scripts adds new requests to execution QUEUE
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

APPNAME=$(basename $0)
PID=$$

# -----------------------------------------------------------------------------
# function usage
# -----------------------------------------------------------------------------

fn_usage() {
	# Missing parameter --> exit
	echo ""
	echo "Missing parameter"
	echo ""
	echo " Usage: $APPNAME -s <conf file>|-l <list file name> [-p <base path>]"
	echo ""
	echo "-s <conf file name>  - Process a dedicated session from <base path>/conf"
	echo "-l <list file name>  - Read list of sessions from <base path>/conf/<list file name>"
	echo "-p <base path>       - base path for backups."
	echo "                       Optional, if <base path> is not omitted and $HOME/.rsbackup.conf exists <base path> will be read from there"
	echo "                       The file $HOME/.rsbackup.conf must contain the line BASE_PATH=<base path>"
	echo ""
	exit 255
}

# -----------------------------------------------------------------------------
# Check input variables
# -----------------------------------------------------------------------------

while getopts "s:p:l:" opt ; do
	case $opt in
		s)	SESSION="$OPTARG"
		;;
		p) 	BASE_PATH="$OPTARG"
		;;
		l) 	SESSION_FILE_LIST="$OPTARG"
		;;
	esac
done

if [[ "$SESSION" = "" && "$SESSION_FILE_LIST" = "" ]]; then
	# Missing parameter --> exit
	fn_usage
fi

if [ "$BASE_PATH" = "" ]; then
	if [ -f "$HOME/.rsbackup.conf" ]; then
		# read from configuration file if exists
		source $HOME/.rsbackup.conf
	else
		# Missing parameter --> exit
		fn_usage
	fi
fi

if [ ! -d "$BASE_PATH" ]; then
	# base path does not exist
	echo ""
	echo "Base path $BASE_PATH does not exist. Exit"
	echo ""
	exit 2
fi

QUEUE_PATH=$BASE_PATH/backup-queue
CONF_PATH=$BASE_PATH/conf
LOG_PATH=$BASE_PATH/log
LOG=$LOG_PATH/$(basename $0 | sed "s/\.sh$//").log

# -----------------------------------------------------------------------------
# Mostly needed
# -----------------------------------------------------------------------------

logger() {
	echo "$(date '+%D %T') $APPNAME[$PID]: $1" >> $LOG
}

# -----------------------------------------------------------------------------
# Add backup request to queue
# -----------------------------------------------------------------------------

fn_add_request_to_queue() {
	# add request to queue
	if [ -f "$CONF_PATH/$SESSION" ]; then
		if [ -f "$QUEUE_PATH/$SESSION" ]; then
			logger "WARNING: Session $SESSION exits already in queue $QUEUE_PATH. Exit"
		else
			touch "$QUEUE_PATH/$SESSION"
			logger "INFO: Session $SESSION added to queue $QUEUE_PATH"
		fi
	else
		logger "WARNING: $CONF_PATH/$SESSION does not exist. Request not added to $QUEUE_PATH"
	fi
}

# -----------------------------------------------------------------------------
# main program
# -----------------------------------------------------------------------------

if [ ! -d "$QUEUE_PATH" ]; then
	# create QUEUE if not existing yet
	mkdir -p $QUEUE_PATH
fi

if [ ! -d "$LOG_PATH" ]; then
	# create LOG path if not existing yet
	mkdir -p $LOG_PATH
fi

if [ ! -d "$CONF_PATH" ]; then
	# create CONF path if not existing yet
	mkdir -p $CONF_PATH

	# we can exit now. if the folder didn't exist the files also cannot exist
	logger "INFO: Path for sessions $CONF_PATH did not exist and has been created. $APPNAME terminated"
	exit 0
fi

# -----------------------------------------------------------------------------
# check if backup request is a file with multiple requests
# -----------------------------------------------------------------------------

if [ "$SESSION_FILE_LIST" != "" ]; then
	if [ -f "$BASE_PATH/conf/$SESSION_FILE_LIST" ]; then
		while read line; do
			if [[ "${line:0:1}" != "#" && "${line:0:1}" != "" ]]; then
				# no comment and not an empty line
				SESSION=$line

				fn_add_request_to_queue
			fi
		done < $BASE_PATH/conf/$SESSION_FILE_LIST
	else
		logger "ERROR: File $BASE_PATH/conf/$SESSION_FILE_LIST does not exist --> exit"
	fi
else
	fn_add_request_to_queue
fi

exit 0

