![Global Enablement & Learning](https://gelgitlab.race.sas.com/GEL/utilities/writing-content-in-markdown/-/raw/master/img/gel_banner_logo_tech-partners.jpg)

# SAS Viya 4 - Deployment on Amazon Elastic Kubernetes Service

**PSGEL297: SAS Viya 4 - Deployment on Amazon Elastic Kubernetes Service**

```log
Cadence : stable
Version : 2021.2.5
```

---

* [One deployment, but 3 Methods](#one-deployment-but-3-methods)
* [Deployment learning path](#deployment-learning-path)
* [Structure and content](#structure-and-content)
* [Clean up - why ?](#clean-up---why-)
* [Next steps](#next-steps)
* [Complete Hands-on Navigation Index](#complete-hands-on-navigation-index)

Welcome to the SAS Viya 4 - Deployment on Amazon Elastic Kubernetes Service (EKS) workshop. This README provides an overview of the workshop structure and the exercises that can be undertaken.

## One deployment, but 3 Methods

* There are several deployment methods for Viya: **manual deployment**, **deployment operator** (SAS preferred method) and **automated deployment with ansible** ([viya4-deployment](https://github.com/sassoftware/viya4-deployment) GitHub project).

* There are also several options to build and prepare the underlying Kubernetes cluster for a Viya deployment.

* Each deployment method comes with it's unique possibilities and requirements for deploying and maintaining the resultant environment.

To help clarify the deployment methods and paths to a successful Viya deployment, we have organized the "Cloud Provider" lab hands-on a specific way that is described below.

## Deployment learning path

**The goal of this hands-on organization is to help you better understand and test the various deployment paths.**

![learningpath](/img/workshop_structure.png)

## Structure and content

To support the three deployment paths, and the two learning tracks (learning paths), the Git project is organised with the following structure.

```log
├── README (Get an overview of the Hands-on organization)
├── 00_001_Access_environments.md
├── 00_999_Fast_track_with_cheatcodes.md (instructions on how to generate the cheatcodes)
|
├── Track-A-Standard
|      ├── 00-Common
│      |      ├── 00_100_Creating_an_EKS_Cluster.md (**THIS EXERCISE IS STILL UNDER CONSTRUCTION**)
│      |      ├── 00_110_Performing_the_prerequisites.md (**THIS EXERCISE IS STILL UNDER CONSTRUCTION**)
|      |      └── 00_400_Cleanup.md (**THIS EXERCISE IS STILL UNDER CONSTRUCTION**)
|      |
│      ├── 01-Manual (perform these set of instructions to follow the Standard / Manual Deployment method)
│      │      └── 01_200_Deploying_Viya_4_on_EKS.md (**THIS EXERCISE IS STILL UNDER CONSTRUCTION**)

|      |
│      └── 02-DepOp (perform these set of instructions to follow the Standard / Deployment Operator method)
│             ├── 02_300_Deployment_Operator_environment_set-up.md (**THIS EXERCISE IS STILL UNDER CONSTRUCTION**)
│             ├── 02_310_Using_the_DO_with_a_Git_Repository.md (**THIS EXERCISE IS STILL UNDER CONSTRUCTION**)
│             ├── 02_320_Using_an_inline_configuration.md (**THIS EXERCISE IS STILL UNDER CONSTRUCTION**)
│             └── 02_330_Using_the_Orchestration_Tool.md (**THIS EXERCISE IS STILL UNDER CONSTRUCTION**)
|
└── Track-B-Automated (perform these set of instructions to follow the Fully-Automated Deployment Method)
       ├── 03_510_Provision_Resources.md
       ├── 03_520_Deploy_SAS_Viya.md
       └── 03_999_Troubleshooting_Tips.md
```

While the content will evolve to integrate additional hands-on in the future, the structure should remain the same.

**Learning path: Track-A-Standard**

**THE EXERCISES IN TRACK A (Manual deployments) ARE STILL UNDER CONSTRUCTION**

* In the "00-Common" folder, we have 2 common hands-on exercises (01_100 and 01_110):
  * To create the EKS cluster with the viya4-iac-aws GitHub tool (terraform method)
  * To install install the pre-requisites manually
  * **these 2 hands-on are mandatory if you want to do the "manual" and "deployment operator" hands-on that are in their respective subfolders.**
  * There is also the **clean-up** instructions (01_400_Cleanup.md), where we provide a script to clean-up the environment and destroy the cluster.

* In the "02-Manual" folder,
  * We show how to use the manual method of deployment (get the assets, kustomize build, kubectl apply)

* In the "03-DepOp" folder,
  * We prepare the environment for a deployment with the Deployment Operator (DepOp).
  * We show how to install Viya with the Deployment Operator (either from a Gitlab repository or an inline configuration).

**Learning path: Track-B-Automated**
* In the "Track-B-Automated" folder,
  * We use the viya-iac-aws GitHub tool (docker method) to create the EKS cluster. (03_510)
  * We then use the viya-iac-deployment GitHub tool (docker method) to install the pre-requisite and deploy Viya 4. (03_520)

<!-- If you want to automate these steps, you can use the instruction in the hands-on [**00_999 Fast track with cheatcodes**](/00_999_Fast_track_with_cheatcodes.md). -->

## Clean up - why ?

**Running SAS Viya in the Cloud is not free!**

* When you create an EKS cluster and deploy Viya on it, a lot of infrastructure resources needs to be created in the Cloud on your behalf (Virtual Network, VMs, Disks,  Load-balancers, etc...)

* Although we try to reduce them as much as possible (smaller instances, autoscaling with minimum node count set to 0), it still generate significant costs, we roughly estimate them at 50 US dollars when you let your cluster run for the 8 hours.

* This is the reason why we provide you ways to clean-up the environment and destroy your cluster once you have completed your training activity

* But just to make sure, there is a scheduled job that deletes any EKS cluster associated Resource group after 8 hours.

---

## Next steps

* Make sure you chave everything to [access your lab environment](00_001_Access_Environments.md)
* Then Select the desired learning path:

  * [Standard - create the EKS cluster](Track-A-Standard/00-Common/00_100_Creating_an_EKS_Cluster.md)

  OR

  * [Fully Automated](Track-B-Automated/03_500_Full_Automation_of_EKS_Deployment.md)

---

## Complete Hands-on Navigation Index

<!-- startnav -->
* [00 001 Access Environments](/00_001_Access_Environments.md)
* [README](/README.md)**<-- you are here**
* [Track B-Automated / 03 510 Provision Resources](/Track-B-Automated/03_510_Provision_Resources.md)
* [Track B-Automated / 03 520 Deploy SAS Viya](/Track-B-Automated/03_520_Deploy_SAS_Viya.md)
<!-- endnav -->
