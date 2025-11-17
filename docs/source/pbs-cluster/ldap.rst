LDAP Server
-------------

Lightweight Directory Access Protocol (LDAP) is a protocol used for accessing and managing 
directory services over a network. It is commonly used for centralised authentication and 
authorisation in enterprise environments. By integrating LDAP with a PBS cluster, 
user authentication and management can be centralised, making it easier to handle user 
accounts and permissions across multiple nodes in the cluster.



LDAP has two types of nodes

* LDAP server - Head node (node1)

* LDAP clients - Login node (node2)


LDAP Server Configuration
~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~

On the head node (node1), install OpenLDAP packages.

.. code-block:: bash

    sudo dnf install openldap-servers openldap-clients

You can now start the server

.. code-block:: bash

    sudo systemctl start slapd
    sudo systemctl enable slapd
    sudo systemctl status slapd


The `slappasswd` command is a utility in OpenLDAP used to generate encrypted (hashed) 
passwords that can be safely stored in the LDAP directory. It's not for changing 
passwords directly inside LDAP — rather, it creates a secure password hash that you can 
then manually add or update in an LDAP entry (for example, in olcRootPW or userPassword 
attributes). One thing to note is that slappasswd generates different hashes for the same 
password each time because it uses a salted hashing algorithm. In the next step, find 
the hash of the password you want to use as the LDAP admin password.

.. code-block:: bash

    slappasswd

In this setup, we are using the password `ldappassword`. Let us assume the hash generated 
for password ldappassword is `{SSHA}UNHjdYvrkQIhD9vRlShjlADjmJF/hhcm`. Now we use this hash 
in the following LDIF file to set the LDAP admin password. In LDAP, an LDIF (LDAP Data Interchange Format) 
file is a plain-text file used to represent directory data and configuration in a standard, 
portable format. So we use the following LDIF file (`changerootpass.ldif`) 
to set the admin password for LDAP.

.. code-block:: bash

    dn: olcDatabase={0}config,cn=config
    changetype: modify
    add: olcRootPW
    olcRootPW: {SSHA}UNHjdYvrkQIhD9vRlShjlADjmJF/hhcm


* `dn: olcDatabase={0}config,cn=config` - Specifies the Distinguished Name (DN) of the LDAP entry being modified.

* `**{0}config` - Refers to the internal configuration database used by slapd.

* `changetype: modify` - Indicates that this operation is modifying an existing entry (not creating or deleting one).

* `add: olcRootPW` - Adds a new attribute called olcRootPW to the configuration entry.

* `olcRootPW: {SSHA}UNHjdYvrkQIhD9vRlShjlADjmJF/hhcm` - The hashed password (generated with slappasswd) that becomes the root bind password for this configuration database.



Now we run the command

.. code-block:: bash
    
    sudo ldapadd -Y EXTERNAL -H ldapi:/// -f changerootpass.ldif

This command applies configuration changes from `changerootpass.ldif` to the local LDAP server. 
It connects via the local UNIX socket (`ldapi:///`) and authenticates as the system user using 
SASL EXTERNAL. SASL (Simple Authentication and Security Layer) is a framework that allows LDAP 
to use different authentication methods. The EXTERNAL mechanism means the authentication is 
done outside of LDAP, using the identity provided by the connection itself (root).

The next step is to add the necessary LDAP schemas. In LDAP schema defines the structure, rules, 
and types of data that can be stored in the directory. Schemas specify which object classes and 
attributes are allowed and how they relate to each other. Without loading the necessary schemas, 
LDAP wouldn't know how to handle common entries like users, groups, or email addresses.

In this case, we are loading three schemas:

* `cosine.ldif`: Provides general-purpose internet-related attributes and object classes for users and groups.

* `nis.ldif`: Adds UNIX/Linux account and group attributes for system integration.

* `inetorgperson.ldif`: Defines detailed human user attributes for directories and identity management.



To add the schemas to LDAP, use the commands.

.. code-block:: bash

    sudo ldapadd -Y EXTERNAL -H ldapi:/// -f /etc/openldap/schema/cosine.ldif 
    sudo ldapadd -Y EXTERNAL -H ldapi:/// -f /etc/openldap/schema/nis.ldif 
    sudo ldapadd -Y EXTERNAL -H ldapi:/// -f /etc/openldap/schema/inetorgperson.ldif

Then restart the LDAP service

.. code-block:: bash

    sudo systemctl restart slapd



The next step is to set the domain and configure the LDAP database. Create a file named 
`setdomain.ldif` with the following content:


.. code-block:: bash

    # Give local root (UID 0) and Manager read access to the monitor database
    dn: olcDatabase={1}monitor,cn=config
    changetype: modify
    replace: olcAccess
    olcAccess: {0}to *
    	by dn.base="gidNumber=0+uidNumber=0,cn=peercred,cn=external,cn=auth" read
    	by dn.base="cn=Manager,dc=cluster,dc=lan" read
    	by * none

    # Set the LDAP database suffix (your domain)
    dn: olcDatabase={2}mdb,cn=config
    changetype: modify
    replace: olcSuffix
    olcSuffix: dc=cluster,dc=lan

    # Define the root DN (admin user for LDAP)

    dn: olcDatabase={2}mdb,cn=config
    changetype: modify
    replace: olcRootDN
    olcRootDN: cn=Manager,dc=cluster,dc=lan

    # Add root password (replace with your own SSHA hash)
    dn: olcDatabase={2}mdb,cn=config
    changetype: modify
    add: olcRootPW
    olcRootPW: {SSHA}UNHjdYvrkQIhD9vRlShjlADjmJF/hhcm

    # Set access control rules for users and the admin

    dn: olcDatabase={2}mdb,cn=config
    changetype: modify
    add: olcAccess
    olcAccess: {0}to attrs=userPassword,shadowLastChange
    	by dn="cn=Manager,dc=cluster,dc=lan" write
    	by anonymous auth
    	by self write
    	by * none
    olcAccess: {1}to dn.base="" by * read
    olcAccess: {2}to *
    	by dn="cn=Manager,dc=cluster,dc=lan" write
    	by * read

Let us break down the different aspects of the LDIF file.

.. code-block:: bash

    dn: olcDatabase={1}monitor,cn=config
    changetype: modify
    replace: olcAccess
    olcAccess: {0}to *
    	by dn.base="gidNumber=0+uidNumber=0,cn=peercred,cn=external,cn=auth" read
    	by dn.base="cn=Manager,dc=cluster,dc=lan" read
    	by * none



This secures the monitor database so that only trusted users (local root or LDAP admin) can 
read it. Protects sensitive runtime information from unauthorised users. In the above In 
OpenLDAP, a database (different from a SQL database) is a storage backend for LDAP entries. 
Each backend can have its own configuration, root DN, access controls, and data.

.. code-block:: bash

    dn: olcDatabase={2}mdb,cn=config
    changetype: modify
    replace: olcSuffix
    olcSuffix: dc=cluster,dc=lan

This sets the LDAP domain for the main database. It defines the LDAP root for the main database 
and establishes the domain name under which all directory entries (users, groups, organisational 
units) are stored. Changing this is effectively changing the LDAP domain (cluster.lan).


.. code-block:: bash

    dn: olcDatabase={2}mdb,cn=config
    changetype: modify
    replace: olcRootDN
    olcRootDN: cn=Manager,dc=cluster,dc=lan

This modifies another existing database ({2}mdb) in LDAP, and it changes the admin account for
 that database. The root user (administrator) for that database is now 
 `cn=Manager,dc=cluster,dc=lan`. 


In an OpenLDAP server, the `{2}mdb` and `{1}monitor` databases serve distinctly different 
purposes. The {2}mdb database is the primary directory backend, storing all real LDAP entries 
such as users, groups, and organizational units under the domain defined by its suffix 
(e.g., `dc=cluster,dc=lan`). It has a defined root DN (`cn=Manager`) with full administrative 
privileges and supports read and write operations controlled by access control rules. 

In contrast, the `{1}monitor` database is a special read-only system database that provides 
internal monitoring information about the LDAP server, such as active connections, operations 
per second, and cache statistics.



Access to `{1}monitor` is strictly limited to the local root user or the LDAP admin for 
security purposes, and it does not contain or manage actual directory entries. While `{2}mdb`
is essential for the functioning of the directory and user management, `{1}monitor` exists 
solely for server monitoring and operational insight.


.. code-block:: bash

    dn: olcDatabase={2}mdb,cn=config
    changetype: modify
    add: olcAccess
    olcAccess: {0}to attrs=userPassword,shadowLastChange
    	by dn="cn=Manager,dc=cluster,dc=lan" write
    	by anonymous auth
    	by self write
    	by * none
    olcAccess: {1}to dn.base="" by * read
    olcAccess: {2}to *
    	by dn="cn=Manager,dc=cluster,dc=lan" write
    	by * read



This snippet defines access control rules (ACLs) for the main LDAP database (`{2}mdb`) to 
control who can read or write entries and attributes.



In summary, the above configuration sets the LDAP domain to cluster.lan, defines the admin user, 
sets the databases, and establishes access control rules. Now apply the configuration using 
the following commands:

.. code-block:: bash

    sudo ldapmodify -Y EXTERNAL -H ldapi:/// -f setdomain.ldif

Verify the naming contexts to ensure the domain is set correctly:

.. code-block:: bash

    sudo ldapsearch -H ldap:// -x -s base -b "" -LLL "namingContexts"

The next step is to add organizational units (OUs) to the LDAP directory. For this, create a 
file named addou.ldif with the following content:

.. code-block:: bash

    dn: dc=cluster,dc=lan
    objectClass: top
    objectClass: dcObject
    objectClass: organization
    o: Cluster Organisation
    dc: cluster

    dn: cn=Manager,dc=cluster,dc=lan
    objectClass: organizationalRole
    cn: Manager
    description: OpenLDAP Manager

    dn: ou=People,dc=cluster,dc=lan
    objectClass: organizationalUnit
    ou: People

    dn: ou=Group,dc=cluster,dc=lan
    objectClass: organizationalUnit
    ou: Group



Let us break down the ldif file:


.. code-block:: bash


    dn: dc=cluster,dc=lan
    objectClass: top
    objectClass: dcObject
    objectClass: organization
    o: Cluster Organisation
    dc: cluster

This entry creates the root of your LDAP directory tree for the domain `cluster.lan`, serving 
as the parent for all other entries such as users, groups, and organisational units, while 
also providing organisational information for the directory.


.. code-block:: bash

    dn: cn=Manager,dc=cluster,dc=lan
    objectClass: organizationalRole
    cn: Manager
    description: OpenLDAP Manager

This entry creates the Manager role in LDAP, which acts as the administrative user (Root DN) 
for the database. It is used to perform all privileged operations, such as adding or modifying 
users, groups, and organisational units.


.. code-block:: bash

    dn: ou=People,dc=cluster,dc=lan
    objectClass: organizationalUnit
    ou: People

    dn: ou=Group,dc=cluster,dc=lan
    objectClass: organizationalUnit
    ou: Group

These entries create two organisational units under the LDAP root:

* `ou=People`: container for user accounts.

* `ou=Group`: container for group entries.

Using OUs keeps the LDAP directory structured and manageable, allowing hierarchical 
organisation of users and groups. Apply the changes using the following command:


.. code-block:: bash

    sudo ldapadd -x -D cn=Manager,dc=cluster,dc=lan -W -f addou.ldif

Finally we add a user calles testuser1 to the LDAP directory. First, generate a password hash 
for the user using slappasswd.

.. code-block:: bash

    slappasswd

In this setup, we use the password `testuser`. Let's assume the hash generated is `{SSHA}yJcv+xLWUvgAWu+fdNN/K6V4cdS4PC5E`. 
Then create a file named `user1.ldif` with the following content:

.. code-block:: bash

    dn: uid=testuser1,ou=People,dc=cluster,dc=lan
    objectClass: inetOrgPerson
    objectClass: posixAccount
    objectClass: shadowAccount
    cn: testuser1
    sn: user
    userPassword: {SSHA}yJcv+xLWUvgAWu+fdNN/K6V4cdS4PC5E
    loginShell: /bin/bash
    uidNumber: 2001
    gidNumber: 2001
    homeDirectory: /scratch/userhome/testuser1
    shadowLastChange: 0
    shadowMax: 0
    shadowWarning: 0

    dn: cn=testuser1,ou=Group,dc=cluster,dc=lan
    objectClass: posixGroup
    cn: testuser1
    gidNumber: 2001
    memberUid: testuser1



This LDIF file creates the user `testuser1` belongs to the group `testuser1` (gidNumber=2001). 
This setup is typical for LDAP-based UNIX/Linux accounts, where each user has a private group. 
Add the user using the following command:

.. code-block:: bash

    sudo ldapadd -x -D cn=Manager,dc=cluster,dc=lan -W -f user1.ldif

Verify that the user has been added successfully:

.. code-block:: bash

    sudo ldapsearch -x -b "ou=People,dc=cluster,dc=lan"



Next we will enable TLS for secure LDAP communication. First, generate a self-signed TLS 
certificate:

.. code-block:: bash

    sudo openssl req -x509 -nodes -days 365 -newkey rsa:2048 -keyout /etc/pki/tls/ldapserver.key -out /etc/pki/tls/ldapserver.crt

    sudo chown ldap:ldap /etc/pki/tls/{ldapserver.crt,ldapserver.key}

Then create a file named `tls.ldif` with the following content:

.. code-block:: bash

    dn: cn=config
    changetype: modify
    replace: olcTLSCACertificateFile
    olcTLSCACertificateFile: /etc/pki/tls/ldapserver.crt
    -
    replace: olcTLSCertificateFile
    olcTLSCertificateFile: /etc/pki/tls/ldapserver.crt
    -
    replace: olcTLSCertificateKeyFile
    olcTLSCertificateKeyFile: /etc/pki/tls/ldapserver.key

The ldif file specifies the paths to the TLS certificate and key files. Next apply the TLS

configuration using the command:

.. code-block:: bash

    sudo ldapadd -Y EXTERNAL -H ldapi:/// -f tls.ldif

Then make sure the `/etc/openldap/ldap.conf` file is configured to use TLS:

.. code-block:: bash

    TLS_CACERT  /etc/pki/tls/cert.pem
    TLS_REQCERT never



LDAP Client Configuration
~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~


Now that the LDAP server is set up and running , we can setup the LDAP client. Ideally, an 
HPC system should have a file system to manage user home directories. In our case, we will 
host all the user home directories under the `/scratch` file system. In the `/scratch` directory, 
create a directory `userhome` to be used as the base home directory for LDAP users:

.. code-block:: bash

    sudo mkdir -p /scratch/userhome
    sudo chown root:root /scratch/userhome
    sudo chmod 755 /scratch/userhome

On the client nodes, install and configure the LDAP client:

.. code-block:: bash

    sudo dnf install openldap-clients sssd sssd-ldap oddjob-mkhomedir -y
    sudo authselect select sssd with-mkhomedir --force

Enable and start the oddjobd service to support home directory creation:

.. code-block:: bash

    sudo systemctl enable --now oddjobd.service
    sudo systemctl status oddjobd.service

Then configure the LDAP client by editing the `/etc/openldap/ldap.conf` file:

.. code-block:: bash

    URI ldap://node1/
    BASE dc=cluster,dc=lan



After this, configure SSSD by editing the `/etc/sssd/sssd.conf` file:

.. code-block:: bash

    [domain/default]
    id_provider = ldap
    autofs_provider = ldap
    auth_provider = ldap
    chpass_provider = ldap

    ldap_uri = ldap://node1/
    ldap_search_base = dc=cluster,dc=lan
    ldap_id_use_start_tls = True

    ldap_tls_cacertdir = /etc/openldap/certs
    cache_credentials = True
    ldap_tls_reqcert = allow

    [sssd]
    services = nss, pam, autofs
    domains = default

    [nss]
    homedir_substring = /scratch/userhome/%u



Once the configuration is done, set the appropriate permissions for the 
`/etc/sssd/sssd.conf` file and start the service:


.. code-block:: bash

    sudo chmod 0600 /etc/sssd/sssd.conf
    sudo systemctl start sssd

    sudo systemctl enable sssd
    sudo systemctl status sssd
    sudo sss_cache -E

Then verify that LDAP user created on the LDAP serever (node1)  can be resolved from the 
LDAP client (node2):

.. code-block:: bash

    getent passwd testuser1

Then try to log in to the client node using the LDAP user:

.. code-block:: bash

    su - testuser1


If `SELinux` is not disabled, it can interfere with LDAP authentication. Especially the home 
directory creation. Now, you should be able to log in using the LDAP user credentials. 
Try logging in via SSH (from the local system):

.. code-block:: bash

    ssh testuser1@<ip of the login node>

