#!/bin/bash

# Suss out the gel-reaper's home directory (wherever it's called from)
GRHOME_DIR="$( cd -- "$( dirname -- "${BASH_SOURCE[0]}" )" &> /dev/null && pwd )"
FUNCTION_FILE=$GRHOME_DIR/gr-functions.shinc
source <( cat ${FUNCTION_FILE}  )

##
## MAIN
##

grprint 9 "\n--- `date +'%T'` --- AWS ECR Repositories -------------"

# Confirm AWS token is valid before running (and again later)
if ! valid_aws_token
then
    exit
fi

grprint 1 "Finding ECR Repositories"

# ECR Repositories provisioned by the IaC 
mapfile -t array < <($AWSCMD ecr describe-repositories --query repositories[].[repositoryName,createdAt,repositoryArn] --output text)
items=${#array[@]}          # no. of items in array

now=`date +%s`        # current datetime in seconds since 1970 epoch

for (( i=0; i<${items}; i++ )); 
do 
    thisname=`echo "${array[$i]}" | awk {'print $1'}`    # repositories[].[repositoryName]
    thistime=`echo "${array[$i]}" | awk {'print $2'}`    # repositories[].[createdAt]  - in seconds since 1970 epoch
    thisarn=`echo "${array[$i]}" | awk {'print $3'}`     # repositories[].[repositoryArn]

    thistime=`echo ${thistime} | awk -F. {'print $1'}`   # drop the decimal
    thisage=`expr ${now} - ${thistime}`                  # age of this repo 

    if [[ ${thisage} -gt ${MAX_AGE} ]]
    then
        grprint 3 "Deleting ECR Repository $thisname (age=${thisage}s)."
        grprint 4 "aws ecr delete-repository --repository-name $thisname --force" 
        result=$( ${AWSCMD} ecr delete-repository --repository-name ${thisname} --force 2>&1 )
        if [[ $? -ne 0 ]]
        then                            # hide the nominal results
            grprint 4 "${result}"       # but when there's an error, echo the output
        fi
    else
        grprint 2 "Too young: Skipping ECR Repository $thisname (${thisage}s < ${MAX_AGE}s)."
    fi
done