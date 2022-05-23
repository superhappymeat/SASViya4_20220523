#!/bin/bash

# Suss out the gel-reaper's home directory (wherever it's called from)
GRHOME_DIR="$( cd -- "$( dirname -- "${BASH_SOURCE[0]}" )" &> /dev/null && pwd )"
FUNCTION_FILE=$GRHOME_DIR/gr-functions.shinc
source <( cat ${FUNCTION_FILE}  )


##
## MAIN
##

grprint 9 "\n--- `date +'%T'` --- AWS IAM Roles & Policies & Instance Profiles ------------------------"

# Confirm AWS token is valid before running (and again later)
if ! valid_aws_token
then
    exit
fi

grprint 1 "Finding IaC roles for (userPrefix)-eks(date)|(userPrefix)-cluster-autoscaler|terraform-(date)"

# Roles named with "-eks" or "-cluster-autoscaler" provisioned by the IaC 
mapfile -t array < <($AWSCMD iam list-roles --query 'Roles[].[RoleName,RoleId,Arn]' --output text | grep -E "\-eks|cluster-autoscaler|terraform-20")
roleitems=${#array[@]}          # no. of items in array

allroleowners=""
activeroleowners=""
for (( i=0; i<${roleitems}; i++ )); 
do 
    # announce what's there
    #echo "${array[$i]}" | awk {'print $0'}   # roleid,  name, arn

    thisrolename=`echo ${array[$i]} | awk {'print $1'} `              # Roles[].[RoleName]
    thisroleid=`echo ${array[$i]} | awk {'print $2'} `                # Roles[].[RoleId]
    thisrolearn=`echo ${array[$i]} | awk {'print $3'} `               # Roles[].[Arn]

    if [[ "$thisrolename" =~ "terraform-" ]]
    then
        # When the prefix is "terraform-(date)"
        #thisprefix=`echo "${array[$i]}" | awk 'BEGIN { FS = ":role/" } {print $2}'`    # Pull the prefix from the Arn
        thisprefix="terraform"
    else 
        # When the prefix is "PREFIX-eks-(and so on)"
        thisprefix=`echo "${array[$i]}" | awk -F"-eks" {'print $1'} `                  # Roles[].[RoleName] (just the prefix)
    fi

    # By default, expect the prefix is the owner name
    thisresowner=$thisprefix

    # Use the role arn to get the actual resourceowner tag value (if it has one)
    # thisresowner=$($AWSCMD iam get-role --role-name $thisrole --query 'Role[].[[Tags[?Key==`resourceowner`].Value][0][0]]')
    ##
    ## BUG: it looks like get-role only returns NULL for *any* query
    ##
    # So get *full policy json*, find the resourceowner line, then grab its value from the *next* line

    mapfile -t rolearray < <($AWSCMD iam get-role --role-name $thisrolename)
    rolelines=${#rolearray[@]}     # no. of lines returned

    valueline=-1    # init for this loop iteration
    for (( j=0; j<${rolelines}; j++));
    do

        # find the resourceowner line, then grab its value from the next line
        thisline=`echo ${rolearray[$j]} | grep resourceowner`
        if [[ "$thisline" != "" ]]
        then
            # found the resourceowner tag line, the following line has its value
            valueline=`expr $j + 1`
        fi

        thisline=`echo ${rolearray[$j]}`
        if [[ "$j" = "$valueline" ]]
        then
            # Now we know the resourceowner  ( "Value:" "UserName" )
            thisresowner=`echo $thisline | awk -F: {'print $2'} | awk -F'"' {'print $2'}`
            break
        fi

    done

    # Check if active EKS
    if [[ " ${allroleowners} " =~ " ${thisresowner} " ]]
    then
        # already checked the active EKS status of this owner
        x=1
    else
        # keep track of which role owners we've checked for EKS already
        allroleowners+="${thisresowner} "

        # Check for active EKS owners 
        if active_eks_owner $thisresowner
        then
            # keep track owners of active EKS clusters
            activeroleowners+="${thisresowner} "  
        fi            
    fi

    # Delete Roles and dependent Policies and Instance Profiles
    if [[ " ${activeroleowners} " =~ " ${thisresowner} " ]]
    then
        x=1
        grprint 2 "Active EKS found: Skipping role $thisrolename for $thisresowner."
    else
        grprint 0 "Role $thisrolename for owner $thisresowner."

        # Find any Managed Policies 
        mapfile -t polarray < <($AWSCMD iam list-attached-role-policies --role-name $thisrolename --query AttachedPolicies[].[PolicyName,PolicyArn] --output text)
        politems=${#polarray[@]}     # no. of policies returned


        grprint 2 "Role $thisrolename has $politems Managed Policies attached."

        for (( k=0; k<${politems}; k++ ));
        do
            # get the PolicyArn
            thisitem=`echo ${polarray[$k]} | awk {'print $2'}`       # AttachedPolicies[].[PolicyArn]
            if [[ "$thisitem" != "" ]]
            then
                grprint 3 "`expr $k + 1` of ${politems}: Detach policy $thisitem from role $thisrolename."
                grprint 4 "aws iam detach-role-policy --role-name $thisrolename --policy-arn $thisitem " 
                $AWSCMD iam detach-role-policy --role-name $thisrolename --policy-arn $thisitem 

                # don't want to try and delete default AWS policies (or gel policies)
                if [[ "${thisitem}" =~ ":policy/${thisresowner}-" ]]
                then
                    grprint 4 "`expr $k + 1` of ${politems}: Delete policy $thisitem."
                    grprint 4 "aws iam delete-policy --policy-arn $thisitem " 
                    $AWSCMD iam delete-policy --policy-arn $thisitem 
                else
                    grprint 4 "`expr $k + 1` of ${politems}: Non-Role Specific Policy: Will not delete $thisitem."
                fi
            fi
        done

        # Find any Instance Profiles 
        mapfile -t iparray < <($AWSCMD iam list-instance-profiles-for-role --role-name $thisrolename --query InstanceProfiles[].[InstanceProfileName] --output text)
        ipitems=${#iparray[@]}     # no. of instance profiles returned
        
        grprint 2 "Role $thisrolename has $ipitems Instance Profiles attached."

        for (( k=0; k<${ipitems}; k++ ));
        do
            # get the InstanceProfileName
            thisitem=`echo ${iparray[$k]} | awk {'print $1'}`       # InstanceProfiles[].[InstanceProfileName]
            if [[ "$thisitem" != "" ]]
            then
                grprint 3 "`expr $k + 1` of ${ipitems}: Remove role $thisrolename from Instance Profile $thisitem ."
                grprint 4 "aws iam remove-role-from-instance-profile --role-name $thisrolename --instance-profile-name $thisitem " 
                $AWSCMD iam remove-role-from-instance-profile --role-name $thisrolename --instance-profile-name $thisitem 
                
                grprint 4 "`expr $k + 1` of ${ipitems}: Delete Instance Profile $thisitem."
                grprint 4 "aws iam delete-instance-profile --instance-profile-name $thisitem " 
                $AWSCMD iam delete-instance-profile --instance-profile-name $thisitem 
            fi
        done

        grprint 1 "Deleting role $thisrolename for $thisresowner."
        grprint 4 "aws iam delete-role --role-name $thisrolename " 
        $AWSCMD iam delete-role --role-name $thisrolename 
    fi

done
