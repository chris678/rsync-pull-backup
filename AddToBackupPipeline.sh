#!/bin/bash
#
# scripts adds new requests to execution pipeline
#

APPNAME=$(basename $0)
PID=$$

# -----------------------------------------------------------------------------
# Check input variables
# -----------------------------------------------------------------------------

SESSION=$1
BASE_PATH=$2

if [[ "$SESSION" = "" || "$BASE_PATH" = "" ]]; then
	# Missing parameter --> exit
	echo ""
	echo "Missing parameter. Usage: $APPNAME.sh <conf file name without extension> <base path>"
	echo "Example: $APPNAME.sh <EXAMPLE> <path for backups>"
	echo "Example for request list: $APPNAME.sh <EXAMPLE=filename> <path for backups>"
	echo "For request lists EXAMPLE can be any descriptive name WITHOUT spaces"
	echo ""
	exit 255
fi

PIPELINE_PATH=$BASE_PATH/pipeline
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
	if [ -f "$PIPELINE_PATH/$SESSION" ]; then
		logger "WARNING: Session $SESSION exits already in queue $PIPELINE_PATH. Exit"
	else
		touch "$PIPELINE_PATH/$SESSION"
		logger "INFO: Session $SESSION added to queue $PIPELINE_PATH"
	fi
}

# -----------------------------------------------------------------------------
# main program
# -----------------------------------------------------------------------------

if [ ! -d "$PIPELINE_PATH" ]; then
	# create PIPELINE if not existing yet
	mkdir -p $PIPELINE_PATH
fi

if [ ! -d "$LOG_PATH" ]; then
	# create LOG path if not existing yet
	mkdir -p $LOG_PATH
fi

# -----------------------------------------------------------------------------
# check if backup request is a file with multiple requests
# -----------------------------------------------------------------------------

read _SESSION _FILE <<< $(IFS="="; echo $SESSION)


if [ "$_FILE" != "" ]; then
	if [ -f "$_FILE" ]; then
		while read line; do
			if [[ "${line:0:1}" != "#" || "${line:0:1}" != "" ]]; then
				# no comment and not an empty line
				SESSION=$_SESSION

				fn_add_request_to_queue
			fi
		done < $BASE_PATH/conf/$_FILE
	else
		logger "ERROR: File $BASE_PATH/conf/$_FILE.request does not exist --> exit"
	fi
else
	fn_add_request_to_queue
fi

exit 0
