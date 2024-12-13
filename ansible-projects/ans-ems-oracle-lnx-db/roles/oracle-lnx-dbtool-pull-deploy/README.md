Role Name
=========
oracle-lnx-dbtool-pull-deploy

# Installs/Updates Oracle Autonomous Health Framework and Tools

Automation Summary
------------------
This automation will:
- Fetch and install DBA Oracle tools - SQL Health Check, Remote Diagnostic Agent, AHF (oracle autonomous health framework), OSwatcher etc 


Author Information
------------------
Kezie Iroha - EMS DBA - kiroha@kiroha.com

Status
------

Requirements
------------
- Linux host configured to Build Ops CRG specification for Oracle database
- Red Hat Linux 6/7/8
- common role is shared between project roles

Roles
-----
- common
- oracle-lnx-db-pull-deploy

Role Variables
--------------
Pre-defined static variables are in the roles/common folder. Do not change these

Command line runtime variables are defined in the cloud*.yml plays and require the following:



Dependencies
------------
Dependency on common role included in project oracle-lnx-dbtool-pull-deploy


Ansible Tower Playbooks
-----------------------
tower*.yml plays are used by ansible tower templates

Build Ops Playbooks
--------------------
Roles can be deployed via command line using the plays cloud*.yml

Syntax Check:
 - ansible-playbook oracle-lnx-dbtool-pull-deploy/cloud-lnx-dbtool-deploy.yml --syntax-check

Dry Run:
 - ansible-playbook -i inventory_file roles/oracle-lnx-dbtool-pull-deploy/cloud-lnx-dbtool-deploy.yml -C -v -u <your_username> --ask-pass --ask-become-pass

Actual Run:
 - ansible-playbook -i inventory_file roles/oracle-lnx-dbtool-pull-deploy/cloud-lnx-dbtool-deploy.yml -u <your_username> --ask-pass --ask-become-pass

Other Notes
-----------
To get the cumulative timing of tasks, please add this to your ansible.cfg default setting:

  callback_whitelist = profile_tasks

License
-------
kiroha
