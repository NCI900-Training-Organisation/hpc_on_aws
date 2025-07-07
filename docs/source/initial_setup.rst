GPU AWS Instance Setup Guide
============================

This document provides a step-by-step guide to creating and configuring a multi-GPU AWS instance,
installing CUDA using Spack, enabling Multi-Instance GPU (MIG) on NVIDIA GPUs, and managing
user permissions and groups for CUDA development.

AWS Instance Setup
------------------

1. **Instance Type and AMI**

   Create an AWS instance using the following configuration:

   - **AMI**: Deep Learning OSS Nvidia Driver AMI GPU PyTorch 2.7 (Ubuntu 22.04) 20250602
   - **AMI ID**: ``ami-05ee60afff9d0a480``
   - **Instance type**: ``p4d.24xlarge`` (which provides multiple GPUs)
   - **Storage**: 300 GiB attached volume for sufficient space

2. **Firewall (Security Groups)**

   Configure security groups to allow:

   - SSH traffic from anywhere (port 22)
   - HTTPS traffic from the internet (port 443)
   - HTTP traffic from the internet (port 80)

Verifying the Instance
----------------------

After the instance is up and accessible, verify the OS, CPU, and NVIDIA GPUs:

- **Check OS version**

  Run:

  .. code-block:: bash

     lsb_release -a

  This confirms you are running the expected Ubuntu 22.04.

- **Check CPU vendor**

  Run:

  .. code-block:: bash

     lscpu | grep "Vendor ID"

  This should typically show ``GenuineIntel`` or ``AuthenticAMD`` depending on the CPU.

- **Verify NVIDIA devices**

  Run:

  .. code-block:: bash

     lspci | grep -i nvidia

  This lists NVIDIA GPU devices available on the instance.

Directory Setup for Software Installation
-----------------------------------------

Create a directory to hold third-party software like Spack and give yourself ownership:

.. code-block:: bash

   sudo mkdir /apps
   sudo chown -R $(whoami):$(whoami) /apps

Installing Spack Package Manager
-------------------------------

Spack is a flexible package manager designed for HPC environments.

- **Clone Spack**

  .. code-block:: bash

     cd /apps
     git clone -c feature.manyFiles=true --depth=2 https://github.com/spack/spack.git

- **Load Spack environment**

  Source the setup script to enable spack commands in the current shell:

  .. code-block:: bash

     . spack/share/spack/setup-env.sh

Working with Spack Compilers and Packages
-----------------------------------------

- **List available packages**

  .. code-block:: bash

     spack list

- **Detect installed compilers**

  .. code-block:: bash

     spack compiler find

- **List recognized compilers**

  .. code-block:: bash

     spack compilers

Installing CUDA with Spack
--------------------------

- **Install CUDA 12.3**

  .. code-block:: bash

     spack install cuda@12.3

- **Verify installation**

  .. code-block:: bash

     spack find

- **Load the installed CUDA environment**

  .. code-block:: bash

     spack load cuda@12.3.2

- **Check CUDA compiler location**

  .. code-block:: bash

     which nvcc

Testing CUDA Installation
-------------------------

Create a simple CUDA program to verify that CUDA devices are detected and usable.

- **Example CUDA program (`count.cu`):**

  .. code-block:: c

     #include <iostream>
     #include <cuda_runtime.h>

     int main() {
         int deviceCount = 0;
         cudaError_t err = cudaGetDeviceCount(&deviceCount);

         if (err != cudaSuccess) {
             std::cerr << "Error detecting CUDA devices: " << cudaGetErrorString(err) << std::endl;
             return 1;
         }

         std::cout << "Number of CUDA-capable GPUs: " << deviceCount << std::endl;
         return 0;
     }

- **Compile and run**

  .. code-block:: bash

     nvcc count.cu
     ./a.out

Enabling Multi-Instance GPU (MIG)
---------------------------------

NVIDIA A100 GPUs support Multi-Instance GPU (MIG), allowing a single GPU to be partitioned into multiple
independent instances.

- **Enable MIG on all GPUs**

  Run this loop to enable MIG mode on GPUs indexed 0 through 7:

  .. code-block:: bash

     for i in {0..7}; do
       sudo nvidia-smi -i $i -mig 1
     done

- **Reboot the instance**

  To apply MIG mode, reboot:

  .. code-block:: bash

     sudo reboot

Configuring MIG Instances
-------------------------

- **Check available MIG profiles on GPU 0**

  .. code-block:: bash

     nvidia-smi mig -lgip -i 0

- **Create 3 MIG instances per GPU using profile `2g.20gb` (profile ID 14)**

  Run this nested loop to create 3 MIGs per GPU on all GPUs 0-7:

  .. code-block:: bash

     for gpu in {0..7}; do
       for _ in {1..3}; do
         sudo nvidia-smi mig -cgi 14 -C -i $gpu
       done
     done

- **Verify the number of GPUs**

  Run the CUDA program again to confirm the increased count (should now report 24 GPUs):

  .. code-block:: bash

     nvcc count.cu
     ./a.out

Setting Up Spack for All Users
------------------------------

To make Spack environment available system-wide:

- **Create a profile script**

  .. code-block:: bash

     sudo nano /etc/profile.d/spack.sh

  Add the following lines to the file:

  .. code-block:: sh

     export SPACK_ROOT=/apps/spack
     . $SPACK_ROOT/share/spack/setup-env.sh

- **Set permissions**

  .. code-block:: bash

     sudo chmod a+r /etc/profile.d/spack.sh

- **Logout and log back in**, then verify:

  .. code-block:: bash

     spack --help

User and Group Management for CUDA Access
-----------------------------------------

- **Create a `spackadmin` group for managing `/apps`**

  .. code-block:: bash

     sudo groupadd spackadmin
     getent group spackadmin
     sudo usermod -aG spackadmin $USER

- **Logout and log back in** and verify group membership:

  .. code-block:: bash

     groups

- **Set ownership and permissions on `/apps`**

  This allows members of the `spackadmin` group to write and manage files in `/apps` while others
  have read and execute permissions.

  .. code-block:: bash

     sudo chown -R root:spackadmin /apps
     sudo chmod -R g+rwX /apps
     sudo chmod g+s /apps
     sudo find /apps -type d -exec chmod g+s {} \;
     sudo chmod -R o=rx /apps

- **Create `cudausers` group for CUDA user access**

  .. code-block:: bash

     sudo groupadd cudausers

- **Install ACL utilities to manage advanced permissions**

  .. code-block:: bash

     sudo apt install acl

- **Grant read and execute permissions recursively to `cudausers` on `/apps`**

  .. code-block:: bash

     sudo setfacl -R -m g:cudausers:rx /apps
     sudo setfacl -R -d -m g:cudausers:rx /apps

- **Verify ACL permissions**

  .. code-block:: bash

     getfacl /apps

Adding CUDA Users
-----------------

Create standard (non-sudo) user accounts for each CUDA user:

.. code-block:: bash

   sudo adduser user1
   sudo adduser user2
   ...
   sudo adduser user24

Add each user to the `cudausers` group to allow access:

.. code-block:: bash

   sudo usermod -aG cudausers user1
   sudo usermod -aG cudausers user2
   ...



Paswsword Login
---------------

.. code-block:: bash
   sudo grep -r 'PasswordAuthentication' /etc/ssh/sshd_config*
   /etc/ssh/sshd_config:PasswordAuthentication yes
   /etc/ssh/sshd_config:# PasswordAuthentication.  Depending on your PAM configuration,
   /etc/ssh/sshd_config:# PAM authentication, then enable this but set PasswordAuthentication
   /etc/ssh/sshd_config.d/60-cloudimg-settings.conf:PasswordAuthentication no