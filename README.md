# Under construction!

## rsync-pull-backup

## Intention 

The scripts have been designed for server based time machine like backup of user data/documents. They are NOT designed for a full system backup. 

## Features
* Copy secured by ssh connection
* Each source system has its own configuration
* batch or single mode

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

## Configuration

Check the EXAMPLE.conf file for all and min-EXAMPLE.conf for a min. set of options.
