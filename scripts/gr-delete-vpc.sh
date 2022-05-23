#!/bin/bash

# Suss out the gel-reaper's home directory (wherever it's called from)
GRHOME_DIR="$( cd -- "$( dirname -- "${BASH_SOURCE[0]}" )" &> /dev/null && pwd )"
FUNCTION_FILE=$GRHOME_DIR/gr-functions.shinc
source <( cat ${FUNCTION_FILE}  )

# Arrays to help make repeatable loops

# Order: RouteTables NATGateways (ElasticIP?) VpcEndpoints NetworkInterfaces InternetGateways NetworkACLs SecurityGroups  
#   ec2_describes=("describe-route-tables" "describe-nat-gateways" "describe-vpc-endpoints" "describe-network-interfaces" "describe-internet-gateways" "describe-subnets" "describe-network-acls" "describe-vpc-peering-connections" "describe-security-groups" "describe-vpn-connections" "describe-vpn-gateways")
#     ec2_deletes=("delete-route-table" "delete-nat-gateway" "delete-vpc-endpoints" "delete-network-interface" "delete-internet-gateway" "delete-subnet" "delete-network-acl" "delete-vpc-peering-connection" "delete-security-group" "delete-vpn-connection" "delete-vpn-gateway")
#       ec2_greps=("RouteTableId" "NatGatewayId" "VpcEndpointId" "NetworkInterfaceId" "InternetGatewayId" "SubnetId" "NetworkAclId" "VpcPeeringConnectionId" "GroupId" "VpnConnectionId" "VpnGatewayId")
#      ec2_labels=("RouteTables" "NatGateways" "VpcEndpoints" "NetworkInterfaces" "InternetGateways" "Subnets" "NetworkACLs" "VpcPeeringConnections" "SecurityGroups" "VpnConnections" "VpnGateways")
#         ec2_ids=("route-table-id" "nat-gateway-id" "vpc-endpoint-id" "network-interface-id" "internet-gateway-id" "subnet-id" "network-acl-id" "vpc-peering-connection-id" "group-id" "vpn-connection-id" "vpn-gateway-id")
#ec2_filter_names=("vpc-id" "vpc-id" "vpc-id" "vpc-id" "attachment.vpc-id" "vpc-id" "vpc-id" "requester-vpc-info.vpc-id" "vpc-id" "vpc-id" "attachment.vpc-id")

# Remove NetworkInterfaces (deleting VPCe seems sufficient?)
   ec2_describes=("describe-route-tables" "describe-nat-gateways" "describe-vpc-endpoints" "describe-internet-gateways" "describe-subnets" "describe-network-acls" "describe-vpc-peering-connections" "describe-security-groups" "describe-vpn-connections" "describe-vpn-gateways")
     ec2_deletes=("delete-route-table" "delete-nat-gateway" "delete-vpc-endpoints" "delete-internet-gateway" "delete-subnet" "delete-network-acl" "delete-vpc-peering-connection" "delete-security-group" "delete-vpn-connection" "delete-vpn-gateway")
       ec2_greps=("RouteTableId" "NatGatewayId" "VpcEndpointId" "InternetGatewayId" "SubnetId" "NetworkAclId" "VpcPeeringConnectionId" "GroupId" "VpnConnectionId" "VpnGatewayId")
      ec2_labels=("RouteTables" "NatGateways" "VpcEndpoints" "InternetGateways" "Subnets" "NetworkACLs" "VpcPeeringConnections" "SecurityGroups" "VpnConnections" "VpnGateways")
         ec2_ids=("route-table-id" "nat-gateway-id" "vpc-endpoint-id" "internet-gateway-id" "subnet-id" "network-acl-id" "vpc-peering-connection-id" "group-id" "vpn-connection-id" "vpn-gateway-id")
ec2_filter_names=("vpc-id" "vpc-id" "vpc-id" "attachment.vpc-id" "vpc-id" "vpc-id" "requester-vpc-info.vpc-id" "vpc-id" "vpc-id" "attachment.vpc-id")


# Find and delete resources
# ------------------------------------------------------------------
# Find all VPC for this user
# Loop through each VPC to find the various resources types
# - Then loop through each resource type to delete each resource
# Then delete the VPC itself
#

# Get a list of VPC owners 
# ------------------------------------------------------------------
# Loop through the list of VPCs and find their owners
#

# build array of resources
mapfile -t array < <($AWSCMD ec2 describe-vpcs --region $LOC  --query 'Vpcs[].[VpcId,[Tags[?Key==`resourceowner`].Value][0][0],[Tags[?Key==`project_name`].Value][0][0]]' --output text)
vpcoitems=${#array[@]}          # no. of items in array

vpcowners=""
for (( i=0; i<${vpcoitems}; i++ )); 
do 
    # announce what's there
    #echo "${array[$i]}" | awk {'print $0'}   # show id, owner, project_name

    thisvpcowner=`echo "${array[$i]}" | awk {'print $2'} `

    if [[ "$thisvpcowner" != "None" ]]                          # confirm it's a real person's vpc 
    then

        if [[ " ${vpcowners} " =~ " ${thisvpcowner} " ]]
        then
            # don't add duplicates
            # grprint 4 "Duplicate VPC owner returned: skipping $thisvpcowner"
            x=1       # have to do some/anything here for syntax
        else
            vpcowners+="${thisvpcowner} "
        fi

    fi 
done

if [[ "$vpcowners" == "" ]]
then
    grprint 1 "No VPC found in region $LOC - skipping"
    exit
else
    grprint 1 "VPC owners in region $LOC:\n    $vpcowners"
fi

# Find and delete resources
# ------------------------------------------------------------------
# Loop through the list of VPC owners to find their VPCs
# Check if owner has any active EKS 
# Delete only "orphaned" VPC
#
for vpco in $vpcowners            # loop thru the list of VPC owners
do
    
    # Check for active EKS owners 
    # Note: checking here and not when building the original list of VPC owners
    #       because finding/deleting resources takes some time. It might be many
    #       minutes between creation of the initial list of VPC owners and the
    #       time when this script gets around to deleting their resources.
    if active_eks_owner $vpco
    then
        grprint 2 "Active viya4-iac resources found: skipping $vpco"
        continue    # skips the remaining commands of this loop iteration
    fi

    # Delete the VPC and dependent items for this user
    grprint 9 "\n--- `date +'%T'` --- AWS VPCs for $vpco ---------------"

    # build array of resources
    mapfile -t vpcarray < <($AWSCMD ec2 describe-vpcs --region $LOC --filters Name=tag:resourceowner,Values=$vpco --query 'Vpcs[].[VpcId,[Tags[?Key==`resourceowner`].Value][0][0],[Tags[?Key==`project_name`].Value][0][0]]' --output text)
    vpcitems=${#vpcarray[@]}          # no. of items in array
    vpcidlist=""

    for (( i=0; i<${vpcitems}; i++ ))             # loop thru the list of this owner's VPCs
    do      

        # It takes a while to delete all this, so re-confirm AWS token is valid
        if ! valid_aws_token
        then
            exit
        fi

        # announce what's there
        vpc=`echo "${vpcarray[$i]}" | awk {'print $1'} `

        grprint 2 "${vpcarray[$i]}" | awk {'print $0'}        # show id, owner, project_name

        for (( j=0; j<${#ec2_describes[@]}; j++ ))            # loop thru the various resources types for this VPC
        do

            # Some resources need additional filtering
            case ${ec2_labels[$j]} in 
                NetworkACLs)
                        # Only capture the non-default nACLs (cannot delete those)
                    ### Use the ec2_ arrays to build the CLI commands we want for each resource type
                    mapfile -t array < <($AWSCMD ec2 ${ec2_describes[$j]} --filters "Name=default,Values=false" "Name=${ec2_filter_names[$j]},Values=$vpc" | grep ${ec2_greps[$j]} | awk -F\" {'print $4'})
                ;;

                *)
                        # For everything else, use the same pattern
                    ### Use the ec2_ arrays to build the CLI commands we want for each resource type
                    mapfile -t array < <($AWSCMD ec2 ${ec2_describes[$j]} --filter "Name=${ec2_filter_names[$j]},Values=$vpc" | grep ${ec2_greps[$j]} | awk -F\" {'print $4'})
                ;;
            esac

            # Count the items in the array and announce what we found
            items=${#array[@]}
            grprint 3 "${items} ${ec2_labels[$j]} in VPC $vpc for owner $vpco in region $LOC:"

            this_list=()
            for (( k=0; k<${items}; k++ ))             # loop thru the list of resources of this type
            do
                this_id=`echo "${array[$k]}" | awk {'print $1'}`

                if [[ " ${this_list[@]} " =~ " ${this_id} " ]]
                then
                    # don't add duplicates
                    #grprint 4 "Duplicate id returned: skipping $this_id"
                    x=1
                else
                
                    # Some resources need a deeper look to handle their situation
                    case ${ec2_labels[$j]} in
                        SecurityGroups)
                            sg=$($AWSCMD ec2 describe-security-groups --filter "Name=group-id,Values=$this_id" | grep GroupName | awk -F\" {'print $4'})
                            if [[ "$sg" = "default" ]]
                            then
                                grprint 4 "Default security group: skipping $this_id"
                                # not adding this_(SecurityGroup)_id to the list
                            else

                                # build array of Security Group Rules for this one Security Group
                                # (cannot have one SG referring to another in its rules)
                                mapfile -t sgrarray < <($AWSCMD ec2 describe-security-group-rules --region $LOC --filter Name=group-id,Values=$this_id --query SecurityGroupRules[].[SecurityGroupRuleId,IsEgress] --output text)
                                grprint 4 "- ${#sgrarray[@]} Ingress Security Group Rules for $this_id:"

                                for (( m=0; m<${#sgrarray[@]}; m++ ))
                                do
                                    sgrid=`echo ${sgrarray[$m]} |  awk {'print $1'}`         # id 
                                    sgregress=`echo ${sgrarray[$m]} |  awk {'print $2'}`     # boolean

                                    if [ "$sgregress" = "True" ]
                                    then
                                        grprint 4 " - `expr $m + 1` of ${#sgrarray[@]}: Skipping egress rule: $sgrid"
                                    else
                                        # Delete (revoke) ingress rules for this SG (so it won't refer to another SG)
                                        grprint 4 " - `expr $m + 1` of ${#sgrarray[@]}: aws ec2 revoke-security-group-ingress --group-id $this_id --security-group-rule-ids $sgrid"
                                        $AWSCMD ec2 revoke-security-group-ingress --group-id $this_id --security-group-rule-ids $sgrid
                                    fi
                                done

                                # Now the ingress rules are revoked, add this_(SecurityGroup)_id to the list for deletion
                                this_list+=("${this_id} ")

                            fi
                        ;;

                        *)
                            # Go ahead and add this_(whatever)_id to the list
                            this_list+=("${this_id} ")
                        ;;
                    esac

                fi

            done

            for (( k=0; k<${#this_list[@]}; k++ ))             # loop thru the list of resources and delete 
            do

                # Some resources need special handling before deleting
                case ${ec2_labels[$j]} in
                    InternetGateways)
                        # Detach IG before delete
                        grprint 4 "- `expr $k + 1` of ${#this_list[@]}: aws detach-internet-gateway --region $LOC --vpc-id $vpc --${ec2_ids[$j]} ${this_list[$k]}"
                        $AWSCMD ec2 detach-internet-gateway --region $LOC --vpc-id $vpc --${ec2_ids[$j]} ${this_list[$k]}   #--dry-run
                    # allow "normal" delete to get the IG 
                    ;;

                    RouteTables)
                        # Disassociate route tables first - get list of assoc-ids and delete
                        # https://docs.aws.amazon.com/cli/latest/reference/ec2/describe-route-tables.html
                        # https://docs.aws.amazon.com/cli/latest/reference/ec2/disassociate-route-table.html

                        this_rt=${this_list[$k]}   # This route table

                        ### Need more info about this route table's associations
                        mapfile -t rtarray < <($AWSCMD ec2 describe-route-tables --filters "Name=${ec2_filter_names[$j]},Values=$vpc" "Name=route-table-id,Values=$this_rt" --query RouteTables[].Associations[].[RouteTableAssociationId,Main] --output text)
                        rtitems=${#rtarray[@]}
                        grprint 4 "- ${rtitems} Associations for Route Table $this_rt:"

                        this_rtlist=()
                        for (( m=0; m<${rtitems}; m++ ))             # loop thru the list of route table association ids
                        do
        
                            this_rtaid=`echo "${rtarray[$m]}" | awk {'print $1'}`
                            this_rtmain=`echo "${rtarray[$m]}" | awk {'print $2'}`

                            if [[ " ${this_rtlist[@]} " =~ " ${this_rtaid} " ]]
                            then
                                # don't add duplicates
                                #grprint 4 "- Duplicate RTA-id returned: skipping $this_rtaid"
                                x=1
                            else
                                if [ "$this_rtmain" = "True" ]
                                then
                                    grprint 4 " - `expr $m + 1` of ${rtitems}: Main route table ${this_list[$k]}: skipping $this_rtaid"
                                    continue 2     # cannot delete main table - so jump the outerloop ${this_list[@]}
                                else
                                    # Disassociate the route table so it can be deleted 
                                    grprint 4 " - `expr $m + 1` of ${rtitems}: aws ec2 disassociate-route-table --association-id ${this_rtaid}"
                                    $AWSCMD ec2 disassociate-route-table --association-id ${this_rtaid}   #--dry-run

                                    this_rtlist+=("${this_rtaid} ")
                                fi
                            fi

                        done
                    # allow "normal" delete to get the route tables themselves
                    ;;

                    NetworkACLs)
                        # Dont specify region when deleting nACL - run command here, then 'continue' loop"
                        # https://docs.aws.amazon.com/cli/latest/reference/ec2/delete-network-acl.html
                        grprint 4 "`expr $k + 1` of ${#this_list[@]}: aws ec2 ${ec2_deletes[$j]} --${ec2_ids[$j]} ${this_list[$k]}"
                        $AWSCMD ec2 ${ec2_deletes[$j]} --${ec2_ids[$j]} ${this_list[$k]}   #--dry-run
                        continue       
                    # "continue" to skip past the "normal" delete command below
                    ;;

                    *)
                    ;;

                esac

                # 
                # This is the main delete for VPC-dependent resources
                #
                try=0
                while [ $try -lt 9 ]
                do
                    # "Normal" delete commands for the ec2_ array items
                    grprint 4 "`expr $k + 1` of ${#this_list[@]}: aws ec2 ${ec2_deletes[$j]} --region $LOC --${ec2_ids[$j]} ${this_list[$k]}"
                    result=$( $AWSCMD ec2 ${ec2_deletes[$j]} --region $LOC --${ec2_ids[$j]} ${this_list[$k]} 2>&1 )
                    retc=$?
                    if [ $retc -eq 0 ] 
                    then
                        try=99  # Success, quit the loop   
                    else                            # hide nominal results from delete
                        grprint 4 "${result}"       # but when there's an error, echo the output
                        grprint 0 "(rc=$retc): SLEEPING 10 seconds before RETRY No. `expr $try + 1`..."
                        sleep 10
                        ((try=try+1))
                    fi
                done

                if [ $retc -ne 0 ]
                then
                    grprint 0 "FAILED: ${ec2_deletes[$j]} --region $LOC --${ec2_ids[$j]} ${this_list[$k]} "
                fi

                # Some resources need special handling after delete
                case ${ec2_labels[$j]} in
                    *)
                    ;;
                esac

            done

        done  # resource types

        #
        # This deletes the VPC itself after everything above
        #
        try=0
        while [ $try -lt 9 ]
        do
            grprint 2 "Deleting VPC $vpc for owner $vpco in region $LOC:"
            grprint 3 "aws ec2 delete-vpc --region $LOC --vpc-id $vpc "
            $AWSCMD ec2 delete-vpc --region $LOC --vpc-id $vpc     #--dry-run
            retc=$?
            if [ $retc -eq 0 ] 
            then 
                break  # Success, quit the loop
            else 
                grprint 0 "(rc=$retc): SLEEPING 10 seconds before RETRY No. `expr $try + 1`..."
                sleep 10
                ((try=try+1))
            fi
        done

        if [ $retc -ne 0 ]
        then
            grprint 3 "FAILED: delete-vpc --region $LOC --vpc-id $vpc"
        else
            grprint 3 "SUCCESS: delete-vpc --region $LOC --vpc-id $vpc"
        fi

        grprint 2 "End: VPC $vpc --------------------------------------------"

    #break                    # useful to run against just 1 VPC
    done  # owner's VPCs

#break                     # useful to run against just 1 owner
done   # all VPC owners
