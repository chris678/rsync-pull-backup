#!/bin/bash
#
# script fo archiving/backups using rsync
#

APPNAME=$(basename $0 | sed "s/\.sh$//")
PID=$$
RSYNC_DATE=$(date "+%Y-%m-%d_%H-%M-%S")

# -----------------------------------------------------------------------------
# Check input variables
# -----------------------------------------------------------------------------

SESSION=$1
BASE_PATH=$2

if [[ "$SESSION" = "" || "$BASE_PATH" = "" ]]; then
	# Missing parameter --> exit
	echo ""
	echo "Missing parameter. Usage: $APPNAME.sh <conf file name> <base path>"
	echo "Example: $APPNAME.sh EXAMPLE /<path>/backup-user"
	echo ""
	exit 255
fi

# -----------------------------------------------------------------------------
# set base path variables
# -----------------------------------------------------------------------------

WRK_PATH=$BASE_PATH/wrk
LOG_PATH=$BASE_PATH/log
CONF_PATH=$BASE_PATH/conf
DIRTY_PATH=$BASE_PATH/dirty
SSH_PATH=$BASE_PATH/.ssh
PIPELINE_PATH=$BASE_PATH/pipeline
BACKUP_ROOT_PATH=$BASE_PATH/backups

# -----------------------------------------------------------------------------
# Mostly needed
# -----------------------------------------------------------------------------

logger() {
	echo "$(date '+%D %T') $APPNAME[$PID]: $1" >> $LOG

}

# -----------------------------------------------------------------------------
# exit in case the no-run file has been set
# -----------------------------------------------------------------------------

if [ -f "$CONF_PATH/backup.stop" ]; then
	logger "ERROR: Lock file $CONF_PATH/backup.stop has been found. Terminating without actions" 
	exit 1
fi

# -----------------------------------------------------------------------------
# create pipeline is not existing
# -----------------------------------------------------------------------------

if [ ! -d "$PIPELINE_PATH" ]; then
	# create PIPELINE if not existing yet
	mkdir -p $PIPELINE_PATH

	# we can exit because there cannot be anything waiting
	exit 0
fi

# -----------------------------------------------------------------------------
# Make sure everything really stops when CTRL+C is pressed
# -----------------------------------------------------------------------------

fn_terminate_script() {
	logger "ERROR: SIGINT caught. Terminating. Check $BACKUP_WRK_PATH for incomplete backups"
	exit 1
}

trap 'fn_terminate_script' SIGINT

# -----------------------------------------------------------------------------
# Check if source server is online and available
# -----------------------------------------------------------------------------

fn_check_source_available() {
	# ToDo: take care, no IP addresses allowed! Should be changed?
	nc -vz $SOURCE_SSH_SERVER $REMOTE_SSH_PORT > /dev/null
	RET=$?

	if [ "$RET" = "0" ]; then
		# ok, we can continue

		# create $BACKUP_WRK_PATH only if we have a connection
		if [ ! -d "$BACKUP_WRK_PATH" ]; then
			mkdir -p "$BACKUP_WRK_PATH"
			chmod 755 "$BACKUP_WRK_PATH"
		fi

		return 0
	else
		# client is down, we can exit. No logging, it is a valid state
		return 1
	fi
}

# -----------------------------------------------------------------------------
# Get parameters from file
# -----------------------------------------------------------------------------

fn_get_parameters() {
	# set defaults
	REMOTE_SSH_PORT=22
	SOURCE_EXCLUDE_FILE=rsync-exclude
	BACKUP_MIN_COUNT=40
	BACKUP_MIN_AGE=30
	STRICT_SSH=1
	BACKUP_OWNER=KEEP
	NUMERIC_IDS=1
	PERMISSIONS="Dgo-w,Dgo+r,Dgo+x,Fgo-w,Fgo+r,Fugo-x"
	PRIVATE_KEY=id_rsa
	DEST_BASE_PATH=$SESSION

	# set the log file name
	LOG="$LOG_PATH"/"$APPNAME"-"$SESSION"_$RSYNC_DATE.log
	if [ ! -d "$LOG_PATH" ]; then
		mkdir -p "$LOG_PATH"
	fi

	# check existance of conf file
	if [ ! -f "$CONF_PATH/$SESSION" ]; then
		logger "ERROR: $CONF_PATH/$SESSION does not exist. Skip"
		return
	fi

	while read line; do
		read _PARAMETER _VALUE <<< $(IFS="="; echo $line)
		
		# set PARAMETER to upper case to make live easier
		PARAMETER=$(echo $_PARAMETER | tr 'a-z' 'A-Z')

		case $PARAMETER in
		REMOTE_SSH_PORT) 	REMOTE_SSH_PORT=$_VALUE
					;;
		SOURCE_RSYNC_USER)	SOURCE_RSYNC_USER=$_VALUE
					;;
		SOURCE_SSH_USER)	SOURCE_SSH_USER=$_VALUE
					;;
		SOURCE_SSH_SERVER)	SOURCE_SSH_SERVER=$_VALUE
					;;
		SOURCE_FOLDER)		SOURCE_FOLDER=$_VALUE
					;;
		SOURCE_EXCLUDE_FILE)	SOURCE_EXCLUDE_FILE=$_VALUE
					;;
		BACKUP_BASE_PATH)	DEST_BASE_PATH=$_VALUE
					;;
		BACKUP_MIN_COUNT)	BACKUP_MIN_COUNT=$_VALUE
					;;
		BACKUP_MIN_AGE)		BACKUP_MIN_AGE=$_VALUE
					;;
		STRICT_SSH)		STRICT_SSH=$_VALUE
					;;
		BACKUP_OWNER)		BACKUP_OWNER=$_VALUE
					;;
		CHMOD)			CHMOD=$_VALUE
					;;
		NUMERIC_IDS)		NUMERIC_IDS=$_VALUE
					;;
		PERMISSIONS)		PERMISSIONS=$_VALUE
					;;
		PRIVATE_KEY_FILE)	PRIVATE_KEY=$_VALUE
					;;
		esac
	done < $CONF_PATH/$SESSION

	# now we know everything we need to complete the BACKUP_BASE_PATH
	BACKUP_BASE_PATH=$BACKUP_ROOT_PATH/$DEST_BASE_PATH/$SOURCE_FOLDER
	BACKUP_WRK_PATH=$WRK_PATH/$DEST_BASE_PATH/$SOURCE_FOLDER/$RSYNC_DATE
	BACKUP_DIRTY_PATH=$DIRTY_PATH/$DEST_BASE_PATH/$SOURCE_FOLDER

	# check the existance of the base folders
	if [ ! -d "$BACKUP_BASE_PATH" ]; then
		mkdir -p "$BACKUP_BASE_PATH"
		chmod 755 "$BACKUP_BASE_PATH"
	fi

	if [ ! -d "$BACKUP_DIRTY_PATH" ]; then
		mkdir -p "$BACKUP_DIRTY_PATH"
		chmod 755 "$BACKUP_DIRTY_PATH"
	fi
}

# -----------------------------------------------------------------------------
# Get oldest and youngest backup (if any before)
# -----------------------------------------------------------------------------

fn_get_backups() {
	# total current count of backups (for later use)
	countBackups=$(ls $BACKUP_BASE_PATH/ | wc -w)

	# no need to continue if = 0
	if [ "$countBackups" != "0" ]; then
		# we have already backups. Let's determine the other values for later use to have all at one place
		oldestBackup=$BACKUP_BASE_PATH/$(ls -t $BACKUP_BASE_PATH | head -n1)
		youngestBackup=$BACKUP_BASE_PATH/$(ls -t $BACKUP_BASE_PATH | tail -n1)
	fi
}

# -----------------------------------------------------------------------------
# Check changed files against previous version 
# -----------------------------------------------------------------------------

fn_check_changed_files() {
	# check if the file type of previous archived files has changed
	# if yes something might be wrong with the files

	RET=0

	while read line; do 
		read p1 file_name <<< $(echo $line)

		if [ "${line:2:9}" != "+++++++++" ]; then
			# only changed files, new files are always ok
			oldFileType=$(file -bi "$youngestBackup/$file_name" | cut -d ";" -f 1)

			# only if the old file really exits (might happen in case of manual moves of older backups...)
			if [ -f "$BACKUP_WRK_PATH/$file_name" ]; then
				newFileType=$(file -bi "$BACKUP_WRK_PATH/$file_name" | cut -d ";" -f 1)

				if [[ "$oldFileType" = "inode/x-empty" || "$newFileType" = "inode/x-empty" ]]; then
					# if one of the files is empty, skip 
					continue
				fi 

				if [ "$oldFileType" != "$newFileType" ]; then
					# something might be wrong! Leave the checks and mark backup as dirty

					logger "ERROR: File $BACKUP_WRK_PATH/$file_name is dirty. $oldFileType <> $newFileType. Backup moved to $BACKUP_DIRTY_PATH/$RSYNC_DATE"

					mv -f "$BACKUP_WRK_PATH" "$BACKUP_DIRTY_PATH" 
					RET=1
					break
				fi
			fi
		fi

	done < $LOG

	return $RET
}

# -----------------------------------------------------------------------------
# Remove older backups
# -----------------------------------------------------------------------------

fn_expireBackup() {
	# in case of 0 never delete old archives
	if [ "$BACKUP_MIN_AGE" != "0" ]; then
		# get date normalized to begin of the day (folderDate below is normalized the same way)
		dateToday=$(date -d $(date '+%Y%m%d') '+%s')

		# save countBackups for comparison
		counter=$countBackups

		# calculate the dead line (one day has 86400 seconds)
		(( CompareDate=$dateToday-$BACKUP_MIN_AGE*86400 ))

		for line in $(ls --group-directories-first -d "$BACKUP_BASE_PATH"/*); do
			# determine if $line is a directory (files and sym links are out of scope)
			if [ "$(file -bi $line | cut -d ';' -f 1)" = "inode/directory" ]; then
				# we have a directory (now we know for sure). Check the age.
#				folderDate=$(date --date $(ls --full-time -d "$line" | cut -d ' ' -f 6 | tr -d '-') '+%s')
				folderDate=$(date --date $(basename $(ls -d "$line") | cut -d '_' -f 1 | tr -d '-') '+%s')
				RET=$?

				if [ "$RET" != "0" ]; then
					continue
				fi
				
				if [ $folderDate -lt $CompareDate ]; then
					# directory/backup is older then today - xx days --> maybe delete (we have 2 conditions!)

					if [ $counter -ge $BACKUP_MIN_COUNT ]; then
						# remove outdated backup - we still have $BACKUP_MIN_COUNT generations
						# (delete can be done in place because a move to a different location also might take a long time (tried before)) 

						# be friendly
						nice rm -fR "$line"

						# also remove the old log file
						OLD_LOG="$LOG_PATH"/"$APPNAME"-"$SESSION"_$(basename "$line").log

						if [ -f "$OLD_LOG" ]; then
							# only if the log file exists
							rm -f "$OLD_LOG"
						fi

						# increase directory counter
						(( counter-=1 ))

						logger "INFO: Backup $line aged --> deleted"
					else
						# BACKUP_MIN_COUNT reached --> break
						break
					fi
				else
					# no more backups/folders older deadline --> break
					break
				fi
			else
				# no directories anymore to check --> break
				break
			fi
		done
	fi

	return
}

# -----------------------------------------------------------------------------
# Integrate new backup
# -----------------------------------------------------------------------------

fn_integrate_new_backup() {
	# change owner before integration (overwrites rsync chown)
	_BACKUP_OWNER=$(echo $BACKUP_OWNER | tr 'a-z' 'A-Z')

	if [ "$_BACKUP_OWNER" != "KEEP" ]; then
		if [ "$USER" = "root" ]; then
			# only allowed as root
			chown -R $BACKUP_OWNER "$BACKUP_WRK_PATH"
		else
			logger "WARNING: Option BACKUP_OWNER ($BACKUP_OWNER): Script needs to run as root for other options than KEEP."
		fi
	fi

	mv  -f "$BACKUP_WRK_PATH" "$BACKUP_BASE_PATH"
}

# -----------------------------------------------------------------------------
# set CMD options
# -----------------------------------------------------------------------------

fn_set_CMD_options() {
	CMD="--compress"
	CMD="$CMD --links"
	CMD="$CMD --hard-links"
	CMD="$CMD --one-file-system"
	CMD="$CMD -rlts"
	CMD="$CMD --verbose"
	CMD="$CMD --delete"

	# change permission settings
	# become independent from lower/upper case
	_PERMISSIONS=$(echo $PERMISSIONS | tr 'a-z' 'A-Z')

	if [ "$_PERMISSIONS" = "KEEP" ]; then
		CMD="$CMD --perms"
	else
		CMD="$CMD --chmod=$PERMISSIONS"
	fi

	CMD="$CMD -i"

	# set the link dest if we have already older backups
	if [ "$countBackups" != "0" ]; then
		CMD="$CMD --link-dest=$youngestBackup"
	fi

	# the exclude file if exists
	if [ "$SOURCE_EXCLUDE_FILE" != "" ]; then
		if [ -f "$CONF_PATH/$SOURCE_EXCLUDE_FILE" ]; then
			CMD="$CMD --exclude-from=$CONF_PATH/$SOURCE_EXCLUDE_FILE"
		else
			logger "WARNING: Exclude file $CONF_PATH/$SOURCE_EXCLUDE_FILE does not exist"
		fi
	fi

	# check existance of private key file
	if [ ! -f "$SSH_PATH/$PRIVATE_KEY" ]; then
		logger "ERROR: Private key $SSH_PATH/$PRIVATE_KEY does not exist"
		return 1
	fi

	# set ssh options
	if [ "$STRICT_SSH" = "1" ]; then
	   	SSH_CMD="-i $SSH_PATH/$PRIVATE_KEY"
	else
		SSH_CMD="-o StrictHostKeyChecking=no -o UserKnownHostsFile=/dev/null -i $SSH_PATH/$PRIVATE_KEY"
	fi
	
	return 0
}

# -----------------------------------------------------------------------------
# start rsync for a single task
# -----------------------------------------------------------------------------

fn_execute_rsync() {
	# get parameters for rsync task
	fn_get_parameters
	fn_get_backups

	# is the client up? 
	fn_check_source_available
	RET=$?

	if [ "$RET" = "1" ]; then
		# if the client is not up try next execution loop again
		return 1
	fi

	# set options for rsync
	fn_set_CMD_options
	RET=$?

	if [ "$RET" != "0" ]; then
		# at least one option failed --> leave without backup
		return 1
	fi

	# start the backup
	logger "INFO: Starting backup. Session: $SESSION"
	logger "INFO: rsync option list: $CMD. SSH options: $SSH_CMD"
	nice rsync $CMD -e "ssh $SSH_CMD -p $REMOTE_SSH_PORT -l $SOURCE_SSH_USER" $SOURCE_RSYNC_USER@$SOURCE_SSH_SERVER:"$SOURCE_FOLDER" "$BACKUP_WRK_PATH" >> $LOG
	RET=$?

	if [ "$RET" = "0" ];then
		# if backup completed without errors check for changed file types (might be a signal for something strange (regards to locky and friends))
		if [ "$countBackups" != "0" ]; then
			# only if not new
			fn_check_changed_files
			RET=$?
		fi

		# next steps only if we didn't find something strange!		
		if [ "$RET" = "0" ]; then
			# integrate new backup
			fn_integrate_new_backup

			# and if there are some ol. Set to 0 for infinite.der backup we can remove
			fn_expireBackup
	
			logger "INFO: Backup successful finished"
		else
			logger "ERROR: Backup ended with changed file type! Backup has been moved to dirty folder"
		fi
	else
		logger "ERROR: rsync terminated with error. Incomplete backup. Check $BACKUP_WRK_PATH"
	fi

	return 0
}

# -----------------------------------------------------------------------------
# main program
# -----------------------------------------------------------------------------

# set SESSION for check to upper case so we are not case sensitive (sad experience with typos)
_SESSION=$(echo $SESSION | tr 'a-z' 'A-Z')

# Check if script is already running to avoid high system load/conflicts in case of PIPELINE
if [ "$(pidof -x $(basename $0))" = "$PID" ]; then
	# script is not running twice, continue

	if [ "$_SESSION" = "PIPELINE" ]; then
		for _file in $(ls -tr $PIPELINE_PATH); do
			SESSION=$_file
			# start rsync for the session
			fn_execute_rsync
			RET=$?

			if [ "$RET" = "1" ]; then
				# if the client is not up try next execution loop again
				continue
			fi

			# we are done for this session and can remove the request from the pipeline
			rm -f $PIPELINE_PATH/$_file
		done
	else
		fn_execute_rsync
	fi
else
	if [ "$_SESSION" != "PIPELINE" ]; then
		# think PIPELINE is mostly batch mode and should not give an output. But in dialog we should know
		echo ""
		echo "Script already running --> exit"
		echo ""
	fi
fi

# exit always 0 
exit 0

