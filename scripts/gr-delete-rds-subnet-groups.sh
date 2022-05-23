#!/bin/bash

# Suss out the gel-reaper's home directory (wherever it's called from)
GRHOME_DIR="$( cd -- "$( dirname -- "${BASH_SOURCE[0]}" )" &> /dev/null && pwd )"
FUNCTION_FILE=$GRHOME_DIR/gr-functions.shinc
source <( cat ${FUNCTION_FILE}  )

##
## MAIN
##

grprint 9 "\n--- `date +'%T'` --- AWS RDS DB Subnet Groups -------------"

# Confirm AWS token is valid before running (and again later)
if ! valid_aws_token
then
    exit
fi

grprint 1 "Finding RDS DB Subnet Groups"

# Key Pairs provisioned by the IaC for NFS Server and Jump Host
mapfile -t array < <($AWSCMD rds describe-db-subnet-groups --region $LOC --query 'DBSubnetGroups[].[DBSubnetGroupName,DBSubnetGroupArn]' --output text)
items=${#array[@]}          # no. of items in array

allsgowners=""
activesgowners=""
for (( i=0; i<${items}; i++ )); 
do 
    # announce what's there
    #echo "${array[$i]}" | awk {'print $0'}   # policy name, id

    thisprefix=`echo ${array[$i]} | awk {'print $1'} `               # DBSubnetGroups[].[DBSubnetGroupName]

    if [[ " ${allsgowners} " =~ " ${thisprefix} " ]]
    then
        # already checked the active EKS status of this owner
        x=1
    else
        # keep track of which policy owners we've checked for EKS already
        allsgowners+="${thisprefix} "

        # Check for active EKS owners 
        if active_eks_owner $thisprefix
        then
            # keep track owners of active EKS clusters
            activesgowners+="${thisprefix} "  
        fi            
    fi

    if [[ " ${activesgowners} " =~ " ${thisprefix} " ]]
    then
        x=1
        grprint 2 "Active EKS found: Skipping RDS DB Subnet Group $thisprefix for $thisprefix."
    else
        # No active EKS, so delete the keypair
        grprint 3 "Deleting RDS DB Subnet Group $thisprefix for $thisprefix."
        grprint 4 "aws rds delete-db-subnet-group --region $LOC --db-subnet-group-name $thisprefix " 
        $AWSCMD rds delete-db-subnet-group --region $LOC --db-subnet-group-name $thisprefix     # --dry-run 
    fi
done
