# rsync-pull-backup

## Intention 

The scripts have been designed for server based time machine like backup of user data/documents. They are NOT designed for a full system backup. For this purpose other tools exist.

The scripts should work with all clients which support a ssh server. It has been tested with Windows and Linux as client (no Mac available).

Backups are important - but creating them takes time. I've been looking for a way how I can automate my backups and don't need to think about them anymore after setup. Nice would also be to have a time line of backups so I can restore a single, accidently changed/deleted/... file without the need to restore from an archive system. 

Next request has been to make it save so it cannot be changed on/from my local systems. Because I have a NAS (in this case a BananaPi with OMV) the idea came up to start the backups from the NAS using rsync. This script collection is the result.

## Content/Scripts
The collection contains three scripts:
* AddToBackupPipeline.sh: Adds a backup request to a queue
* rsyncPollScript.sh: Processes all requests from the queue
* checkLogfile.sh: Checks the log files of the backups for errors. Because the OMV crontab can be easily configured to send a mail notification on cron job outputs there is no mail component in the script.
 
All scripts are started by crontab on the NAS so nothing needs to be configured on the clients except of the ssh server (and also the scripts/configurations of the backup cannot be changed by a malware).



**Be aware that a ssh server is a potential risk.** To make it more secure I disabled password login on the clients sshd configuration and changed the owner of the authorized_keys file of the user to root so nobody can access the PC without an interaction of somebody with root access. At least for me this is save enough. 

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

## Requirements
* nc needs to be installed on the server

## Folder structure on the server
./backup root
* /.ssh - Folder for private key file(s)
* /backups - Source folder for the backups (will be created automatically if not exists)
* /conf -  Folder for configuration and exclude files
* /dirty - Source folder for "dirty" backups. Dirty backups are backups where in one file type changed after backup (will be created automatically if not exists)
* /log - Folder for log files (will be created automatically if not exists)
* /pipeline - Queue folder (will be created automatically if not exists)
* /wrk - Work folder. Used by backups during process (will be created automatically if not exists)


## Usage
### Installation

* Copy the sh files to i.e. /usr/local/bin
* Create a user (should be a dedicated user) for backups
* Create a root folder for backups and make the change the owner to the backup user 
* Create a sub folder conf for the configuration files
* Create a sub folder .ssh for key files
* Create a key pair in the .ssh folder

All other needed folders will be created by the scripts on demand/first usage.

Make sure you can reach the client with ssh and shared key authentication.

And again: **Be aware that a ssh server is a potential risk.** To make it more secure I disabled password login on the clients sshd configuration and changed the owner of the authorized_keys file of the user to root so nobody can access the PC without an interaction of somebody with root access. At least for me this is save enough. 


## Configuration

Check the EXAMPLE.conf file for all and min-EXAMPLE.conf for a min. set of options.

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
