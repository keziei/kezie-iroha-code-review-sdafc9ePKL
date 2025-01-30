Role Name
=========
ansible-win-oracle-cli

# Installs Oracle 11G-19C Windows Client for Build Ops Infrastructure

Automation Summary
------------------
This automation will:
- Fetch and install any Windows Oracle Client Binary Version specified --> COMPLETE
- Drop in the tnsnames.ora connection information for the client server --> COMPLETE
- Fetch and Deploy SQL Developer

Author Information
------------------
Kezie Iroha - EMS DBA - kiroha@kiroha.com

Status
------
- Windows deploy Complete ->  https://jira.kiroha.com/browse/ECISDB-516

Ansible Test Version
--------------------
Tested on Ansible 2.7.9

Requirements
------------
- Windows

Roles
-----
- common
- oracle-win-cli-pull-deploy

Role Variables
--------------
Pre-defined static variables are in the common folder. Do not change these

Runtime variables are defined in the cloud-deploy-oracle-cli.yml file and require the following:

    # Ansible runtime vars for windows
    # https://docs.ansible.com/ansible/latest/user_guide/windows_winrm.html
    # https://docs.ansible.com/ansible/latest/user_guide/windows_setup.html

    ansible_user: Username
    ansible_password: Password
    ansible_connection: winrm
    ansible_winrm_transport: kerberos
    ansible_port: 5985
    ansible_winrm_server_cert_validation: ignore

    # install_loc: specify base install file system for the oracle client, this is usually D:
    install_loc: 'D:'

    # specify cloud artifactory proxy data centre: LIT, AM3
    artifactory_dc: LIT

    # specify one of 11G, 12CR1, 12CR2, 18C, 19C
    # 11G - Oracle 11.2.0.4
    # 12CR1 - Oracle 12.1.0.2
    # 12CR2 - Oracle 12.2.0.1
    # 18C - Oracle 18.x.0.0
    # 19C - Oracle 19.x.0.0
    oracle_version: 19C

    # Specify the name of the oracle sid and oracle db host that this client will connect to
    oracle_sid: MYDB1
    oracle_fqdn: mydb1.cust.some.host

    # Specify yes to uninstall an existing binary version
    remove_existing_client: no


Dependencies
------------
Note - Only Oracle versions >=19c are certified on Windows 2019
- See - https://confluence.kiroha.com/display/ED/Oracle+Database-Client+OS+Certification+-+All+Platforms


Ansible Tower Playbooks
-----------------------
tower*.yml plays are used by ansible tower templates


Build Ops Playbooks
--------------------
Roles can be deployed via command line using the plays cloud*.yml

Dry Run:
 - ansible-playbook -i inventory_file roles/ans-ems-oracle-win-cli/cloud-deploy-oracle-win-cli.yml -C -v -u <your_username> --ask-pass --ask-become-pass

Actual Run:
 - ansible-playbook -i inventory_file roles/ans-ems-oracle-win-cli/cloud-deploy-oracle-win-cli.yml -v -u <your_username> --ask-pass --ask-become-pass


License
-------
kiroha

