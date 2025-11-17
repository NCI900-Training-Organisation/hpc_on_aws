
Passwordless SSH
-------------------

Passwordless SSH is required in HPC clusters to allow nodes to communicate and execute tasks  
automatically, such as job scheduling, data transfers, and parallel computations, without  
repeated password prompts, ensuring efficient and seamless operation.


Create the SSH keys
~~~~~~~~~~~~~~~~~~~~~~~

On each node, ensure the `~/.ssh` directory exists, creating it if necessary:

.. code-block:: bash

    mkdir -p ~/.ssh     
    chmod 700 ~/.ssh     
    chown rocky:rocky ~/.ssh


Then, generate an SSH key pair on each node:

.. code-block:: bash

    ssh-keygen -t rsa -b 4096 -f ~/.ssh/id_rsa -N ""

This creates a new keypair (id_rsa private key and id_rsa.pub public key). The `-N` option in 
`ssh-keygen` specifies the new passphrase for the private key, and using `-N` "" sets it to an 
empty password (no passphrase). This makes it possible to use this keypair without a password 
prompt. 



Once the keys are created, copy the new key back to your local system. Since the local 
system's public key (terraform-user.pub) was already added to the VM during its creation, transferring files from 
the VM is easier.  On the local system:

.. code-block:: bash

    mkdir keys
    cd keys
    scp -i ~/.ssh/terraform-user rocky@<node1 ip>:~/.ssh/id_rsa node1.pub


This scp command copies the key of node1 to the local system. Do that for all other nodes. 


Set the hostname
~~~~~~~~~~~~~~~~~~~~

Once the keys are created and copied to the local system we can set the hostname for each node 
in the cluster.  The hostname is the unique name assigned to a system on a network. It is used 
to identify the machine in communications with other nodes, for logging, and for network 
management. To set the hostname on node1 run the command

.. code-block:: bash

    sudo hostnamectl set-hostname node1

This command will set the hostname of node1 as `node1`. To make this persistent across reboots 
write the hostname to `/etc/hostname`:

.. code-block:: bash

    echo "node1" | sudo tee /etc/hostname

Repeat the same for other nodes- of course, with other hostnames. 



Hosts File Setup
~~~~~~~~~~~~~~~~~~~~

Next, we configure the `/etc/hosts`. The `/etc/hosts` file is a local mapping of hostnames 
to IP addresses. It allows systems to resolve names without using DNS, making it easy to 
connect to other machines by name (like node1) instead of their IP addresses. 


We need to make sure that the localhost and IPv6 entries are correctly set in `/etc/hosts`.
Ensuring correct entries for localhost and IPv6 addresses allows the system to properly resolve 
its own name and handle network communications internally, which is essential for many services 
and applications. Add these lines to `/etc/hosts`:


.. code-block:: bash

    127.0.0.1 localhost
    # The following lines are desirable for IPv6 capable hosts

    ::1 ip6-localhost ip6-loopback
    fe00::0    ip6-localnet      # IPv6 local network address
    ff00::0    ip6-mcastprefix   # IPv6 multicast prefix
    ff02::1    ip6-allnodes      # Multicast address for all IPv6 nodes on the local network
    ff02::2    ip6-allrouters    # Multicast address for all IPv6 routers on the local network
    ff02::3    ip6-allhosts      # Multicast address for all IPv6 hosts




Finally, add the details of all nodes in the cluster along with their local IP addresses to 
`/etc/hosts`.  To find the local (private) IP address on RHEL, you can the following command:

.. code-block:: bash

    ip addr show

This display the IP addresses assigned to the network interfaces on the node. An example 
hostname-to-IP mapping will look like this

.. code-block:: bash

    10.0.1.20 node1
    10.0.1.19 node2
    10.0.1.56 node3
    10.0.1.60 node4
    10.0.1.35 node5
    10.0.1.12 node6
    10.0.1.22 node7



In the end, the `/etc/hosts` file should look like this:

.. code-block:: bash

    127.0.0.1 localhost localhost.localdomain localhost4 localhost4.localdomain4
    ::1  localhost localhost.localdomain localhost6 localhost6.localdomain6
    127.0.0.1 localhost

    # The following lines are desirable for IPv6 capable hosts

    ::1 ip6-localhost ip6-loopback
    fe00::0 ip6-localnet
    ff00::0 ip6-mcastprefix
    ff02::1 ip6-allnodes
    ff02::2 ip6-allrouters
    ff02::3 ip6-allhosts

    10.0.1.20 node1
    10.0.1.19 node2
    10.0.1.56 node3
    10.0.1.60 node4
    10.0.1.35 node5
    10.0.1.12 node6
    10.0.1.22 node7





Append Keys
~~~~~~~~~~~~~~

Earlier, we had copied the public keys for each node in the cluster to the local system. 
Now combine the multiple keys into a single file. On the local system do:

.. code-block:: bash

    cat *.pub >> authorized_keys


Next, copy this authorized_keys file to each node in the cluster using `scp`. This ensures that 
all nodes have the same set of authorized keys. For example to copy the `authorized_keys` file 
to node1 you can do this:

.. code-block:: bash

    scp -i ~/.ssh/terraform-user authorized_keys rocky@<node1 ip>:~/.ssh/authorized_keys

Do this for all the nodes in the cluster.

The authorized_keys file in a user's ~/.ssh/ directory tells the SSH server which public keys 
are allowed to log in as that user. When someone tries to SSH in:

1. The client presents its private key.
2. The server checks if the corresponding public key exists in authorized_keys.
3. If it matches, the login is allowed without a password.

This enables passwordless, secure SSH access from multiple users or machines, while keeping 
control centralized.


Once the `authorized_keys` file is set on all nodes, set the correct permissions for the 
authorized_keys file to ensure SSH works properly:

.. code-block:: bash

    sudo chmod 600 /home/rocky/.ssh/authorized_keys
    sudo chown rocky:rocky /home/rocky/.ssh/authorized_keys


In some cases the `/etc/hosts` file will have stale ip entry. A stale entry in the 
`/etc/hosts` file refers to a hostname-to-IP mapping that is no longer valid- for example, 
if a server's IP address has changed but the old IP still exists in the file. Stale entries can cause issues like:


* SSH or other network connections trying to reach the wrong IP.

* Applications resolving hostnames incorrectly.

* Confusion during cluster or multi-node setups where consistent name resolution is critical.


So it is a good practice to remove outdated entries and ensure all hostnames point to the 
correct IP addresses. To do that run the following command on all nodes.

.. code-block:: bash
    
    ssh-keygen -R <other-node-ip>

The ssh-keygen command removes a hosts old SSH key from your `~/.ssh/known_hosts` file (this is 
especially important when you have run the same ansible file multiple times). This file keeps 
a record of the public keys of all remote hosts your system has previously connected to via SSH.
Each time you connect to a server, the SSH client checks this file to verify that the 
server's key matches what was stored from earlier connections.

If the key matches, the connection proceeds smoothly. If it doesn't, SSH warns of a potential 
security risk. Running the `ssh-keygen` command clears the outdated entry for a specific IP 
(e.g., <other-node-ip>). In a cluster, you need to perform this for all IPs of all nodes 
to ensure smooth, passwordless SSH connectivity across the entire cluster. And you need 
to do this on alll cluster nodes.



Now that you have cleared any stale entries in the known_hosts file, retrieve the current  
host key from the remote machine (`<other-node-ip>`) and add it to your local `known_hosts`
file. This allows SSH connections without interactive prompts:

.. code-block:: bash

    ssh-keyscan -H <other-node-ip>

Again, you need to perform this for all IPs of all nodes to ensure smooth, passwordless 
SSH connectivity across the entire cluster. And you need to do this on alll cluster nodes.



Now that all the known_hosts file is populated edit the `~/.ssh/config` file to include the 
following settings:


.. code-block:: bash

    Host *
        StrictHostKeyChecking no
        UserKnownHostsFile /home/rocky/.ssh/known_hosts
        LogLevel ERROR



* `StrictHostKeyChecking no` - ensures the SSH client does not prompt you when connecting to 
a host whose key is new or has changed.

* `UserKnownHostsFile` specifies the file where known host keys are stored.

* `LogLevel ERROR` reduces unnecessary SSH log messages.


After this, edit `/etc/ssh/sshd_config` on each node and ensure the following:

* `PasswordAuthentication yes`- This allows users to log in using a password instead of an 
SSH key. It's useful as a fallback, but enabling it can be less secure than key-based 
authentication.

* `ChallengeResponseAuthentication no`- This disables challenge-response authentication, 
a method where the server sends a challenge (like a one-time code) and the client must respond 
correctly. Turning it off simplifies login and avoids unnecessary prompts.

* `UsePAM yes` - This enables Pluggable Authentication Modules (PAM), which provide a flexible 
way to handle authentication. PAM can support extra security features like account limits, 
two-factor authentication, or logging, enhancing the SSH login process.


Disable cloud configurations
~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~

On a bare-metal system, the previous SSH configuration steps would usually be sufficient.
However, since we are working with AWS instances, additional steps are required to prevent 
cloud-specific settings from interfering.

On every node, disable cloud-init SSH management:

.. code-block:: bash

    sudo chmod 644 /etc/cloud/cloud.cfg.d/99-disable-ssh-password.cfg

    sudo rm -f /etc/ssh/sshd_config.d/60-cloudimg-settings.conf



Deleting the SSH configuration file is important because cloud images often include default
SSH settings that can disable password login or override your manual SSH configuration.

Also, in `/etc/cloud/cloud.cfg` (create the file if it doesn't exist), enable password 
authentication to ensure cloud-init does not overwrite your SSH settings on reboot or 
redeployment:

.. code-block:: bash

    ssh_pwauth: 1

Setting `ssh_pwauth` to 1 allows SSH password login. This prevents cloud-init from resetting 
or disabling password authentication during instance reboots or redeployments, ensuring your 
manual SSH configuration remains intact.


Finally restart the SSH service:

.. code-block:: bash

    sudo systemctl restart sshd


To verify that passwordless SSH is working, test SSH from each node to every other node. For 
example, from node1, run:

.. code-block:: bash

    ssh node2

You should be able to log in to node2 without being prompted for a password. This confirms that 
the SSH key setup was successful.