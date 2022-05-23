#!/bin/bash

# Suss out the gel-reaper's home directory (wherever it's called from)
GRHOME_DIR="$( cd -- "$( dirname -- "${BASH_SOURCE[0]}" )" &> /dev/null && pwd )"
FUNCTION_FILE=$GRHOME_DIR/gr-functions.shinc
source <( cat ${FUNCTION_FILE}  )

##
## MAIN
##

grprint 9 "\n--- `date +'%T'` --- AWS EC2 Key Pairs ---------------------"

# Confirm AWS token is valid before running (and again later)
if ! valid_aws_token
then
    exit
fi

grprint 1 "Finding EC2 Key Pairs for (userPrefix)-nfs-server-admin and -jump-admin"

# Key Pairs provisioned by the IaC for NFS Server and Jump Host
mapfile -t array < <($AWSCMD ec2 describe-key-pairs --query 'KeyPairs[].[KeyName]' --output text | grep -E "nfs-server-admin|jump-admin")
items=${#array[@]}          # no. of items in array

allkeyowners=""
activekeyowners=""
for (( i=0; i<${items}; i++ )); 
do 
    # announce what's there
    #echo "${array[$i]}" | awk {'print $0'}   # policy name, id

    thiskeypair=`echo ${array[$i]} | awk {'print $1'} `               # KeyPairs[].[KeyName]
    thisprefix=`echo "${array[$i]}" | awk -F"-" {'print $1'} `        # KeyPairs[].[KeyName] (just the prefix)

    if [[ " ${allkeyowners} " =~ " ${thisprefix} " ]]
    then
        # already checked the active EKS status of this owner
        x=1
    else
        # keep track of which policy owners we've checked for EKS already
        allkeyowners+="${thisprefix} "

        # Check for active EKS owners 
        if active_eks_owner $thisprefix
        then
            # keep track owners of active EKS clusters
            activekeyowners+="${thisprefix} "  
        fi            
    fi

    if [[ " ${activekeyowners} " =~ " ${thisprefix} " ]]
    then
        x=1
        grprint 2 "Active EKS found: Skipping EC2 Key Pair $thiskeypair for $thisprefix."
    else
        # No active EKS, so delete the keypair
        grprint 3 "Deleting EC2 Key Pair $thiskeypair for $thisprefix."
        grprint 4 "aws ec2 delete-key-pair --key-name $thiskeypair " 
        $AWSCMD ec2 delete-key-pair --key-name $thiskeypair     # --dry-run 
    fi
done
