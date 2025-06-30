Terraform
============================


Configure AWS
----------------

Make sure you have an IAM access key and configure AWS.

.. code-block:: bash
    :linenos:

    aws configure --profile terraform-user

    AWS Access Key ID [None]: A*********************T
    AWS Secret Access Key [None]: 7************************4             
    Default region name [None]: us-east-1
    Default output format [None]: yaml

Where ``terraform-user`` is the IAM user you have created, with the access key id ``A*********************T``
and access key ``7************************4``.  

.. code-block:: bash
    :linenos:

    aws configure list
    aws sts get-caller-identity

 
Sample configuration
---------------------


The set of files used to describe infrastructure in Terraform is known as a Terraform configuration. 
You will write your first configuration to define a single AWS EC2 instance.


.. important::
    Each Terraform configuration must be in its own working directory. 

.. code-block:: hcl
    :linenos:

    terraform {
        required_providers {
            aws = {
              source  = "hashicorp/aws"
              version = "~> 4.16"
            }
        }

        required_version = ">= 1.2.0"
    }

    provider "aws" {
      region  = "us-west-2"
    }

    resource "aws_instance" "app_server" {
      ami           = "ami-830c94e3"
      instance_type = "t2.micro"

      tags = {
        Name = "ExampleAppServerInstance"
      }
    }

Terraform Block
^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^

The ``terraform {}`` block contains Terraform settings, including the required providers Terraform will use to provision your infrastructure. 
For each provider, the source attribute defines an optional hostname, a namespace, and the provider type. 

* Terraform installs providers from the Terraform Registry by default. 
* In this example configuration, the aws provider's source is defined as hashicorp/aws, which is shorthand for ``registry.terraform.io/hashicorp/aws``.


Privider Block
^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^

The provider block configures the specified provider, in this case ``aws``. A provider is a plugin that Terraform uses to create and manage your resources.
You can use multiple provider blocks in your Terraform configuration to manage resources from different providers. You can even use different providers 
together. 


Resource Blocks
^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^

Resource blocks to define components of your infrastructure. A resource might be a physical or virtual component such as an EC2 instance, 
or it can be a logical resource such as a Heroku application.

Resource blocks have two strings before the block: the resource type and the resource name. In this example, 

* The resource type is aws_instance and the name is app_server. 
* The prefix of the type maps to the name of the provider. 
* In the example configuration, Terraform manages the aws_instance resource with the aws provider. 
* Together, the resource type and resource name form a unique ID for the resource. 
* For example, the ID for your EC2 instance is aws_instance.app_server.



Initialize the directory
---------------------------------

When you create a new configuration  you need to initialize the directory with terraform init.
Initializing a configuration directory downloads and installs the providers defined in the configuration, which in this case is the aws provider.


.. code-block:: bash
    :linenos:

    terraform init

Format and validate the configuration
---------------------------------

The terraform fmt command automatically updates configurations in the current directory for readability and consistency.

.. code-block:: bash
    :linenos:

    terraform fmt


You can also make sure your configuration is syntactically valid and internally consistent by using the terraform validate command.

.. code-block:: bash
    :linenos:

    terraform validate


Create infrastructure
---------------------------------

Apply the configuration now with the terraform apply command. Terraform will print output similar to what is shown below. We have truncated some
of the output to save space.

.. code-block:: bash
    :linenos:

    terraform apply