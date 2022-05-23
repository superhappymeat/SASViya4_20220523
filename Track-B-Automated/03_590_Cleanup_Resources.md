![Global Enablement & Learning](https://gelgitlab.race.sas.com/GEL/utilities/writing-content-in-markdown/-/raw/master/img/gel_banner_logo_tech-partners.jpg)

# Cleanup the resources in AWS

- [Environment preparation](#environment-preparation)
- [Uninstall SAS Viya](#uninstall-sas-viya)
- [Destroy the AWS resources](#destroy-the-aws-resources)
- [Navigation](#navigation)
## Environment preparation

We've been using some environment variables and command aliases in other exercises. Ensure they're setup for use here, too. 

* Prepare the environment

  ```bash
  # as cloud-user on your Linux host in RACE

  # Aliases for utilities run inside viya4-iac-aws Docker container
  alias aws="docker container run --rm --group-add root --user $(id -u):$(id -g) -v $HOME/.aws:/.aws --entrypoint aws viya4-iac-aws"

  alias terraform="docker container run --rm --group-add root --user $(id -u):$(id -g) -v $HOME/.aws:/.aws -v $HOME/.ssh:/.ssh -v $HOME/viya4-iac-aws:/workspace --entrypoint terraform viya4-iac-aws"

  alias viya4-deployment="docker container run -it --group-add root --user $(id -u):$(id -g) -v $HOME/project/deploy:/data -v $HOME/.kube/config:/config/kubeconfig -v $HOME/project/deploy/${NS}/${NS}-viyavars.yaml:/config/config -v $HOME/viya4-iac-aws/${NS}.tfstate:/config/tfstate viya4-deployment"

  # You and your project namespace
  NS=`cat ~/MY_NS.txt`
  MY_PREFIX=`cat ~/MY_PREFIX.txt`
  MY_PREFIX=${MY_PREFIX,,}        # convert to all lower-case
  echo -e "\nYour PREFIX for names/tags in AWS is: ${MY_PREFIX}."
  ```

## Uninstall SAS Viya

When you're done with using SAS Viya - or if you want to redeploy from scratch - then you're ready to uninstall the SAS Viya software from the EKS cluster.

* Remove SAS Viya software from the Kubernetes cluster in AWS

   ```bash
   # as cloud-user on your Linux host in RACE

   # Unnstall SAS Viya 4
   viya4-deployment --tags "baseline,viya,uninstall"

   # Or if you deployed SAS Viya 4 with full monitoring
   viya4-deployment --tags "baseline,viya,cluster-logging,cluster-monitoring,viya-monitoring,uninstall"
   ```

## Destroy the AWS resources 

This is an important step - some of [these resources cost money](https://calculator.aws/#/) just by existing! When you're done with this workshop, please ensure all of your resources have been destroyed. 

* Destroy the AWS infrastructure using Terraform

  ```bash
  # as cloud-user on your Linux host in RACE
  cd ~/viya4-iac-aws

  # Delete all AWS resources created by the Terraform plan and tracked in the Terraform state file.
  TFVARS=/workspace/sasviya4aws.tfvars    # path inside the container
  TFSTATE=/workspace/sasviya4aws.tfstate  # path inside the container

  # terraform destroy
  terraform destroy -auto-approve \
    -var-file ${TFVARS} \
    -state ${TFSTATE}

  # Only after SUCCESSFUL destroy, then
  # remove the TF state, so next time we start clean
  #rm ~/viya4-iac-aws/sasviya4aws.tfstate
  ```

* If, for some reason, Terraform is unable to tear down your environment in AWS, then refer to the GEL blog post _[Manually destroying AWS infrastructure for SAS Viya](http://sww.sas.com/blogs/wp/gate/44278/manually-destroying-aws-infrastructure-for-sas-viya/rocoll/2021/05/06)_ for additional guidance.

* To keep costs manageable, this workshop also employs an automated process which destroys any resources when they're too old (usually ~1 day or less).

# End

You've uninstalled SAS Viya and destroyed your AWS resources. 

## Navigation

<!-- startnav -->
* [00 001 Access Environments](/00_001_Access_Environments.md)
* [README](/README.md)
* [Track B-Automated / 03 510 Provision Resources](/Track-B-Automated/03_510_Provision_Resources.md)
* [Track B-Automated / 03 520 Deploy SAS Viya](/Track-B-Automated/03_520_Deploy_SAS_Viya.md)
* [Track B-Automated / 03 590 Cleanup Resources](/Track-B-Automated/03_590_Cleanup_Resources.md)**<-- you are here**
<!-- endnav -->
