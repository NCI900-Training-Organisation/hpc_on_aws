PBS Scheduler
------------------

OpenPBS (Portable Batch System) is an open-source workload management and job scheduling 
system designed for HPC environments. It efficiently allocates compute resources across 
clusters by queuing, scheduling, and monitoring batch jobs submitted by users. OpenPBS and 
PBS will be used interchangeably in this document.

There are 3 main types of nodes in the PBS.


* **Server Node**: Central control node of the PBS cluster. This manages job queues, user 
requests, and job tracking (node1)

* **Compute Node**: Runs the actual computational jobs submitted by users. It acts as the 
worker node and executes and monitors jobs assigned by the server (node3, node4, node5)

* **Client node**: Used by users to log in, compile code, and submit jobs. These nodes do 
not to execute jobs (node2)



In our setup, storage servers does not execute jobs and so the storage servers do not require 
any aspect of PBS, including the PBS clients.  In OpenPBS, the MOM (Machine Oriented Mini-server)
is the daemon that runs on each compute node and is responsible for executing and managing jobs 
assigned by the PBS server. Acting as the cluster's worker agent, it receives job scripts, 
launches them, monitors their progress, and reports job status back to the server.



Initial installation 
~~~~~~~~~~~~~~~~~~~~~~~~

Install the following packages on all nodes 

.. code-block:: bash

    sudo dnf install -y cjson-devel libedit-devel libical-devel ncurses-devel make cmake rpm-build libtool gcc gcc-c++ libX11-devel libXt-devel libXext libXext-devel libXmu-devel tcl-devel tk-devel postgresql-devel postgresql-server postgresql-contrib python3 python3-devel perl expat-devel openssl-devel hwloc-devel java-21-openjdk-devel swig swig-doc vim sendmail chkconfig autoconf automake git


Build OpenPBS from Source
~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~

Once the packages are installed, build OpenPBS from source on all nodes (except storage as we 
are not installing PBS in storage nodes)

.. code-block:: bash

    sudo git clone https://github.com/openpbs/openpbs.git && cd openpbs
    sudo ./autogen.sh
    sudo ./configure --prefix=/opt/pbs
    sudo make -j$(nproc) && sudo make install
    echo "export PATH=/opt/pbs/bin:/opt/pbs/sbin:\$PATH" | sudo tee /etc/profile.d/pbs.sh
    source /etc/profile.d/pbs.sh

Once installed run the following command on 

.. code-block:: bash

    sudo /opt/pbs/libexec/pbs_postinstall

Then set the proper permissions on the files `/opt/pbs/sbin/pbs_iff` and `/opt/pbs/sbin/pbs_rcp`:

.. code-block:: bash

    sudo chmod 4755 /opt/pbs/sbin/pbs_iff /opt/pbs/sbin/pbs_rcp

If it doesn't already exist, create the required directories and set permissions on the head 
node (node1):

.. code-block:: bash

    sudo mkdir -p /var/spool/pbs/server_priv/security
    sudo chown root:root /var/spool/pbs/server_priv/security
    sudo chmod 700 /var/spool/pbs/server_priv/security

Then, in all nodes set the hostname for the PBS server

.. code-block:: bash

    sudo sh -c 'echo "node1" > /var/spool/pbs/server_name'



Configuration Files
~~~~~~~~~~~~~~~~~~~~~~~~~

Once installed, configure PBS by editing the configuration file `/etc/pbs.conf`. 
The configuration file has the following values

* **PBS_SERVER**: Specifies the hostname of the PBS server. All PBS components (scheduler, communication daemon, and MOMs) will connect to this server for coordination.

* **PBS_START_SERVER**: Tells the system to start the PBS server daemon (pbs_server) on this node. The PBS server manages job queues, user submissions, and system-wide scheduling.

* **PBS_START_SCHED**: Starts the PBS scheduler (pbs_sched), which decides when and where jobs should run based on policies and available resources.

* **PBS_START_COMM**: Starts the PBS communication daemon (pbs_comm), which handles network communication between all PBS components (server, scheduler, and compute nodes).

* **PBS_START_MOM**: Indicates that the MOM (Machine Oriented Mini-server) process (pbs_mom) should not start on this node. The MOM daemon runs on compute nodes to execute and manage jobs. Setting this to 0 means this node is not a compute node.

* **PBS_EXEC**: Specifies the installation directory where PBS binaries and scripts are located.

* **PBS_HOME**: Defines the working directory for PBS, where it stores logs, job data, and configuration files.

* **PBS_CORE_LIMIT**: Sets the core file size limit for PBS daemons to unlimited, allowing full core dumps for debugging if a daemon crashes.

* **PBS_SCP**: Specifies the path to the scp command, used for securely copying files (like job scripts or output) between nodes.



PBS Server
^^^^^^^^^^^^^^^^^^^^^^^^^

On the PBS server (node1) set the following values


.. code-block:: bash

    PBS_SERVER=node1
    PBS_START_SERVER=1
    PBS_START_SCHED=1
    PBS_START_COMM=1
    PBS_START_MOM=0
    PBS_EXEC=/opt/pbs
    PBS_HOME=/var/spool/pbs
    PBS_CORE_LIMIT=unlimited
    PBS_SCP=/bin/scp



Client Node
^^^^^^^^^^^^^^^^

On the client node (node2) set the following values

.. code-block:: bash

    PBS_SERVER=node1
    PBS_START_SERVER=0
    PBS_START_SCHED=0
    PBS_START_COMM=0
    PBS_START_MOM=0
    PBS_HOME=/var/spool/pbs
    PBS_EXEC=/opt/pbs



Compute Nodes
^^^^^^^^^^^^^^^^

On the compute nodes (node3, node4, node 5) set the following values

.. code-block:: bash

    PBS_SERVER=node1
    PBS_START_SERVER=0
    PBS_START_SCHED=0
    PBS_START_COMM=0
    PBS_START_MOM=1
    PBS_HOME=/var/spool/pbs
    PBS_EXEC=/opt/pbs



Then, on all nodes run the PBS services

.. code-block:: bash

    sudo systemctl start pbs
    sudo systemctl enable pbs
    sudo systemctl status pbs



Configuring and Verifying PBS Nodes
~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~


Now that PBS is properly configured on all nodes, add the compute nodes from the PBS server 
(node1)

.. code-block:: bash

    sudo /opt/pbs/bin/qmgr -c "create node node3"
    sudo /opt/pbs/bin/qmgr -c "create node node4"
    sudo /opt/pbs/bin/qmgr -c "create node node5"

You can verify if the nodes were properly added by using the command:

.. code-block:: bash

    sudo /opt/pbs/bin/qmgr -c "list node @active"

Also verify PBS is reachable from the client node (node2):

.. code-block:: bash

    sudo /opt/pbs/bin/qstat -B

In addition on the head node set the default server parameters:

.. code-block:: bash

    sudo /opt/pbs/bin/qmgr -c "set server default_queue = workq"
    sudo /opt/pbs/bin/qmgr -c "set server resources_default.select = 1"
    sudo /opt/pbs/bin/qmgr -c "set server flatuid = True"

The last one is particularly important as it tells PBS to treat all user IDs (UIDs) as 
equivalent across the cluster. This will make sure that strict UID matching between the 
server and compute nodes are not enforced. Without this, you may get an error when submitting 
the job from the client node (node2).