# rsync-pull-backup

## Intention 

The scripts have been designed for server based time machine like backup of user data/documents. They are NOT designed for a full system backup. For this purpose other tools exist.

The scripts should work with all clients which support a ssh server. It has been tested with Windows and Linux as client (no Mac available).

Backups are important - but creating them takes time and to be fair I'm lazy with this. So I've been looking for a way how I can automate my backups and don't need to think about them anymore after setup. Nice would also be to have a time line of backups so I can restore a single, accidently changed/deleted/... file without the need to restore from an archive system. 

Next request has been to make it save so it cannot be changed on/from my local systems. Because I have a NAS (in this case a BananaPi with OMV) the idea came up to start the backups from the NAS using rsync. This script collection is the result.

There is no restore functionalit so the scripts are "one way only". For me this doesn't matter as they are only desinged for files/documents which can be restored manually without huge problems/conflicts with access rights and so on. To have access to the backups from a remote site I use /etc/fstab to mount the base folder of a backup user to another folder which is reachable by a SMB share. This can be done without risk because the owners are different and by default only the backup user has write access to the backup. All other ones can only read the files. Didn't test if this would be true also if you use soft links for this.

## Features
* Copy secured by ssh connection
* Each source system has its own configuration (and might also have multiple)
* batch or single mode
* Processing can be stopped by setting a stop file.
* Basic check for changed file types after a backup. If the type of a file e.g changes from text to something else the backup will not be integrated into the time line.
* Automatic aging/deleting of older backups. Each backup job may have its own max. age.
* Each backup job may have its own exclude file list
* For each backup job you can set different user rights
* Script does not neeed to run as root on the server
* If the client is not available the script postpones the backup until the client is back again. No folders in the backup time line will be created.
* Detailed logging of all actions and changed files
* Each backup job may have an own ssh key pair
* Configuration file editor with a dialog based interface

## Content/Scripts
The collection contains three scripts:
* add_backup_to_queue.sh: Adds a backup request to a queue
* rsyncBackup.sh: Processes all requests from the queue
* checkLogFile.sh: Checks the log files of the backups for errors. Because the OMV crontab can be easily configured to send a mail notification on cron job outputs there is no mail component in the script.
* configEditor.sh: Editor for configuration files for rsyncBackup.sh and AWS_backup.sh with a textual interface using dialog. The editor can be used as user root.
* AWS_backup.sh: Script for uploading backups to the AWS S3 cloud

All scripts are started by crontab on the NAS so nothing needs to be configured on the clients except of the ssh server (and also the scripts/configurations of the backup cannot be changed by a malware).


**Be aware that a ssh server is a potential risk.** To make it more secure I disabled password login on the clients sshd configuration and changed the owner of the authorized_keys file of the user to root so nobody can access the PC without an interaction of somebody with root access. At least for me this is save enough. 

## Requirements
* add_backup_to_queue.sh: nothing special
* rsyncBackup.sh: nc, rsync, ssh need to be installed on the server
* checkLogFile.sh: nothing special
* configEditor.sh: dialog need to be installed on the server
* AWS_backup.sh: - Python 2 version 2.6.5+ or Python 3 version 3.3+, Pip, awscli, ccrypt, find, tar need to be installed on the server


## Folder structure on the server
./backup root
* /.ssh - Folder for private key file(s)
* /backups - Source folder for the backups (will be created automatically if not exists)
* /conf -  Folder for configuration and exclude files
* /dirty - Source folder for "dirty" backups. Dirty backups are backups where in one file type changed after backup (will be created automatically if not exists)
* /log - Folder for log files (will be created automatically if not exists)
* /backup-queue - Queue folder (will be created automatically if not exists)
* /wrk - Work folder. Used by backups during process (will be created automatically if not exists)
* /cloud-queue - Queue folder for upload to the cloud request (will be created automatically if not exists)
* /cloud-backups - Base folder for cloud backups. Contains several sub folders (will be created automatically if not exists)

All other needed folders will be created by the scripts on demand/first usage.

## Installation
### Installation on the server

* Copy the sh files to i.e. /usr/local/bin
* Create a user (should be a dedicated user) for backups
* Create a root folder for backups and make the change the owner to the backup user 
* Create a sub folder conf for the configuration files
* Create a sub folder .ssh for key files
* Create a key pair in the .ssh folder

### Installation on the client 

* Install a ssh server and make it secure (!). See also the remarks about this.
* Add the public key to the client user in the authorized_keys file

Make sure you can reach the client with ssh and shared key authentication.

And again: **Be aware that a ssh server is a potential risk.** To make it more secure I disabled password login on the clients sshd configuration and changed the owner of the authorized_keys file of the user to root so nobody can access the PC without an interaction of somebody with root access. At least for me this is save enough. 

## Usage
### Script usage

* add_backup_to_queue.sh -s &lt;conf file&gt;|-l &lt;list file name&gt; [-p &lt;base path&gt;] <br> <br>
Parameters: <br>
-s &lt;conf file name&gt;  - Process a dedicated session from &lt;base path&gt;/conf <br>
-l &lt;list file name&gt;  - Read list of sessions from &lt;base path>/conf/&lt;list file name&gt; <br>
-p &lt;base path&gt;   - base path for backups. <br>
Optional, if &lt;base path&gt; is not omitted and $HOME/.rsbackup.conf exists &lt;base path&gt; will be read from there
The file $HOME/.rsbackup.conf must contain the line BASE_PATH=&lt;base path&gt;

* rsyncBackup.sh -s &lt;conf file name&gt;|-q [-p &lt;base path&gt;] <br> <br>
Parameters: <br>
-s &lt;conf file name&gt;  - Process a dedicated session from &lt;base path&gt;/conf <br>
-q                   - Process all sessions in &lt;base path&gt;/backup-queue <br>
-p &lt;base path&gt;       - base path for backups. <br>
                       Optional, if &lt;base path&gt; is not omitted and $HOME/.rsbackup.conf exists &lt;base path&gt; will be read from there <br>
                       The file $HOME/.rsbackup.conf must contain the line BASE_PATH=&lt;base path&gt; <br>
 
* checkLogFile.sh [-d &lt;log file age to ckeck in days&gt;] [ -p &lt;base path&gt;]<br>
<br>
Parameters:<br>
-d                   - Optional, log file age to ckeck in days, default is 1 day<br>
-p &lt;base path&gt;       - base path for backups.<br>
                       Optional, if &lt;base path&gt; is not omitted and $HOME/.rsbackup.conf exists &lt;base path&gt; will be read from there<br>
                       The file $HOME/.rsbackup.conf must contain the line BASE_PATH=&lt;base path&gt;<br>
<br>

* configEditor.sh [&lt;base path&gt;]" <br><br>
If &lt;base path&gt; is not omitted and $HOME/.rsbackup.conf exists &lt;base path&gt; will be read from there <br>

* AWS_backup.sh -q &lt;queue name&gt; [-p &lt;base path&gt;] <br>
<br>
Parameters:<br>
-q &lt;queue name&gt; - Queue folder name. A folder relative to &lt;base path&gt;/cloud-queue. The folder contains the request files for the upload to the AWS S3 cloud <br>
-p &lt;base path&gt;  - base path for backups <br>
                  Optional, if &lt;base path&gt; is not omitted and $HOME/.rsbackup.conf exists &lt;base path&gt; will be read from there <br>
                  The file $HOME/.rsbackup.conf must contain the line BASE_PATH=&lt;base path&gt; <br>

## Configuration

Check EXAMPLE.conf and AWS-EXAMPLE.conf for example configurations. The same help is also available in configEditor.sh.


## License
The MIT License (MIT)

Copyright (c) 2016 chris678

Permission is hereby granted, free of charge, to any person obtaining a copy
of this software and associated documentation files (the "Software"), to deal
in the Software without restriction, including without limitation the rights
to use, copy, modify, merge, publish, distribute, sublicense, and/or sell
copies of the Software, and to permit persons to whom the Software is
furnished to do so, subject to the following conditions:

The above copyright notice and this permission notice shall be included in all
copies or substantial portions of the Software.

THE SOFTWARE IS PROVIDED "AS IS", WITHOUT WARRANTY OF ANY KIND, EXPRESS OR
IMPLIED, INCLUDING BUT NOT LIMITED TO THE WARRANTIES OF MERCHANTABILITY,
FITNESS FOR A PARTICULAR PURPOSE AND NONINFRINGEMENT. IN NO EVENT SHALL THE
AUTHORS OR COPYRIGHT HOLDERS BE LIABLE FOR ANY CLAIM, DAMAGES OR OTHER
LIABILITY, WHETHER IN AN ACTION OF CONTRACT, TORT OR OTHERWISE, ARISING FROM,
OUT OF OR IN CONNECTION WITH THE SOFTWARE OR THE USE OR OTHER DEALINGS IN THE
SOFTWARE.
