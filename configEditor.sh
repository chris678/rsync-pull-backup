#!/bin/bash

#######################################################################
# Title      :    configEditor.sh
# Author     :    chris678
# Date       :    2016-08-14
# Requires   :    dialog
# Category   :    Shell menu tools
#######################################################################
# Description
#   edit configuration scripts for rsync pull backup
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
TEMP_FILE=/tmp/$APPNAME.$PID
DIALOG_BACK_TITLE="rsync pull backup"

# -----------------------------------------------------------------------------
# function usage
# -----------------------------------------------------------------------------

fn_usage() {
	# Missing parameter --> EXIT
	echo ""
	echo "Missing parameter. Usage $APPNAME <base path>"
	echo ""
	echo "If <base path> is empty and $HOME/.rsbackup.conf exists <base path> will be read from there"
	echo ""
	exit 255
}

# -----------------------------------------------------------------------------
# Check input variables
# -----------------------------------------------------------------------------

BASE_PATH=$1

if [ "$BASE_PATH" = "" ]; then
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

LOG_PATH="$BASE_PATH"/log
LOG="$LOG_PATH"/$(basename $0 | sed "s/\.sh$//").log
CONF_PATH="$BASE_PATH"/conf

# -----------------------------------------------------------------------------
# Check most important directories
# -----------------------------------------------------------------------------

if [ ! -d "$LOG_PATH" ]; then
	mkdir "$LOG_PATH"
	chown --reference "$BASE_PATH" "$LOG_PATH"
fi

if [ ! -d "$CONF_PATH" ]; then
	mkdir "$CONF_PATH"
	chown --reference "$BASE_PATH" "$CONF_PATH"
fi

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
	# clean up tmp folder and exit
	rm -f $TEMP_FILE*
	clear
	exit 0
}

trap 'fn_terminate_script' SIGINT

# -----------------------------------------------------------------------------
# Function select a file
# -----------------------------------------------------------------------------

fn_select_file() {
	TITLE=$1
	FILE_PATH=$2

	while true; do
		dialog --clear --backtitle "$DIALOG_BACK_TITLE - $MENU_CHOICE" --title "$TITLE - select file with [space]" \
			--fselect "$FILE_PATH" 20 70 2> $TEMP_FILE
		RET=$?

		# Stop on Cancel
		if [ $RET != 0 ]; then 
			rm -f $TEMP_FILE
			return 1
		else
			choice=$(cat $TEMP_FILE && rm -f $TEMP_FILE)

			if [ ! -f "$choice" ]; then
				FILE_PATH=$choice
				dialog --clear --backtitle "$DIALOG_BACK_TITLE - $MENU_CHOICE" \
					--title "Error: Not a file" \
					--msgbox "\n$choice is not a file" 9 52
			else
				CURRENT_FILE="$choice"
				return 0
			fi
		fi
	done
}

# -----------------------------------------------------------------------------
# Function edit a file
# -----------------------------------------------------------------------------

fn_edit_file() {
	dialog --clear --backtitle "$DIALOG_BACK_TITLE - $MENU_CHOICE" \
		--title "Edit $CURRENT_FILE" \
		--ok-label "Save" \
		--editbox "$CURRENT_FILE" 0 0 2> $TEMP_FILE
	RET=$?

	# clean up on Cancel
	if [ $RET != 0 ]; then 
		rm -f $TEMP_FILE 
	else
		# move the changed file to current file
		mv -f $TEMP_FILE "$CURRENT_FILE"
		chown --reference "$BASE_PATH" "$CURRENT_FILE_SIK"
	fi

	# clear variable again
	CURRENT_FILE=""

	return $RET
}

# -----------------------------------------------------------------------------
# Function create new file
# -----------------------------------------------------------------------------

fn_create_new_file() {
	dialog --backtitle "$DIALOG_BACK_TITLE - $MENU_CHOICE" --clear \
		--inputbox "Enter file name" 8 52 2> $TEMP_FILE
	RET=$?

	if [ $RET != 0 ]; then
		rm -f $TEMP_FILE
	else
		NEW_FILE=$(cat $TEMP_FILE && rm -f $TEMP_FILE)		
		if [ -f "$CONF_PATH/$NEW_FILE" ]; then
			dialog --backtitle "$DIALOG_BACK_TITLE - $MENU_CHOICE" --clear \
				--msgbox "\nFile already exists:\n$NEW_FILE" 9 52
			RET=1
		else
			CURRENT_FILE="$CONF_PATH/$NEW_FILE"
		fi
	fi

	return $RET
}

# -----------------------------------------------------------------------------
# Function read configuration configuration file
# -----------------------------------------------------------------------------

fn_read_rsync_config_file() {
	# Set all values to default
	REMOTE_SSH_PORT=""
	SOURCE_RSYNC_USER=""
	SOURCE_SSH_USER=""
	SOURCE_SSH_SERVER=""
	SOURCE_FOLDER=""
	SOURCE_EXCLUDE_FILE=""
	BACKUP_BASE_PATH=""
	BACKUP_MIN_COUNT=""
	BACKUP_MIN_AGE=""
	STRICT_SSH=""
	PERMISSIONS=""
	PRIVATE_KEY_FILE=""
	CLOUD_ARCHIVE_QUEUE=""
	CLOUD_ARCHIVE_REQUEST_FILE=""

	while read line; do
		read _PARAMETER _VALUE <<< $(IFS="="; echo $line)
		
		# set PARAMETER to upper case to make live easier
		PARAMETER=$(echo $_PARAMETER | tr 'a-z' 'A-Z')

		case $PARAMETER in
		REMOTE_SSH_PORT) 		REMOTE_SSH_PORT=$_VALUE
						;;
		SOURCE_RSYNC_USER)		SOURCE_RSYNC_USER=$_VALUE
						;;
		SOURCE_SSH_USER)		SOURCE_SSH_USER=$_VALUE
						;;
		SOURCE_SSH_SERVER)		SOURCE_SSH_SERVER=$_VALUE
						;;
		SOURCE_FOLDER)			SOURCE_FOLDER=$_VALUE
						;;
		SOURCE_EXCLUDE_FILE)		SOURCE_EXCLUDE_FILE=$_VALUE
						;;
		BACKUP_BASE_PATH)		BACKUP_BASE_PATH=$_VALUE
						;;
		BACKUP_MIN_COUNT)		BACKUP_MIN_COUNT=$_VALUE
						;;
		BACKUP_MIN_AGE)			BACKUP_MIN_AGE=$_VALUE
						;;
		STRICT_SSH)			STRICT_SSH=$_VALUE
						;;
		PERMISSIONS)			PERMISSIONS=$_VALUE
						;;
		PRIVATE_KEY_FILE)		PRIVATE_KEY_FILE=$_VALUE
						;;
		CLOUD_ARCHIVE_QUEUE)        	CLOUD_ARCHIVE_QUEUE=$_VALUE
						;;
		CLOUD_ARCHIVE_REQUEST_FILE)	CLOUD_ARCHIVE_REQUEST_FILE=$_VALUE
						;;
		esac
	done < $CURRENT_FILE
}

fn_read_aws_config_file() {
	# Set all values to default
	AWS_ACCESS_KEY_ID=""
	AWS_SECRET_ACCESS_KEY=""
	AWS_DEFAULT_REGION=""
	AWS_BUCKET=""
	LOCAL_BACKUP_SUB_PATH=""
	TAR_EXCLUDE=""
	MAX_GENERATIONS=""
	FILE_AGE=""
	CCRYPT_ENC_KEY=""

	while read line; do
		read _PARAMETER _VALUE <<< $(IFS="="; echo $line)
		
		# set PARAMETER to upper case to make live easier
		PARAMETER=$(echo $_PARAMETER | tr 'a-z' 'A-Z')

		case $PARAMETER in
		AWS_ACCESS_KEY_ID) 		AWS_ACCESS_KEY_ID=$_VALUE
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
		MAX_GENERATIONS)		MAX_GENERATIONS=$_VALUE
						;;
		FILE_AGE)			FILE_AGE=$_VALUE
						;;
		CCRYPT_ENC_KEY)			CCRYPT_ENC_KEY=$_VALUE
						;;
		esac
	done < $CURRENT_FILE
}

# -----------------------------------------------------------------------------
# Function read variables into corresponding vars
# -----------------------------------------------------------------------------

fn_read_base_1_config_into_vars() {
	TEMP_CHANGED_FILE="$TEMP_FILE"_$(basename "$CURRENT_FILE")
	COUNTER=1
	
	echo "# Start base config 1" > "$TEMP_CHANGED_FILE"

	while read line; do
		prefix=""

		if [ "$line" = "" ]; then prefix="#"; fi

		case $COUNTER in
			2)	echo "$prefix""SOURCE_SSH_SERVER=$line" >> "$TEMP_CHANGED_FILE"
				;;
			4)	echo "$prefix""SOURCE_RSYNC_USER=$line" >> "$TEMP_CHANGED_FILE"
				;;
			6)	echo "$prefix""SOURCE_SSH_USER=$line" >> "$TEMP_CHANGED_FILE"
				;;
			9)	echo "$prefix""SOURCE_FOLDER=$line" >> "$TEMP_CHANGED_FILE"
				;;
			12)	echo "$prefix""BACKUP_BASE_PATH=$line" >> "$TEMP_CHANGED_FILE"
				;;
			15)	echo "$prefix""SOURCE_EXCLUDE_FILE=$line" >> "$TEMP_CHANGED_FILE"
				;;
		esac

		let COUNTER+=1
	done < "$TEMP_FILE"

	echo "# End base config 1" >> "$TEMP_CHANGED_FILE"
	echo "" >> "$TEMP_CHANGED_FILE"
}

fn_read_base_2_config_into_vars() {
	COUNTER=1
	
	echo "# Start base config 2" >> "$TEMP_CHANGED_FILE"

	while read line; do
		prefix=""

		if [ "$line" = "" ]; then prefix="#"; fi

		case $COUNTER in
			3)	echo "$prefix""BACKUP_MIN_COUNT=$line" >> "$TEMP_CHANGED_FILE"
				;;
			7)	echo "$prefix""BACKUP_MIN_AGE=$line" >> "$TEMP_CHANGED_FILE"
				;;
			12)	echo "$prefix""PERMISSIONS=$line" >> "$TEMP_CHANGED_FILE"
				;;
			14)	echo "$prefix""CLOUD_ARCHIVE_QUEUE=$line" >> "$TEMP_CHANGED_FILE"
				;;
			16)	echo "$prefix""CLOUD_ARCHIVE_REQUEST_FILE=$line" >> "$TEMP_CHANGED_FILE"
				;;
		esac

		let COUNTER+=1
	done < "$TEMP_FILE"

	echo "# End base config 2" >> "$TEMP_CHANGED_FILE"
	echo "" >> "$TEMP_CHANGED_FILE"
}

fn_read_ssh_config_into_vars() {
	COUNTER=1
	
	echo "# Start ssh config " >> "$TEMP_CHANGED_FILE"

	while read line; do
		prefix=""

		if [ "$line" = "" ]; then prefix="#"; fi

		case $COUNTER in
			3)	echo "$prefix""REMOTE_SSH_PORT=$line" >> "$TEMP_CHANGED_FILE"
				;;
			6)	echo "$prefix""STRICT_SSH=$line" >> "$TEMP_CHANGED_FILE"
				;;
			9)	echo "$prefix""PRIVATE_KEY_FILE=$line" >> "$TEMP_CHANGED_FILE"
				;;
		esac

		let COUNTER+=1
	done < "$TEMP_FILE"

	echo "# End ssh config" >> "$TEMP_CHANGED_FILE"
	echo "" >> "$TEMP_CHANGED_FILE"
}

fn_read_AWS_S3_config_into_vars() {
	TEMP_CHANGED_FILE="$TEMP_FILE"_$(basename "$CURRENT_FILE")
	COUNTER=1
	
	echo "# AWS S3 parameters" > "$TEMP_CHANGED_FILE"

	while read line; do
		prefix=""

		if [ "$line" = "" ]; then prefix="#"; fi

		case $COUNTER in
			1)	echo "$prefix""AWS_ACCESS_KEY_ID=$line" >> "$TEMP_CHANGED_FILE"
				;;
			2)	echo "$prefix""AWS_SECRET_ACCESS_KEY=$line" >> "$TEMP_CHANGED_FILE"
				;;
			3)	echo "$prefix""AWS_DEFAULT_REGION=$line" >> "$TEMP_CHANGED_FILE"
				;;
			4)	echo "$prefix""AWS_BUCKET=$line" >> "$TEMP_CHANGED_FILE"
				;;
		esac

		let COUNTER+=1
	done < "$TEMP_FILE"

	echo "# AWS S3 parameters" >> "$TEMP_CHANGED_FILE"
	echo "" >> "$TEMP_CHANGED_FILE"
}

fn_read_AWS_local_config_into_vars() {
	COUNTER=1
	
	echo "# AWS local configuration" >> "$TEMP_CHANGED_FILE"

	while read line; do
		prefix=""

		if [ "$line" = "" ]; then prefix="#"; fi

		case $COUNTER in
			5)	echo "$prefix""LOCAL_BACKUP_SUB_PATH=$line" >> "$TEMP_CHANGED_FILE"
				;;
			9)	echo "$prefix""TAR_EXCLUDE=$line" >> "$TEMP_CHANGED_FILE"
				;;
			12)	echo "$prefix""MAX_GENERATIONS=$line" >> "$TEMP_CHANGED_FILE"
				;;
			16)	echo "$prefix""FILE_AGE=$line" >> "$TEMP_CHANGED_FILE"
				;;
		esac

		let COUNTER+=1
	done < "$TEMP_FILE"

	echo "# AWS local configuration" >> "$TEMP_CHANGED_FILE"
	echo "" >> "$TEMP_CHANGED_FILE"
}

fn_read_AWS_encryption_into_vars() {
	COUNTER=1
	
	echo "# AWS encyprtion configuration" >> "$TEMP_CHANGED_FILE"

	while read line; do
		prefix=""

		if [ "$line" = "" ]; then prefix="#"; fi

		case $COUNTER in
			5)	echo "$prefix""CCRYPT_ENC_KEY=$line" >> "$TEMP_CHANGED_FILE"
				;;
		esac

		let COUNTER+=1
	done < "$TEMP_FILE"

	echo "# AWS encryption configuration" >> "$TEMP_CHANGED_FILE"
}

# -----------------------------------------------------------------------------
# Function dialog rsync configuration file
# -----------------------------------------------------------------------------

fn_rsync_config_dialog() {
	dialog --backtitle "$DIALOG_BACK_TITLE - $MENU_CHOICE: $CURRENT_FILE" --clear --ok-label "Save changes" --mixedform \
	" Base config (1/2)- use [up] [down] to select input field " 30 80 22 \
		"Remote computer (client/source for backup)" 2 4 "" 2 70 1 0 2 \
		"SOURCE_SSH_SERVER" 3 4 "$SOURCE_SSH_SERVER" 3 24 40 130 0 \
		"Backup source partner name (remote partner)" 5 4 "" 5 70 1 0 2 \
		"SOURCE_RSYNC_USER" 6 4 "$SOURCE_RSYNC_USER" 6 24 40 130 0 \
		"User for ssh connection (usually the same like SOURCE_RSYNC_USER)" 8 4 "" 8 70 1 0 2 \
		"SOURCE_SSH_USER" 9 4 "$SOURCE_SSH_USER" 9 24 40 130 0 \
		"Remote source folder to backup (fake module)" 11 4 "" 11 50 1 0 2 \
		"The '/' at the end controls rsync's behavior (see rsync man page)" 12 4 "" 12 70 1 0 2 \
		"SOURCE_FOLDER" 13 4 "$SOURCE_FOLDER" 13 24 40 130 0 \
		"Path to combine multiple sessions to one common base folder" 15 4 "" 15 70 1 0 2 \
		"(optional/recommended)" 16 4 "" 16 70 1 0 2 \
		"BACKUP_BASE_PATH" 17 4 "$BACKUP_BASE_PATH" 17 24 40 130 0 \
		"rsync exclude file" 19 4 "" 19 70 1 0 2 \
		"Change in case to use a different file (optional)" 20 4 "" 20 70 1 0 2 \
		"SOURCE_EXCLUDE_FILE" 21 4 "$SOURCE_EXCLUDE_FILE" 21 24 40 130 0 2> $TEMP_FILE

	RET=$?
	
	if [ $RET != 0 ]; then 
		rm -f $TEMP_FILE
		rm -f "$TEMP_CHANGED_FILE"
		return
	else
		fn_read_base_1_config_into_vars
	fi

	dialog --backtitle "$DIALOG_BACK_TITLE - $MENU_CHOICE: $CURRENT_FILE" --clear --ok-label "Save changes" --mixedform \
	" Base config (2/2) - use [up] [down] to select input field " 28 80 22\
		"Min counts of backups to keep (default 40)" 2 4 "" 2 70 1 0 2 \
		"The last xx backups will not be removed regardlee of the age" 3 4 "" 3 70 1 0 2 \
		"BACKUP_MIN_COUNT" 4 4 "$BACKUP_MIN_COUNT" 4 24 40 130 0 \
		"Min age in days for backups" 6 4 "" 6 70 1 0 2 \
		"no backups younger will be removed regardless how many we have" 7 4 "" 7 70 1 0 2 \
		"default in the script is 30. Set to 0 for infinite." 8 4 "" 8 70 1 0 2 \
		"BACKUP_MIN_AGE" 9 4 "$BACKUP_MIN_AGE" 9 24 40 130 0 \
		"Change permissions" 11 4 "" 11 70 1 0 2 \
		"Permissions will be changed for directories and files to the mask" 12 4 "" 12 76 1 0 2 \
		"The mask uses rsync syntax (default Dgo-w,Dgo+r,Dgo+x,Fgo-w,Fgo+r,Fugo-x)" 13 4 "" 13 70 1 0 2 \
		"Use KEEP to keep original permissions" 14 4 "" 14 70 1 0 2 \
		"PERMISSIONS" 15 4 "$PERMISSIONS" 15 24 40 130 0 \
		"Cloud backup queue. Empty = no cloud backup" 17 4 "" 17 70 1 0 2 \
		"CLOUD_ARCHIVE_QUEUE" 18 4 "$CLOUD_ARCHIVE_QUEUE" 18 24 40 130 0 \
		"Cloud backup configuration file" 20 4 "" 20 70 1 0 2 \
		"CLOUD_ARCHIVE_REQUEST_FILE" 21 4 "$CLOUD_ARCHIVE_REQUEST_FILE" 21 31 40 130 0 2> $TEMP_FILE

	RET=$?
	
	if [ $RET != 0 ]; then 
		rm -f $TEMP_FILE
		rm -f "$TEMP_CHANGED_FILE"
		return
	else
		fn_read_base_2_config_into_vars
	fi

	dialog --backtitle "$DIALOG_BACK_TITLE - $MENU_CHOICE: $CURRENT_FILE" --clear --ok-label "Save changes" --mixedform \
	" ssh configuration - use [up] [down] to select input field " 26 70 18\
		"ssh port for the source system (optional)" 2 4 "" 2 70 1 0 2 \
		"Default in the script is ssh default port 22" 3 4 ""  3 70 1 0 2 \
		"REMOTE_SSH_PORT" 4 4 "$REMOTE_SSH_PORT" 4 24 40 130 0 \
		"Controls if remote host needs to be in known hosts (optional)" 6 4 ""  6 70 1 0 2 \
		"1: yes, anything else: no (default: 1)" 7 4 ""  7 70 1 0 2 \
		"STRICT_SSH" 8 4 "$STRICT_SSH" 8 24 40 130 0 \
		"ssh private key file (optional)" 10 4 "" 10 70 1 0 2 \
		"Define the private key file for the session (default: id_rsa)" 11 4 "" 11 70 1 0 2 \
		"PRIVATE_KEY_FILE" 12 4 "$PRIVATE_KEY_FILE" 12 24 40 130 0 2> $TEMP_FILE

	RET=$?

	echo $RET

	if [ $RET != 0 ]; then 
		rm -f $TEMP_FILE
		rm -f "$TEMP_CHANGED_FILE"
		return
	else
		fn_read_ssh_config_into_vars
	fi
	
	CURRENT_FILE_SIK=$CURRENT_FILE
	CURRENT_FILE="$TEMP_CHANGED_FILE"
	fn_edit_file
	RET=$?

	if [ $RET = 0 ]; then 
		mv -f "$TEMP_CHANGED_FILE" "$CURRENT_FILE_SIK"
		chown --reference "$BASE_PATH" "$CURRENT_FILE_SIK"
	else
		rm -f "$TEMP_CHANGED_FILE"
	fi

	return
}

fn_aws_config_dialog() {
	dialog --backtitle "$DIALOG_BACK_TITLE - $MENU_CHOICE: $CURRENT_FILE" --clear --ok-label "Save changes" --mixedform \
	" AWS S3 parameters - use [up] [down] to select input field " 30 80 22 \
		"AWS_ACCESS_KEY_ID" 3 4 "$AWS_ACCESS_KEY_ID"  3 26 40 130 0 \
		"AWS_SECRET_ACCESS_KEY" 5 4 "$AWS_SECRET_ACCESS_KEY" 5 26 40 130 0 \
		"AWS_DEFAULT_REGION" 7 4 "$AWS_DEFAULT_REGION" 7 26 40 130 0 \
		"AWS_BUCKET" 9 4 "$AWS_BUCKET" 9 26 40 130 0 2> $TEMP_FILE

	RET=$?
	
	if [ $RET != 0 ]; then 
		rm -f $TEMP_FILE
		rm -f "$TEMP_CHANGED_FILE"
		return
	else
		fn_read_AWS_S3_config_into_vars
	fi

	dialog --backtitle "$DIALOG_BACK_TITLE - $MENU_CHOICE: $CURRENT_FILE" --clear --ok-label "Save changes" --mixedform \
	" AWS local configuration - use [up] [down] to select input field " 28 80 22\
		"The variable allows only to upload parts of a backup in the cloud" 2 4 "" 2 74 1 0 2 \
		"Empty means all files" 3 4 "" 3 70 1 0 2 \
		"May contain multiple combinations of name and pathes separated by ':'" 4 4 "" 4 74 1 0 2 \
		"Example: SUB_1=<folder1>/<folder2>:SUB_2=<folder1>/<folder3>" 5 4 "" 5 70 1 0 2 \
		"LOCAL_BACKUP_SUB_PATH" 6 4 "$LOCAL_BACKUP_SUB_PATH" 6 26 40 130 0 \
		"Exclude some files/folders from the cloud archive" 8 4 "" 8 70 1 0 2 \
		"multiple exclude filters can be used by separating with ':'" 9 4 "" 9 70 1 0 2 \
		"Example: a/*:b/c/d*:e:f/*. Default is empty = don't exclude anything" 10 4 "" 10 74 1 0 2 \
		"TAR_EXCLUDE" 11 4 "$TAR_EXCLUDE" 11 24  40 130 0 \
		"Controls how many generations will be stored in the cloud" 13 4 "" 13 74 1 0 2 \
		"Default is 5, 0 = nothing expires, just add" 14 4 "" 14 70 1 0 2 \
		"MAX_GENERATIONS" 15 4 "$MAX_GENERATIONS" 15 24 40 130 0 \
		"Parameter that only files changed during the last xx days will be" 17 4 "" 17 70 1 0 2 \
		"uploaded to the cloud." 18 4 "" 18 70 1 0 2 \
		"FILE_AGE=0 equals save all files. Default is 120 days." 19 4 "" 19 70 1 0 2 \
		"FILE_AGE" 20 4 "$FILE_AGE" 20 24  40 130 0 2> $TEMP_FILE

	RET=$?
	
	if [ $RET != 0 ]; then 
		rm -f $TEMP_FILE
		rm -f "$TEMP_CHANGED_FILE"
		return
	else
		fn_read_AWS_local_config_into_vars
	fi

	dialog  --backtitle "$DIALOG_BACK_TITLE - $MENU_CHOICE: $CURRENT_FILE" --clear --ok-label "Save changes" --mixedform \
	" AWS encryption configuration - use [up] [down] to select input field " 28 80 22 \
		"Secret for encryption" 2 4 "" 2 70 1 0 2 \
		"If empty file will not be encrytped" 3 4 "" 3 70 1 0 2 \
		"Default is empty/no encryption" 4 4 "" 4 70 1 0 2 \
		"(don't want to make a key proposal in the EXAMPLE file)" 5 4 "" 5 70 1 0 2 \
		"CCRYPT_ENC_KEY" 6 4 "$CCRYPT_ENC_KEY" 6 24  40 130 0 2> $TEMP_FILE

	RET=$?

	if [ $RET != 0 ]; then 
		rm -f $TEMP_FILE
		rm -f "$TEMP_CHANGED_FILE"
		return
	else
		fn_read_AWS_encryption_into_vars
	fi

	CURRENT_FILE_SIK="$CURRENT_FILE"
	CURRENT_FILE="$TEMP_CHANGED_FILE"

	fn_edit_file
	RET=$?

	if [ $RET = 0 ]; then 
		mv -f "$TEMP_CHANGED_FILE" "$CURRENT_FILE_SIK"
		chown --reference "$BASE_PATH" "$CURRENT_FILE_SIK"
	else
		rm -f "$TEMP_CHANGED_FILE"
	fi

	return
}

# -----------------------------------------------------------------------------
# Function edit rsync configuration file
# -----------------------------------------------------------------------------

fn_edit_rsync_conf_file() {
	fn_select_file "select rsync configuration file" $CONF_PATH/	
	RET=$?

	if [ $RET != 0 ]; then
		return
	else
		# read configuration file
		fn_read_rsync_config_file

		# show form
		fn_rsync_config_dialog
	fi
}

fn_edit_aws_conf_file() {
	fn_select_file "select AWS configuration file" $CONF_PATH/	
	RET=$?

	if [ $RET != 0 ]; then
		return
	else
		# read configuration file
		fn_read_aws_config_file

		# show form
		fn_aws_config_dialog
	fi
}

# -----------------------------------------------------------------------------
# Function edit list file
# -----------------------------------------------------------------------------

fn_edit_conf_list_file() {
	fn_select_file "select list file" $CONF_PATH/
	RET=$?

	if [ $RET != 0 ]; then
		return
	else
		fn_edit_file
	fi
}

# -----------------------------------------------------------------------------
# Functions create new file
# -----------------------------------------------------------------------------

fn_new_rsync_conf_file() {
	fn_create_new_file
	RET=$?

	if [ $RET = 0 ]; then
		SOURCE_RSYNC_USER="EXAMPLE"
		SOURCE_SSH_USER="EXAMPLE"
		SOURCE_SSH_SERVER="EXAMPLE.my.domain.com"
		SOURCE_FOLDER="Documents/"
		BACKUP_BASE_PATH="MY-BACKUPS"
		SOURCE_EXCLUDE_FILE="rsync-exclude"
		CLOUD_ARCHIVE_QUEUE="AWS-ALL"
		CLOUD_ARCHIVE_REQUEST_FILE="AWS-EXAMPLE.conf"
		REMOTE_SSH_PORT="22"
		STRICT_SSH="1"
		PRIVATE_KEY_FILE="id_rsa"
		BACKUP_MIN_COUNT="40"
		BACKUP_MIN_AGE="30"
		PERMISSIONS="Dgo-w,Dgo+r,Dgo+x,Fgo-w,Fgo+r,Fugo-x"

		# show form
		fn_rsync_config_dialog
	fi
}

fn_new_aws_conf_file() {
	fn_create_new_file
	RET=$?

	if [ $RET = 0 ]; then
		AWS_ACCESS_KEY_ID=""
		AWS_SECRET_ACCESS_KEY=""
		AWS_DEFAULT_REGION=""
		AWS_BUCKET="my-backup-bucket"
		LOCAL_BACKUP_SUB_PATH=""
		TAR_EXCLUDE=""
		MAX_GENERATIONS="5"
		FILE_AGE="120"
		CCRYPT_ENC_KEY=""

		# show form
		fn_aws_config_dialog
	fi
}

fn_new_conf_list_file() {
	fn_create_new_file
	RET=$?

	if [ $RET = 0 ]; then
		# show form
		touch "$CURRENT_FILE"
		fn_edit_file
	fi
}

# -----------------------------------------------------------------------------
# Main menu
# -----------------------------------------------------------------------------

fn_main_menu() {
	dialog --backtitle "$DIALOG_BACK_TITLE - Main menue" --clear \
		--menu " Main menu - use [up] [down] to select topic " 20 59 10 \
		"1 New rsync conf" "Create a new backup conf file" \
		"2 New AWS conf" "Create a new AWS conf file" \
		"3 New conf list file" "Create a new conf list file" \
		"4 Edit rsync conf" "Edit a backup conf file" \
		"5 Edit AWS conf" "Edit an AWS conf file" \
		"6 Edit conf list file" "Edit a conf list file" \
		"Q Quit" "Exit program" 2> $TEMP_FILE
	RET=$?

	# Stop on Cancel
	if [ $RET != 0 ]; then 
		rm -f $TEMP_FILE
		MENU_CHOICE="Q"
	else
		MENU_CHOICE=$(cat $TEMP_FILE && rm -f $TEMP_FILE)
	fi
	
	case "$MENU_CHOICE" in
		"1 New rsync conf") 		fn_new_rsync_conf_file
						;;
		"2 New AWS conf")		fn_new_aws_conf_file
						;;
		"3 New conf list file")		fn_new_conf_list_file
						;;
		"4 Edit rsync conf")		fn_edit_rsync_conf_file
						;;
		"5 Edit AWS conf")		fn_edit_aws_conf_file
						;;
		"6 Edit conf list file")	fn_edit_conf_list_file
						;;
		"Q Quit"|*)			clear
						exit 0
						;;
	esac
}

# ---------------------------------------------	--------------------------------
# Main program
# -----------------------------------------------------------------------------

while true; do
	fn_main_menu
done


