Provisioning GPU node on AWS
============================

We are provisioning a GPU node on AWS and this requires three key aspects:

#. AWS setup
#. Terraform setup
#. Ansible setup


This document detail each of the above steps in detail.

AWS Setup
---------------------------

The AWS setup mainly involves two steps:

#. Creating an IAM user with the necessary permissions
#. Installing and configuring the AWS CLI

To provision a GPU node on AWS, you need to create an IAM user with the necessary permissions. Follow these steps:
   
   - Go to the AWS IAM console.
   - Create a new user with programmatic access.
   - Attach the `AmazonEC2FullAccess` policy to the user.
   - Save the access key ID and secret access key.

Here the policy decides what the user can do. The `AmazonEC2FullAccess` policy allows the user to create, modify, and delete EC2 instances.
The acess key ID and secret access key are used to authenticate the user when using the AWS CLI or SDKs.

The next step is to install and configure the AWS CLI. For this you can follow the official AWS documentation on 
`Installing the AWS CLI, NCI <https://docs.aws.amazon.com/cli/v1/userguide/install-linux.html>`_

Once we have the AWS CLI installed, we can configure it with the access key ID and secret access key we created earlier. Run the following 
command:

.. code-block:: bash
    :linenos:

    aws configure --profile terraform-user

    AWS Access Key ID [None]: A*********************T
    AWS Secret Access Key [None]: 7************************4             
    Default region name [None]: us-east-1
    Default output format [None]: yaml

Where ``terraform-user`` is the IAM user you have created, with the access key id ``A*********************T``
and access key ``7************************4``.  

You can verify the configuration by running:

.. code-block:: bash
    :linenos:

    aws configure list
    aws sts get-caller-identity

Where the first command lists the configuration of the AWS CLI, and the second command returns the IAM user details.

Terraform Setup
----------------

In the next step, we will set up Terraform to provision the GPU node on AWS. This involves 

#. Creating a Terraform configuration file that defines the resources we want to create, such as the EC2 instance, security groups, and IAM roles.
#. Initializing Terraform and applying the configuration to create the resources.
#. Configuring HCP (HashiCorp Cloud Platform) to manage the state of the resources.

In the following sections we will define each Terraform configuration file we have used in detail.

`main.tf, NCI <../../GPU-server/main.tf>`_
^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^

The ``terraform`` block in a Terraform configuration is used to specify settings that apply to the entire Terraform project 
(working directory). It's typically placed in the root module and controls how Terraform behaves during operations like init, plan, apply.

The ``required_providers`` block specifies which providers are needed for the project and their versions. In this case, we are using the 
AWS provider from HashiCorp's official registry.

The ``provider`` block configures the AWS provider with the region where the resources will be created.

.. code-block:: hcl
   :linenos:


terraform {
  required_providers {
    aws = {
      # The AWS provider comes from the official HashiCorp registry
      source  = "hashicorp/aws"     










