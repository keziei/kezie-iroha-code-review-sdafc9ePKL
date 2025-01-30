Role Name
=========
oracle-lnx-patch-db

# Apply Oracle 11G-19C Single Instance Database PSU (Patch Set Update) for Build Ops DB Infrastructure

Automation Summary
------------------
This automation will:
- Fetch and Apply any Database Patch
- 

Author Information
------------------
Kezie Iroha - EMS DBA - kiroha@kiroha.com

Status
------
- WIP https://jira.kiroha.com/browse/ECISDB-1582

Ansible Test Version
--------------------
Tested on Ansible 2.9

Requirements
------------
- Linux host configured to Build Ops CRG specification for Oracle database
- Red Hat Linux 6/7/8
- common role is shared between project roles

Roles
-----
- common
- oracle-lnx-patch-db

Role Variables
--------------
Pre-defined static variables are in the roles/common folder. Do not change these

Command line runtime variables are defined in the cloud*.yml plays and require the following:
 


Dependencies
------------
Dependency on common role included in project ans-ems-oracle-lnx-db


Ansible Tower Playbooks
-----------------------
tower*.yml plays are used by ansible tower templates

Build Ops Playbooks
--------------------
Roles can be deployed via command line using the plays cloud*.yml

Syntax Check:
 - ansible-playbook ans-ems-oracle-lnx-db/cloud-oracle-lnx-db-patch.yml --syntax-check

Dry Run:
 - ansible-playbook -i inventory_file roles/ans-ems-oracle-lnx-db/cloud-oracle-lnx-db-patch.yml -C -v -u <your_username> --ask-pass --ask-become-pass

Actual Run:
 - ansible-playbook -i inventory_file roles/ans-ems-oracle-lnx-db/cloud-oracle-lnx-db-patch.yml -u <your_username> --ask-pass --ask-become-pass

Other Notes
-----------
To get the cumulative timing of tasks, please add this to your ansible.cfg default setting:

  callback_whitelist = profile_tasks

License
-------
kiroha
