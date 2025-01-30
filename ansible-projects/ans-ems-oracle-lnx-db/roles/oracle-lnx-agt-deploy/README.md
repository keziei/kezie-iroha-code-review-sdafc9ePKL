Role Name
=========
oracle-lnx-agt-deploy

# Install Oracle EM13c Linux Agent for Build Ops Infrastructure, or Run Root Scripts only for Existing installation

Automation Summary
------------------
This automation will:
- Fetch and install EM13c Agent Image

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
- oracle-lnx-agt-deploy

Role Variables
--------------
    # specify cloud artifactory proxy data centre: LIT (NA), AM3 (EU)
    artifactory_dc: LIT 

    # Perform a new agent installation yes/no?
    agt_install: yes/no

    # Run Agent Root script only on an existing installation which has been upgraded yes/no?
    root_only: yes/no

    # Default Agent location is /U01/app/oracle/product/Agent13c
    # Specify an alternative agent location if required
    agent_install_dir: /U01/app/oracle/product/Agent13c


Dependencies
------------


Ansible Tower Playbooks
-----------------------
tower*.yml plays are used by ansible tower templates


Build Ops Playbooks
--------------------
Roles can be deployed via command line using the plays cloud*.yml

Dry Run:
 - ansible-playbook -i inventory_file roles/ans-ems-oracle-lnx-db/cloud-lnx-agt-deploy.yml -C -v -u <your_username> --ask-pass --ask-become-pass

Actual Run:
 - ansible-playbook -i inventory_file roles/ans-ems-oracle-lnx-db/cloud-lnx-agt-deploy.yml -v -u <your_username> --ask-pass --ask-become-pass


License
-------
kiroha

