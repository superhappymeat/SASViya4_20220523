#!/bin/bash

# Suss out the gel-reaper's home directory (wherever it's called from)
GRHOME_DIR="$( cd -- "$( dirname -- "${BASH_SOURCE[0]}" )" &> /dev/null && pwd )"
FUNCTION_FILE=$GRHOME_DIR/gr-functions.shinc
source <( cat ${FUNCTION_FILE}  )

##
## MAIN
##

grprint 9 "\n--- `date +'%T'` --- AWS IAM OIDC Providers -------------"

# Confirm AWS token is valid before running (and again later)
if ! valid_aws_token
then
    exit
fi

grprint 1 "Finding IAM OIDC Providers"

# OIDC Providers provisioned by the IaC 
mapfile -t array < <($AWSCMD iam list-open-id-connect-providers --query OpenIDConnectProviderList[].[Arn] --output text)
items=${#array[@]}          # no. of items in array

allowners=""
activeowners=""
for (( i=0; i<${items}; i++ )); 
do 
    thisarn=${array[$i]}
    thisowner=$($AWSCMD iam get-open-id-connect-provider --open-id-connect-provider-arn $thisarn --query 'Tags[?Key==`resourceowner`].Value' --output text)

    if [[ "${thisowner}" == "" ]]
    then
        grprint 2 "No resourceowner found: Skipping IAM OIDC Provider $thisarn."
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
        grprint 2 "Active EKS found: Skipping IAM OIDC Provider $thisarn for $thisowner."
    else
        # No active EKS, so delete the OIDC Provider
        grprint 3 "Deleting IAM OIDC Provider $thisarn for $thisowner."
        grprint 4 "aws iam delete-open-id-connect-provider --open-id-connect-provider-arn $thisarn" 
        $AWSCMD iam delete-open-id-connect-provider --open-id-connect-provider-arn $thisarn     # --dry-run 
    fi
done
