Role Name
=========
ans-ems-oracle-lnx-cli

# Installs Oracle 11G-19C Linux Client for Build Ops Infrastructure

Automation Summary
------------------
This automation will:
- Fetch and install any RHEL Oracle Client Binary Version specified --> COMPLETE
- Drop in the tnsnames.ora connection information for the client server --> COMPLETE

Author Information
------------------
Kezie Iroha - EMS DBA - kiroha@kiroha.com

Status
------
- RHEL7 Complete -> JIRA: https://jira.kiroha.com/browse/ECISDB-512
- RHEL8 WIP -> JIRA: https://jira.kiroha.com/browse/ECISDB-421

Ansible Test Version
--------------------
Tested on Ansible 2.7.9

Requirements
------------
- Red Hat Linux 6/7/8
- common role is shared between project roles

Roles
-----
- common
- oracle-lnx-cli-pull-deploy

Role Variables
--------------
Pre-defined static variables are in the common folder. Do not change these

Runtime variables are defined in the cloud-deploy-oracle-cli.yml file and require the following:

    # specify cloud artifactory proxy data centre: LIT, AM3
    artifactory_dc: LIT 

    # specify one of 11G, 12CR1, 12CR2, 18C, 19C
    # 11G - Oracle 11.2.0.4
    # 12CR1 - Oracle 12.1.0.2
    # 12CR2 - Oracle 12.2.0.1
    # 18C - Oracle 18.x.0.0
    # 19C - Oracle 19.x.0.0
    oracle_version: 19C

    # Specify base Install Location /opt or /U01
    # If you specify /opt then please ensure that it has been sized with at least 6GB for the oracle client. 
    # This should preferably be a dedicated mount /opt/app/oracle on the linux app server
    cli_install_loc: /opt

    # Specify the name of the oracle sid and oracle db host that this client will connect to
    oracle_sid: MYDB1
    oracle_fqdn: mydb1.cust.some.host

    # Install Oracle client linux rpm (default no)
    update_rpm: no


Dependencies
------------
- The Oracle client on Build Ops app servers usually install to /opt. Ensure that sufficient storage has been allocated to /opt - at least 5gb for the Oracle client. This should preferably be a dedicated mount: /opt/app/oracle

- Dependency on common role included in project ans-ems-oracle-lnx-db

- Note - Only Oracle versions >=19c are certified on RHEL 8
See - https://confluence.kiroha.com/display/ED/Oracle+Database-Client+OS+Certification+-+All+Platforms


Ansible Tower Playbooks
-----------------------
tower*.yml plays are used by ansible tower templates


Build Ops Playbooks
--------------------
Roles can be deployed via command line using the plays cloud*.yml

Dry Run:
 - ansible-playbook -i inventory_file roles/ans-ems-oracle-lnx-cli/cloud-deploy-oracle-lnx-cli.yml -C -v -u <your_username> --ask-pass --ask-become-pass

Actual Run:
 - ansible-playbook -i inventory_file roles/ans-ems-oracle-lnx-cli/cloud-deploy-oracle-lnx-cli.yml -v -u <your_username> --ask-pass --ask-become-pass

License
-------
kiroha

