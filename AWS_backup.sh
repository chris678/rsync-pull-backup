#!/bin/bash

#######################################################################
# Title      :    AWS_backup.sh
# Author     :    chris678
# Date       :    2016-08-14
# Requires   :    - Python 2 version 2.6.5+ or Python 3 version 3.3+
#                 - Pip
#	          - awscli
#                 - ccrypt
#                 - find
#                 - tar
# Category   :    Backup tools
#######################################################################
# Description
#   script for uploading backups to the AWS S3 cloud
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
BACKUP_DATE=$(date "+%Y%m%d_%H%M%S")

# -----------------------------------------------------------------------------
# function usage
# -----------------------------------------------------------------------------

fn_usage() {
	# Missing parameter --> exit
	echo ""
	echo "Missing parameter"
	echo ""
	echo "Usage: $APPNAME.sh -q <queue name> [-p <base path>]"
	echo "-q <queue name> - Queue folder name. A folder relative to <base path>/cloud-queue. The folder contains the request files for" 
	echo "		        the upload to the AWS S3 cloud"
	echo "-p <base path>  - base path for backups"
	echo "                  Optional, if <base path> is not omitted and $HOME/.rsbackup.conf exists <base path> will be read from there"
	echo "                  The file $HOME/.rsbackup.conf must contain the line BASE_PATH=<base path>"
	echo ""
	exit 255
}

# -----------------------------------------------------------------------------
# Check input variables
# -----------------------------------------------------------------------------

while getopts "q:p:" opt ; do
	case $opt in
		q)	QUEUE_NAME="$OPTARG"
		;;
		p) 	BASE_PATH="$OPTARG"
		;;
	esac
done

if [ "$QUEUE_NAME" = "" ]; then 
	fn_usage
fi

if [ "$BASE_PATH" = "") ]; then
	if [ -f "$HOME/.rsbackup.conf" ]; then
		# read from configuration file
		source $HOME/.rsbackup.conf
	else
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

# -----------------------------------------------------------------------------
# set base path variables
# -----------------------------------------------------------------------------

CLOUD_QUEUE_PATH=$BASE_PATH/cloud-queue/$QUEUE_NAME
CLOUD_BACKUPS_ROOT=$BASE_PATH/cloud-backups
LOG_PATH=$BASE_PATH/log
CONF_PATH=$BASE_PATH/conf

if [ ! -d "$LOG_PATH" ]; then
	mkdir -p "$LOG_PATH"
fi

# -----------------------------------------------------------------------------
# Mostly needed
# -----------------------------------------------------------------------------

logger() {
	echo "$(date '+%D %T') $APPNAME[$PID]: $1" >> $LOG
}

app_logger() {
	echo "$(date '+%D %T') $APPNAME[$PID]: $1" >> "$LOG_PATH/$APPNAME.log"
}

# -----------------------------------------------------------------------------
# exit in case the no-run file has been set
# -----------------------------------------------------------------------------

if [ -f "$CONF_PATH/AWS.stop" ]; then
	app_logger "ERROR: Lock file $CONF_PATH/AWS.stop has been found. Terminating without actions"
	exit 1
fi

# -----------------------------------------------------------------------------
# create queue is not existing
# -----------------------------------------------------------------------------

if [ ! -d "$CLOUD_QUEUE_PATH" ]; then
	# create QUEUE_NAME if not existing yet
	mkdir -p $CLOUD_QUEUE_PATH

	# we can exit because there cannot be anything waiting
	exit 0
fi

# -----------------------------------------------------------------------------
# Make sure everything really stops when CTRL+C is pressed
# -----------------------------------------------------------------------------

fn_terminate_script() {
	app_logger "ERROR: SIGINT caught. Terminating"
	exit 1
}

trap 'fn_terminate_script' SIGINT

# -----------------------------------------------------------------------------
# Get parameters from file
# -----------------------------------------------------------------------------

fn_get_parameters() {
	# set defaults
	AWS_ACCESS_KEY_ID=
	AWS_SECRET_ACCESS_KEY=
	AWS_DEFAULT_REGION=
	AWS_BUCKET=
	LOCAL_BACKUP_SUB_PATH=
	TAR_EXCLUDE=
	CCRYPT_ENC_KEY=
	MAX_GENERATIONS=5
	FILE_AGE=120

	while read line; do
		read _PARAMETER _VALUE <<< $(IFS="="; echo $line)
		
		# set PARAMETER to upper case to make live easier
		PARAMETER=$(echo $_PARAMETER | tr 'a-z' 'A-Z')

		case $PARAMETER in
		AWS_ACCESS_KEY_ID)		AWS_ACCESS_KEY_ID=$_VALUE
						;;
		AWS_SECRET_ACCESS_KEY)		AWS_SECRET_ACCESS_KEY=$_VALUE
						;;
		AWS_DEFAULT_REGION)		AWS_DEFAULT_REGION=$_VALUE
						;;
		AWS_BUCKET)			AWS_BUCKET=$_VALUE
						;;
		LOCAL_BACKUP_SUB_PATH)		LOCAL_BACKUP_SUB_PATH=$_VALUE
						;;
		TAR_EXCLUDE)			TAR_EXCLUDE=$_VALUE
						;;
		CCRYPT_ENC_KEY)			CCRYPT_ENC_KEY=$_VALUE
						;;
		MAX_GENERATIONS)		MAX_GENERATIONS=$_VALUE
						;;
		FILE_AGE)			FILE_AGE=$_VALUE
						;;
		esac
	done < $CONF_PATH/$SESSION

	# now we know everything we need to complete the BACKUP_BASE_PATH
	CLOUD_BACKUPS=$CLOUD_BACKUPS_ROOT/$AWS_BUCKET
	CLOUD_BACKUPS_WRK="$CLOUD_BACKUPS/wrk"
	CLOUD_BACKUPS_SYNC="$CLOUD_BACKUPS/sync"

	# check the existance of the base folders
	if [ ! -d "$CLOUD_BACKUPS_WRK" ]; then
		mkdir -p "$CLOUD_BACKUPS_WRK"
		chmod 755 "$CLOUD_BACKUPS_WRK"
	fi

	if [ ! -d "$CLOUD_BACKUPS_SYNC" ]; then
		mkdir -p "$CLOUD_BACKUPS_SYNC"
		chmod 755 "$CLOUD_BACKUPS_SYNC"
	fi

	# get the backup path from the SESSION
	while read line; do
		read _PARAMETER _VALUE <<< $(IFS="="; echo $line)
		
		# set PARAMETER to upper case to make live easier
		PARAMETER=$(echo $_PARAMETER | tr 'a-z' 'A-Z')

		case $PARAMETER in
		BACKUP_PATH)			BACKUP_PATH=$_VALUE
	 					;;
		esac
	done < $CLOUD_QUEUE_PATH/$SESSION
}

# -----------------------------------------------------------------------------
# Remove older backups
# -----------------------------------------------------------------------------

fn_expireBackup() {
	# in case of 0 never delete old archives
	if [ "$MAX_GENERATIONS" != "0" ]; then
		# calculate how many files need to be removed	
		(( TO_DELETE=$(ls $CLOUD_BACKUPS_SYNC/*$SESSION* | wc -w)-(MAX_GENERATIONS*SUB_ARCHIVE_COUNT) ))

		if [ $TO_DELETE -gt 0 ]; then
			# oldest backups need to be deleted
			for line in $(ls -dtr $CLOUD_BACKUPS_SYNC/*$SESSION* | head -$TO_DELETE); do
				# remove file
				rm -f "$line"
				logger "INFO: Old backup $line removed"
	
				# remove the old log file also (if exists)
				read DATE_TIME  <<< $(echo $(basename "$line" ) | cut -d '-' -f 1)
				OLD_LOG_FILE="$LOG_PATH/$APPNAME-"$SESSION"_"$DATE_TIME".log"
				if [ -f "$OLD_LOG_FILE" ]; then
					rm -f "$OLD_LOG_FILE"
				fi
			done
		fi
	fi
}

# -----------------------------------------------------------------------------
# set TAR options
# -----------------------------------------------------------------------------

fn_set_TAR_CMD_options() {
	# determine the excludes
	CMD_TAR_EXCLUDE=""
	IFS=':' read -r -a EXCLUDE_ARRAY <<< "$TAR_EXCLUDE"

	for element in "${EXCLUDE_ARRAY[@]}"
	do
	    CMD_TAR_EXCLUDE="$CMD_TAR_EXCLUDE --exclude=$element"
	done
}

# -----------------------------------------------------------------------------
# set FIND options
# -----------------------------------------------------------------------------

fn_set_FIND_options() {
	FIND_CMD_OPTIONS=""

	if [[ "$FILE_AGE" != "0" && "$FILE_AGE" != "" ]]; then
		FIND_CMD_OPTIONS="-mtime -$FILE_AGE"
	fi
}

# -----------------------------------------------------------------------------
# process find and tar
# -----------------------------------------------------------------------------

fn_process_find_and_tar() {
	# change to source dir
	cd $BACKUP_PATH

	# start compression friendly
	if [[ "$FILE_AGE" = "0" && "$FILE_AGE" = "" ]]; then
		find * -type f -print0 | tar cf $BACKUP_TAR_FILE --null --files-from - $CMD_TAR_EXCLUDE && gzip $BACKUP_TAR_FILE
	else
		find * -type f -mtime -"$FILE_AGE" -print0 | tar cf $BACKUP_TAR_FILE --null --files-from - $CMD_TAR_EXCLUDE && gzip $BACKUP_TAR_FILE
	fi

	RET=$?

	if [ "$RET" = "0" ];then
		# check for encryption
		if [ ! "$CCRYPT_ENC_KEY" = "" ]; then
			export CCRYPT_ENC_KEY=$CCRYPT_ENC_KEY
			nice ccrypt -e -E CCRYPT_ENC_KEY $BACKUP_TAR_FILE.gz
			RET=$?
			export CCRYPT_ENC_KEY=
			
			if [ "$RET" = "0" ]; then
				#  move file to sync folder
				mv -f $BACKUP_TAR_FILE* "$CLOUD_BACKUPS_SYNC/"
			else
				logger "ERROR: Return code from ccrypt: $RET. Encryption failed! File $BACKUP_TAR_FILE. Check $CLOUD_BACKUPS_WRK for dead files"
			fi
		else
			#  move file to sync folder
			mv -f "$BACKUP_TAR_FILE*" "$CLOUD_BACKUPS_SYNC/"
		fi
	fi
	
	return $RET
}

# -----------------------------------------------------------------------------
# main process find and tar
# -----------------------------------------------------------------------------

fn_prepare_find_and_tar() {
	BACKUP_BASE_NAME="$BACKUP_DATE-$SESSION"
	BACKUP_BASE_PATH="$BACKUP_PATH"

	if [ "$LOCAL_BACKUP_SUB_PATH" = "" ]; then
		# set destination file name
		BACKUP_NAME=$BACKUP_BASE_NAME
		BACKUP_TAR_FILE="$CLOUD_BACKUPS_WRK/$BACKUP_NAME.tar"
		# set the sub archive count (needed later for fn_expireBackup)
		SUB_ARCHIVE_COUNT=1

		# call find and tar
		fn_process_find_and_tar
		RET=$?

		logger "INFO: Cloud backup file name created: $BACKUP_NAME"
	else
		# determine the sub archives
		IFS=':' read -r -a SUB_ARCHIVES_ARRAY <<< "$LOCAL_BACKUP_SUB_PATH"

		# save the sub archive count (needed later for fn_expireBackup)
		SUB_ARCHIVE_COUNT="${#SUB_ARCHIVES_ARRAY[*]}"

		for element in "${SUB_ARCHIVES_ARRAY[@]}"
		do
			read SUB_ARCHIVE_NAME SUB_ARCHIVE_PATH dummy <<< $(IFS="="; echo $element)
			# set destination file name
			BACKUP_NAME="$BACKUP_BASE_NAME_$SUB_ARCHIVE_NAME"
			BACKUP_TAR_FILE="$CLOUD_BACKUPS_WRK/$BACKUP_NAME.tar"
			BACKUP_PATH="$BACKUP_BASE_PATH/$SUB_ARCHIVE_PATH"

			# call find and tar for each sub session
			fn_process_find_and_tar
			RET=$?

			logger "INFO: Cloud backup file name created: $BACKUP_NAME"
		done
	fi

	if [ "$RET" = "0" ]; then
		# success until now. Cleanup old backups
		fn_expireBackup
	fi
}

# -----------------------------------------------------------------------------
# start cloud backup for SESSION
# -----------------------------------------------------------------------------

fn_execute_cloud_sync() {
	# set options for tar
	fn_set_TAR_CMD_options
	# set options for find
	fn_set_FIND_options

	# start the backup
	logger "INFO: Start CLOUD backup. Session: $SESSION, queue base path $BASE_PATH"
	logger "INFO: tar exclude list: $CMD_TAR_EXCLUDE. find options: $FIND_CMD_OPTIONS"

	# prepare the upload (execute find, tar and optional encryption
	fn_prepare_find_and_tar
	RET=$?

	if [ "$RET" = "0" ];then
		# whatever has happend $RET contains a return value
		# start sync process
		export AWS_ACCESS_KEY_ID=$AWS_ACCESS_KEY_ID
		export AWS_SECRET_ACCESS_KEY=$AWS_SECRET_ACCESS_KEY
		export AWS_DEFAULT_REGION=$AWS_DEFAULT_REGION
		logger "INFO: Cloud sync starts"
		nice aws s3 sync "$CLOUD_BACKUPS_SYNC" s3://"$AWS_BUCKET" --delete >> $LOG
		RET=$?

		if [ "$RET" = "0" ]; then
			logger "INFO: Cloud backup finished with success"
		else
			logger "ERROR: Cloud backup finished with error code $RET"
		fi
	else
		logger "ERROR: $APPNAME failed on $SESSION. Backup path: $BACKUP_PATH"
		RET=1
	fi 

	return $RET
}

# -----------------------------------------------------------------------------
# main program
# -----------------------------------------------------------------------------

# Check if script is already running to avoid high system load/conflicts
if [ "$(pidof -x $(basename $0))" = "$PID" ]; then
	# script is not running twice, continue

	for _file in $(ls -tr $CLOUD_QUEUE_PATH); do
		SESSION=$_file

		# set the log file name
		LOG="$LOG_PATH"/"$APPNAME"-"$SESSION"_$BACKUP_DATE.log

		# check existance of conf file
		if [ ! -f "$CONF_PATH/$SESSION" ]; then
			app_logger "ERROR: $CONF_PATH/$SESSION does not exist. Skip"
		else
			# get parameters for cloud sync task
			fn_get_parameters

			# start cloud sync for _file
			fn_execute_cloud_sync
			RET=$?

			if [ "$RET" != "0" ]; then
				# try execution next loop again
				continue
			fi
		fi

		# we are done for this file and can remove the request from the queue
		rm -f $CLOUD_QUEUE_PATH/$_file
	done
fi

# exit always 0 
exit 0

