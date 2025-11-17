Preparing AWS instances
--------------------------


This part explains the initial setup to install the packages we will need for the different 
components of the HPC cluster.


The first thing we have to do is disable Security-Enhanced Linux (SELinux). It is a security 
module built into the Linux kernel that provides mandatory access control (MAC), which is 
stricter than the usual discretionary access control (DAC) that standard Linux uses. 
In simpler terms, SELinux adds another layer of security beyond normal Linux permissions.

Some of the components we use in this setup, like OpenPBS, will not work with SELinux.
Therefore, the first step is to disable SELinux on all nodes:

.. code-block:: bash

    sudo setenforce 0

To ensure the change persists even after a reboot, edit the file `/etc/selinux/config` 
and set:

.. code-block:: bash

    SELINUX=disabled


Next, enable the CRB and PLUS repositories on all nodes. The CodeReady Builder (CRB) repository 
is an optional repository in RHEL that provides developer tools, libraries, and packages not 
included in the default BaseOS or AppStream repositories. Similarly, the RHEL PLUS repository 
contains additional supported packages beyond the standard BaseOS or AppStream offerings.

.. code-block:: bash

    sudo dnf config-manager --set-enabled crb

    sudo dnf config-manager --set-enabled plus



Then we refresh the package metadata and clear any old cached data

.. code-block:: bash

    sudo dnf clean all

    sudo dnf makecache

We run dnf clean all to remove old or stale package metadata and cache, ensuring no outdated 
information is used. Then, dnf makecache downloads fresh metadata from all enabled repositories, 
so package installations and updates use the latest available information. This is especially 
important after enabling new repositories like CRB or PLUS.

After this, we update the GNU C Library (glibc) first to avoid dependency issues before 
updating the rest of the system:

.. code-block:: bash

    sudo dnf install glibc glibc-devel glibc-common -y



Next, update the entire system to the latest packages:

.. code-block:: bash

    sudo dnf update -y



We then install the EPEL (Extra Packages for Enterprise Linux) to access additional open-source 
packages.

.. code-block:: bash

    sudo dnf nstall epel-release -y


Next we ensure the installed packages match the currently enabled repositories versions:

.. code-block:: bash

    sudo dnf distro-sync -y

`distro-sync` synchronises installed packages with the versions available in the enabled 
repositories. It can upgrade or downgrade packages to match the repository, ensuring 
consistency. This is useful after enabling or changing repositories to prevent mismatched or unsupported package versions.

After the synchronisation, we install the Development Tools. This installs a predefined 
group of packages needed for software development. This includes compilers, libraries, and 
build tools like gcc, make, and autoconf.

.. code-block:: bash

    sudo dnf groupinstall "Development Tools" -y


Finally, we install the other packages required across the virtual machines

.. code-block:: bash

    sudo dnf install -y wget vim telnet net-tools python3 python3-devel perl autoconf automake gcc gcc-c++ make cmake chkconfig nmap-ncat

After all updates and SELinux changes, reboot the nodes.

.. code-block:: bash

    sudo reboot


There are two main pain points we are trying to avoid with this order of installation.

* Discrepancy in the glibc package version: The glibc library is a critical component that provides the core system libraries for applications and system utilities to function correctly. A discrepancy in its version can lead to compatibility issues, unexpected behavior in binaries compiled against different library versions, or errors during package installation and system updates.

* Mismatch between the kernel version and the kernel headers version: The installed kernel version does not match the kernel-headers package version. Kernel headers are used during software compilation (especially for drivers and kernel modules) and must correspond exactly to the running kernel. When the versions differ, it can cause build failures for kernel-dependent packages or modules, and may lead to runtime errors if compiled against the wrong headers.