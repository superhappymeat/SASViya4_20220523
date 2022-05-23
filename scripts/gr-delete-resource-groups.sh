#!/bin/bash

# Suss out the gel-reaper's home directory (wherever it's called from)
GRHOME_DIR="$( cd -- "$( dirname -- "${BASH_SOURCE[0]}" )" &> /dev/null && pwd )"
FUNCTION_FILE=$GRHOME_DIR/gr-functions.shinc
source <( cat ${FUNCTION_FILE}  )

##
## MAIN
##

grprint 9 "\n--- `date +'%T'` --- AWS Resource Groups -------------"

# Confirm AWS token is valid before running (and again later)
if ! valid_aws_token
then
    exit
fi

grprint 1 "Finding Resource Groups"

# Resource Groups provisioned by the IaC 
mapfile -t array < <($AWSCMD resource-groups list-groups --region $LOC --output text | grep GROUPIDENTIFIERS)
items=${#array[@]}          # no. of items in array

allowners=""
activeowners=""
for (( i=0; i<${items}; i++ )); 
do 
    thisarn=`echo "${array[$i]}" | awk {'print $2'}`     # RG ARN
    thisname=`echo "${array[$i]}" | awk {'print $3'}`    # RG Name (PREFIX-rg)
    thisowner=`echo $thisname | awk -F- {'print $1'}`    # The PREFIX used to name the rg

    if [[ "${thisowner}" == "" ]]
    then
        grprint 2 "No resourceowner found: Skipping Resource Group $thisarn."
        continue        # iterate the loop 
    fi

    if [[ " ${allowners} " =~ " ${thisowner} " ]]
    then
        # already checked the active EKS status of this owner
        x=1
    else
        # keep track of which policy owners we've checked for EKS already
        allowners+="${thisowner} "

        # Check for active EKS owners 
        if active_eks_owner $thisowner
        then
            # keep track owners of active EKS clusters
            activeowners+="${thisowner} "  
        fi            
    fi

    if [[ " ${activeowners} " =~ " ${thisowner} " ]]
    then 
        grprint 2 "Active EKS found: Skipping Resource Group $thisarn for $thisowner."
    else
        # No active EKS, so delete the OIDC Provider
        grprint 3 "Deleting Resource Group $thisarn for $thisowner."
        grprint 4 "aws resource-groups delete-group --group $thisarn" 
        result=$( $AWSCMD resource-groups delete-group --group $thisarn  2>&1 )   
        if [[ $? -ne 0 ]]
        then                            # hide the nominal results
            grprint 4 "${result}"       # but when there's an error, echo the output
        fi
    fi
done
