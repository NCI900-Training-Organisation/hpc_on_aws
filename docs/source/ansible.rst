Ansible
============================


Start instance
---------------------

.. code-block:: bash
    :linenos:

    terraform login
    terraform init
    terraform apply

Start the instance and find the public ip address of the instance

.. code-block:: bash
    :linenos:

    terraform output

This will give you the iP address.

Inventory file (hosts.ini)
----------------------

Using the IP adress (for example 92.29.22.22) update the file `hosts.ini`

.. code-block:: bash
    :linenos:

    98.81.120.13 ansible_user=ubuntu ansible_ssh_private_key_file=~/.ssh/terraform-user

Where ``terraform-user`` is the private key of the key-pair used to create the instance.

Ansible playbook setup.yaml
-------------------


Ansible plybooks gives the configuration steps to be carried out in the instance.








