#!/bin/bash
#
# nuke-viya4-aws.sh
#
# ATTENTION: This script is not part of GELLOW execution. It is used by a "Gelkins" job
#            to keep the AWS tokens up-to-date for the students.
#            http://gelkins.race.sas.com:8080/job/AWS/job/nuke-viya4-aws/
#
# Assumes:
#   - AWS sas-salesenabletest tokens/credentials are in place 
#   - AWS CLI is available 
#   - Ability to download the cloud-nuke binary
#
# rocoll        - 01-JUL-21      - init
# ---------------------------------------------------------

##### MODIFY AS NEEDED

# delete AWS resources older than this
OLDERTHAN="12h"                      # goal: 24h or less 

# build list of exclusion options
EXCLAUSE="--older-than ${OLDERTHAN}"

# exclude this list resource types from deletion
EXCLUDERT="s3"            # space-separated list
for e in $EXCLUDERT
do
  EXCLAUSE="${EXCLAUSE} --exclude-resource-type ${e}"
done
# follow this example to create other ex/inclusions 


##### MAIN

# url to get the cloud-nuke executable
DOWNLOADURL="https://github.com/gruntwork-io/cloud-nuke/releases/download/v0.3.0/cloud-nuke_linux_amd64"
CLOUDNUKE="/tmp/cloud-nuke"

# Interactive? Or Automation?
UNKOWNARGS=()
while [[ $# -gt 0 ]]; do
  key="$1"

  case $key in
    -f|--force)
    FORCERUN=1
    shift  # to next arg
    ;;
    *)     # any other options
    UNKOWNARGS+=("$1")   # save in array for later, if needed
    shift  # to next arg
    ;;
  esac
done

##### Download the cloud-nuke utility

# download cloud-nuke and save to specified location
wget --quiet $DOWNLOADURL -O $CLOUDNUKE
if [ $? -ne 0 ]
then
  echo -e "nva-ERROR: Unable to download cloud-nuke at:\n$DOWNLOADURL"
  exit 1
fi

# running as
aws sts get-caller-identity  --output table


# make it executable
chmod +x $CLOUDNUKE

$CLOUDNUKE --help > /dev/null 2>@1
if [ $? -ne 0 ]
then
  echo -e "nva-ERROR: Unable to execute $CLOUDNUKE"
  exit 1
fi


##### NUKK 'EM

# WARNING:
# The idea here is that for the GEL Deploying SAS Viya workshop, all students are  
# signed in to the same account/role. When cloud-nuke runs, it'll target everything in 
# that account, regardless of which student created it. So be sure to exclude anything 
# that needs to live on. There is no recovery of unintentionally deleted resources.

if [[ $FORCERUN == 1 ]]
then
  # Pre-answer the prompt - cloud-nuke deletes immediately
  echo nuke | $CLOUDNUKE aws ${EXCLAUSE}                 # major destruction ensues
else
  # Allow cloud-nuke to prompt user for confirmation
  $CLOUDNUKE aws ${EXCLAUSE}
fi

exit
