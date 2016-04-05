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


# add request to pipeline
if [ -f "$PIPELINE_PATH/$SESSION" ]; then
	logger "WARNING: Session $SESSION exits already in pipeline $PIPELINE_PATH. Exit"
else
	touch "$PIPELINE_PATH/$SESSION"
	logger "INFO: Session $SESSION added to pipeline $PIPELINE_PATH"
fi

exit 0

