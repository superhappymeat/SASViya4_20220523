#!/bin/bash

# ATTENTION: This script is not part of GELLOW execution. It is used by a "Gelkins" job
#            to keep the AWS tokens up-to-date for the students.
#            http://gelkins.race.sas.com:8080/job/AWS/job/kinit-getawskey/

# For SAS use, AWS relies on the SAS Active Directory Federated Server (SASADFS). So ensure
# this script runs on a host with network access to SASADFS. If configuring, see the requirements:
# https://sas.service-now.com/kb?id=kb_article_view&sysparm_article=KB0027303&sys_kb_id=6ade026b1b55d410536add7edd4bcb70&spa=1#Requirements

# The glsuser2 account is used in GEL workshops to provide read-only access to file shares.
# Using it here for SASADFS authentication. 
kinit -kt ${GLSUSER2KEYTAB} glsuser2@NA.SAS.COM
klist
# The GLSUSER2KEYTAB is saved in Jenkins as a "secret file" and referenced here

# Specifying the role ARN for the sas-salesenabletest account in AWS
[[ -d .aws ]] || mkdir .aws
tee .aws/awskeyconfig > /dev/null << EOF
[default]
principal_arn = arn:aws:iam::182696677754:saml-provider/SASADFS
role_arn      = arn:aws:iam::182696677754:role/testers
output        = json
region        = us-east-1
EOF

# The getawskey utility is used inside SAS (relying on SASADFS) to authenticate to AWS
getawskey -file .aws/awskeyconfig -duration 4000   # the Gelkins job runs every 3,600s
aws sts get-caller-identity  --output table

# Capture the AWS token info and save to file
AWS_ACCESS_KEY_ID=`aws configure get aws_access_key_id`
AWS_SECRET_ACCESS_KEY=`aws configure get aws_secret_access_key`
AWS_SESSION_TOKEN=`aws configure get aws_session_token`

echo "Creating the AWS credentials file..."
# credentials file
[[ -f .aws/credentials ]] && rm .aws/credentials 
tee  .aws/credentials > /dev/null << EOF
# generated for GEL workshop using getawskey
[default]
aws_secret_access_key = ${AWS_SECRET_ACCESS_KEY}
aws_access_key_id     = ${AWS_ACCESS_KEY_ID}
aws_session_token     = ${AWS_SESSION_TOKEN}
EOF

# The glsuser1 account is used in GEL workshops to provide read-write access to file shares.
# Copy the updated AWS token files over to NAGEL01 file server where it'll be
# mounted and referenced by RACE machines used by the GEL workshop
scp -o StrictHostKeyChecking=no -i $GLSUSER1SSH -r .aws glsuser1@gelweb01.race.sas.com:/r/nagel01/vol/gel/gate/workshops/PSGEL297_001/glsuser2-kinit-getawskey/
# The GLSUSER1SSH is a private SSH key saved in Jenkins and referenced here. 

# End
# This script is done. From here GELLOW is expected to mount the NAGEL01 location on the RACE 
# host(s) at /home/cloud-user/.aws. That way, every student will automatically have active 
# AWS tokens to allow utilities like the AWS CLI and Terraform to operate. 
