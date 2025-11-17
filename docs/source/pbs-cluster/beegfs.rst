BeeGFS File System
-------------------

BeeGFS is a high-performance parallel file system designed for scalable storage in HPC and 
other data-intensive environments. It stripes data across multiple storage servers, 
enabling fast, concurrent access for many clients, which significantly boosts I/O performance.


The first crucial step in installing BeeGFS is to ensure that the operating system is 
compatible with the BeeGFS version being used. Incompatibility usually crops up when 
installing the BeeGFS client, which is the last step in the setup. In our case, we are 
using BeeGFS version 8.2. which is compatible with Rocky Linux 9.6. BeeGFS underwent some 
major design and CLI changes from version 8.0. So the setup explained here will only work 
for versions 8+. 

The second important step is to make sure the kernel-devel and kernel-headers versions may 
match the running kernel version. To check the versions, kernel version, run the command

.. code-block:: bash

    uname -r

and to find the header version run the command

.. code-block:: bash

    rpm -q kernel-headers kernel-devel



Disk and Directory setup
~~~~~~~~~~~~~~~~~~~~~~~~~~~~~


In our setup, the head node, node1, will act as the BeeGFS management node. The storage nodes, 
node6 and node7, will host the data (storage targets). The compute and login node will 
have the BeeGFS clients.

Each node in the cluster, except the login nodes, has three hard disks.

* /dev/nvme0n1

* /dev/nvme1n1

* /dev/nvme3n1

Login nodes have only one disk - `/dev/nvme0n1`. You can list all the disks in each node using the command.


.. code-block:: bash

    sudo lsblk



Management Node
~~~~~~~~~~~~~~~~~~~~

The management node must have a /BeeGFS directory.

.. code-block:: bash

    sudo mkdir /BeeGFS


his directory should be mounted to the disk `/dev/nvme1n1`. To do this format the disk and 
mount `/BeeGFS`.

.. code-block:: bash

    sudo mkfs.xfs /dev/nvme1n1
    sudo mount /dev/nvme1n1 /BeeGFS
    sudo systemctl daemon-reload


The XFS filesystem is a high-performance journaling filesystem. It is widely used in 
enterprise and HPC environments because of its speed, scalability, and reliability. 
In our setup, XFS will be the local file system (on individual disks), and the BeeGFS will 
be the cluster file system working on top of the local XFS formatted disks. You can verify 
the mount using the command:

.. code-block:: bash

    sudo df -h

Once verified,  create a directory management within the /BeeGFS directory. 

.. code-block:: bash

    sudo mkdir /BeeGFS/management

This directory will store all the management server related data data.


Storage Nodes
~~~~~~~~~~~~~~~~~~~

Similar to the management node, on each storage node, create a `/BeeGFS` directory:


.. code-block:: bash

    sudo mkdir /BeeGFS

Mount /BeeGFS to the disk /dev/nvme1n1

.. code-block:: bash

    sudo mkfs.xfs /dev/nvme1n1
    sudo mount /dev/nvme1n1 /BeeGFS
    sudo systemctl daemon-reload



In our design, metadata is stored on the storage node. Ideally, metadata should reside on 
a separate dedicated server, but for now, we are hosting it on the storage node. To host all 
the metadata server related data, we create a directory metadata on the `/BeeGFS` directory.

.. code-block:: bash

    sudo mkdir /BeeGFS/metadata



Each storage node also has two storage targets. A storage target is essentially a logical 
unit of storage on a storage server. Each target corresponds to a physical disk or a partition 
formatted with a local filesystem (like XFS) and is managed by the BeeGFS storage daemon. 
In our design, we have two storage targets, each with its own disk. To mount the storage 
targets, create the directories `/storage`, `/storage/stor1`, and `/storage/stor2`.

.. code-block:: bash

    sudo mkdir /storage
    sudo mkdir /storage/stor1
    sudo mkdir /storage/stor2



In this setup, each storage node has two disks, `/dev/nvme2n1` and `/dev/nvme3n1`. Format the 
disk and mount the directories these disks. 

.. code-block:: bash

    sudo mkfs.xfs /dev/nvme2n1
    sudo mkfs.xfs /dev/nvme3n1
    sudo mount /dev/nvme2n1 /storage/stor1
    sudo mount /dev/nvme3n1 /storage/stor2
    sudo systemctl daemon-reload

We have to do these steps on all storage nodes.


Configuration and setup
~~~~~~~~~~~~~~~~~~~~~~~~~~~~~


Install beegfs-tools on all the cluster nodes

.. code-block:: bash

    sudo dnf install beegfs-tools -y

The `beegfs-tools` package provides a collection of administrative and diagnostic utilities 
for managing a BeeGFS cluster. These tools are primarily used to monitor, configure, and 
troubleshoot the filesystem.



Configure Management Node
^^^^^^^^^^^^^^^^^^^^^^^^^^^^^

On the management node first install the BeeGFS Management Service

.. code-block:: bash

    sudo dnf install beegfs-mgmtd -y


A secret key is used to authenticate other BeeGFS services with the management service. 
This ensures that only authorised services can connect. By default, the connection file 
is located at `/etc/beegfs/conn.auth`. Edit this file and add the secret key abc123! 
(or any other) to this file. The important thing is to make sure the secret key is 
identical on all nodes.


To ensure secure communication between BeeGFS services, it is necessary to create a 
TLS certificate. This certificate enables encrypted connections, preventing unauthorized 
access and protecting data integrity. You can generate the certificate using the following command:

.. code-block:: bash

    sudo mkdir -p /etc/beegfs
    sudo openssl req -x509 -newkey rsa:4096 -nodes -sha256 -keyout key.pem -out cert.pem -days 3650 -subj "/CN=node1" -addext "subjectAltName=DNS:node1,IP:$(hostname -I | awk '{print $1}')"

    sudo chmod 600 /etc/beegfs/key.pem
    sudo chmod 644 /etc/beegfs/cert.pem
    sudo chown root:root /etc/beegfs/key.pem /etc/beegfs/cert.pem



Once created, copy these files to all other nodes in the cluster. You can use the SCP command 
to do this from node1. The files should be stored in the same location, `/etc/beegfs/key.pem` 
and `/etc/beegfs/cert.pem`, on all nodes. Also, make sure to set the same permissions on 
these files on all the nodes

The management configurations are stored in `/etc/beegfs/beegfs-mgmtd.toml`. In this 
configuration file, set the following permissions:

.. code-block:: bash

    tls-cert-file = "/etc/beegfs/cert.pem"
    tls-key-file = "/etc/beegfs/key.pem"
    auth-file = "/etc/beegfs/conn.auth"



The management service now uses a dedicated SQLite database to improve robustness and support 
advanced features. In older versions, data was stored in plain files rather than a database. 
To initialise the management service, run

.. code-block:: bash

    sudo /opt/beegfs/sbin/beegfs-mgmtd --init

the start the BeeGFS Management Service:

.. code-block:: bash

    sudo systemctl start beegfs-mgmtd

    sudo systemctl status beegfs-mgmtd



Then verify that the management service is running properly and without errors:

.. code-block:: bash

    sudo systemctl status beegfs-mgmtd


You can also check that the management node is listed using the BeeGFS commands

.. code-block:: bash

    sudo /opt/beegfs/sbin/beegfs node list --mgmtd-addr node1:8010



Configure Metadata server
^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^

In this design, there are two metadata servers (node6 and node7), each co-located with a storage 
server. On the storage nodes 

Install the BeeGFS Metadata Service:

.. code-block:: bash

    sudo dnf install beegfs-meta -y

This installs the BeeGFS metadata service, which is responsible for managing the file system 
metadata. Then, set up the BeeGFS Metadata Service:

.. code-block:: bash

    /opt/beegfs/sbin/beegfs-setup-meta -p /BeeGFS/metadata/ -s 1 -m node1


* -p: Specifies the metadata storage path.

* -s: Assigns and id to the the metadata storage service.

* -m: Specifies the BeeGFS management node.


On the second storage node (node7) this command will be

.. code-block:: bash

    /opt/beegfs/sbin/beegfs-setup-meta -p /BeeGFS/metadata/ -s 2 -m node1


A metadata target is a logical storage location managed by a single beegfs-meta server.
Each beegfs-meta service can manage only one target. It is possible to run multiple. beegfs-meta 
service on the same physical node, provided that each beegfs-meta service manages a separate 
target backed by a different partition. The beegfs-meta service ID should be unique across the 
cluster nodes.

Next, edit the `/etc/beegfs/beegfs-meta.conf` file to configure the metadata service and set.

.. code-block:: bash

    connAuthFile = /etc/beegfs/conn.auth
    sysMgmtdHost = node1


* `connAuthFile`: defines the authentication file (usually default)
* `sysMgmntHost`: defines the BeeGHS management hostname


Then start and check the Metadata Service:

.. code-block:: bash

    sudo systemctl start beegfs-meta
    sudo systemctl status beegfs-meta 


This step must be performed on both metadata servers (with different meta target IDs). You can 
ensure that each metadata server is properly registered with the management server by 
listing the metadata server from the management node (node1)

.. code-block:: bash

    sudo /opt/beegfs/sbin/beegfs node list --mgmtd-addr node1:8010 --node-type meta



Storage Server Configuration
^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^

On both the storage nodes (node6 and node7) install the BeeGFS Storage Service:

.. code-block:: bash
    
    sudo dnf install beegfs-storage -y

Next, configure the storage service by editing the file `/etc/beegfs/beegfs-storage.conf`. 
Set the values

.. code-block:: bash

    storeStorageDirectory = /storage/stor1,/storage/stor2
    sysMgmtdHost = node1
    connAuthFile = /etc/beegfs/conn.auth


* `connAuthFile`: defines the authentication file (usually default)

* `sysMgmntHost`: defines the BeeGHS management hostname

* `storeStorageDirectory`: defines the storage targets


Storage targets in BeeGFS differ from metadata targets. Each `beegfs-storage` daemon can

manage more than one storage target. In this setup, each storage daemon is configured with 
two storage targets.

.. code-block:: bash

    sudo /opt/beegfs/sbin/beegfs-setup-storage -p /storage/stor1 -s 1 -i 101 -m node1

    sudo /opt/beegfs/sbin/beegfs-setup-storage -p /storage/stor2 -s 1 -i 102 -m node1



* -p: /storage/stor1: Specifies the storage target path.

* -s 1: Assigns the storage service ID.

* -i: Sets a unique storage target index (should be unique across all storage targets).

* -m: Specifies the BeeGFS management node.



On the second storage node (node7) this command will be:

.. code-block:: bash

    sudo /opt/beegfs/sbin/beegfs-setup-storage -p /storage/stor1 -s 2 -i 201 -m node1

    sudo /opt/beegfs/sbin/beegfs-setup-storage -p /storage/stor2 -s 2 -i 202 -m node1


By convention, the storage target index begins with the storage service ID, followed by a 
unique number. Now start the BeeGFS Storage Service:

.. code-block:: bash

    sudo systemctl start beegfs-storage

    sudo systemctl status beegfs-storage



Repeat this process on all storage servers (with unique storage and service ID). Then, on the 
management node, verify that the storage servers are correctly registered.

.. code-block:: bash

    sudo /opt/beegfs/sbin/beegfs node list --mgmtd-addr node1:8010 --node-type storage



Install BeeGFS Client and Dependencies
^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^


Now that the BeeGFS management, meta, and storage services are set up, install the BeeGFS 
Client on all the client nodes (login node - node2 and compute nodes- node3, node4, node5):

.. code-block:: bash

    sudo dnf install beegfs-client kernel-devel

This is where you can run into trouble if the kernel version and the kernel-header version 
is not the same. Now set the following parameters in the `/etc/beegfs/beegfs-client.conf` 
file:

.. code-block:: bash

    sysMgmtdHost = node1

    connAuthFile = /etc/beegfs/conn.auth



* connAuthFile: defines the authentication file (usually default)

* sysMgmntHost: defines the BeeGHS management hostname



Now set the following parameters in the `/etc/beegfs/beegfs-mounts.conf` file:

.. code-block:: bash

    /scratch /etc/beegfs/beegfs-client.conf

`/etc/beegfs/beegfs-mounts.conf`defines the filesystems that the client should automatically 
mount, along with their configuration. In the configuration file `/etc/beegfs/beegfs-mounts.conf`, /scratch is the mount point on the local client node, where the BeeGFS filesystem will appear in the directory tree. You must create this directory on all client nodes (login node - node2 and compute nodes- node3, node4)

.. code-block:: bash

    sudo mkdir -p /scratch

In the configuration file `/etc/beegfs/beegfs-mounts.conf`, `/etc/beegfs/beegfs-client.conf` 
specifies the path to the client configuration file for this mount. This tells the client which 
management server to contact and other necessary configuration details.


Now start the BeeGFS client on all client nodes

.. code-block:: bash

    sudo systemctl start beegfs-client

    sudo systemctl status beegfs-client


Then, check if the clients are registered with the management server by executing this 
command on the management node (node1)

.. code-block:: bash

    sudo beegfs node list --mgmtd-addr node1:8010 --node-type client

Finally, to verify that everything is working correctly, create a test file in the
`/scratch` directory from any client node (node2, for instance )and check whether it is 
visible from the other client nodes (node 3, for instance).

.. code-block:: bash

    ssh node3
    touch /scratch/testfile_from_node3.txt

    ssh node4
    ls /scratch/



In this example, we only have one shared file system `/scratch`. In a production HPC system, 
we will have multiple file systems- for instance, `/scratch`` (to host user data) and 
`/userhome` (to host user home directories). In such cases, we will need two management 
services - one for `/scratch` and one for `/userhome`. It is possible to host both the 
management services on the same VM, but it is not advised. Similarly, we will need different 
meta and storage services for both /scratch and /userhome. In addition, the  /etc/beegfs/beegfs-mounts.conf file will contain 2 entries

.. code-block:: bash

    /scratch /etc/beegfs/beegfs-client_scratch.conf

    /userhome /etc/beegfs/beegfs-client_userhome.conf

