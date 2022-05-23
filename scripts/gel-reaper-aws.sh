#!/bin/bash

# ------------------------------------------------------------------------
#   __|  __|  |       _ \  __|    \    _ \ __|  _ \      \ \ \      /  __| 
#  (_ |  _|   |    _    /  _|    _ \   __/ _|     / _   _ \ \ \ \  / \__ \ 
# \___| ___| ____|   _|_\ ___| _/  _\ _|  ___| _|_\   _/  _\ \_/\_/  ____/ 
#                                                   
# About: 
# The GEL-REAPER-AWS utility deletes items left behind in AWS after the CLOUD-NUKE utility
# has removed many components. Primarily focused on the EC2 VPC as some of those resources
# continue to accrue cost over time until they're deleted, but also deleting other items
# like RDS DB Subnet Groups, IAM Policies and Roles, Identity Providers and EC2 Keypairs. 
#
# Intended specifically for use with SAS Viya software deployments using the AWS Elastic 
# Kubernetes Service that were provisioned using the SAS VIYA4-IAC-AWS project. Expects 
# that most items will have a "resourceowner" tag as well as a consistent naming "PREFIX". 
# ------------------------------------------------------------------------

# Suss out the gel-reaper's home directory (wherever it's called from)
GRHOME_DIR="$( cd -- "$( dirname -- "${BASH_SOURCE[0]}" )" &> /dev/null && pwd )"
FUNCTION_FILE=$GRHOME_DIR/gr-functions.shinc
source <( cat ${FUNCTION_FILE}  )

##
## MAIN
##

start_time=$SECONDS
grprint 0 "--- GEL-REAPER --- `date` ---"

# Confirm AWS token is valid before running (and again later)
you=`$AWSCMD sts get-caller-identity --query Arn --output text 2>&1`
retc=$?

if [ "$retc" != "0" ]
then
    grprint 9 "'aws sts get-caller-identity' returned:"
    grprint ERR "$you"
    grprint 9 "ERROR: Unable to confirm authentication to AWS (rc=$retc).\n"
    exit
else
    grprint 0 "AWS identity: $you"
fi

# Delete resources which don't have active EKS cluster

    cd $GRHOME_DIR/

    # Delete VPCs (& dependent items)
    ./gr-delete-vpc.sh 

    # Delete RDS DB Subnet Groups 
    ./gr-delete-rds-subnet-groups.sh 
 
    # Delete IAM Roles (& Policies & Identity Providers)
    ./gr-delete-iam-roles.sh

    # Delete IAM OIDC Providers 
    ./gr-delete-iam-oidc-providers.sh

    # Delete EC2 Key Pairs
    ./gr-delete-ec2-keypairs.sh 

    # Delete Resource Groups
    ./gr-delete-resource-groups.sh

    # Delete ECR Repos
    ./gr-delete-ecr-repositories.sh

# Wrap up
elapsed=$(( SECONDS - start_time ))
etmsg=$(elapsedtime $elapsed)
grprint 0 "--- GEL-REAPER --- $etmsg ---"
