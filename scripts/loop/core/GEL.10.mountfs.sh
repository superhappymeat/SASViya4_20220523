#!/bin/sh
###############################################################################
#        Name: GEL mountfs.sh                                                 #
# Description: Ensure necessary fs are mounted on sasnode hosts               #
#     Assumes: /etc/ansible/hosts file exists with grid hostnames             #
# --------------------------------------------------------------------------- #
# Rob Collum,        Initial release,                                JUL-2021 #
###############################################################################
#set -x

# Get common collateral ------------------------------------------------
FUNCTION_FILE=/opt/gellow_code/scripts/common/common_functions.shinc
source <( cat ${FUNCTION_FILE}  )

WORKSHOP="PSGEL297_001"

# Define and mount fs ------------------------------------------------
mount_it_all () {

    # nagel01 EXPORTS:
    #   /vol/gel/gate/workshops/PSGEL297_001/glsuser2-kinit-getawskey/.aws       *(rw,sync,no_root_squash)
    #
    # sasnode01 MOUNTS:
    #   /home/cloud-user/.aws                                                    ro,defaults 0 0

    # Define mount to the AWS credential files (all sasnode## hosts)
    HOSTS="sasnodes"
    FS="nagel01.unx.sas.com:/vol/gel/gate/workshops/${WORKSHOP}/glsuser2-kinit-getawskey/.aws"
    MNT="/home/cloud-user/.aws"

    logit "Defining mount ${FS} on [${HOSTS}]"

    # Ensure the mount point is created
    # Update /etc/fstab with the mount
    #
    ansible $HOSTS   -m file \
                     -a "path=${MNT} state=directory" -b

    ansible $HOSTS   -m lineinfile \
                     -a "dest=/etc/fstab \
                         line='${FS} ${MNT} nfs ro,defaults 0 0' \
                         state=present"  -b


    # Mount the newly defined fs on all hosts
    HOSTS="sasnodes"
    logit "Mounting all fs"
    ansible $HOSTS   -m shell \
                     -a "mount -a" -b

}

# Decide what this script will do ------------------------------------------------
case "$1" in
    'enable')
        mount_it_all
    ;;
    'validate')
        #no-op
    ;;
    'start')
        mount_it_all
    ;;
    'clean')
        #no-op
    ;;
    *)
        printf "\nThe parameter '$1' does not do anything in the script '`basename "$0"`' \n"
        exit 0
    ;;
esac
