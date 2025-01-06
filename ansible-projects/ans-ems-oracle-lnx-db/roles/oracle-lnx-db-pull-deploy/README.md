Role Name
=========
ans-ems-oracle-lnx-db

# Installs Oracle 11G-19C Single Instance Database for Build Ops DB Infrastructure

Automation Summary
------------------
This automation will:
- Fetch and install any oracle database binary version specified --> COMPLETE
- Fetch and apply the latest database PSU (patch set update) to the Oracle Home --> COMPLETE
- Fetch and install DBA Oracle tools - SQL Health Check, Remote Diagnostic Agent, AHF (oracle autonomous health framework), OSwatcher etc --> COMPLETE
- Fetch and install the Oracle EM13c monitoring agent and EM13c API Client  --> COMPLETE
- Create, patch and configure the oracle database according to the kiroha CRG and Product best practise specification --> COMPLETE
- Vary the Oracle database build by characterset or size --> COMPLETE
- Create kiroha product schemas specified for the oracle database --> COMPLETE
- Configure backups for the customer database and schedule cron jobs --> COMPLETE
- Perform an Oracle Health Check of the Database Build --> COMPLETE
- Align database SGA with Cloud EMS Huge Page memory specification --> COMPLETE
- Promote EM13c targets and enable EM13c database monitoring --> COMPLETE

Author Information
------------------
Kezie Iroha - EMS DBA - kiroha@kiroha.com

Status
------
- RHEL7 Complete -> JIRA: https://jira.kiroha.com/browse/ECISDB-513
- RHEL8 WIP -> JIRA: https://jira.kiroha.com/browse/ECISDB-421 

Ansible Test Version
--------------------
Tested on Ansible 2.7.9

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

    # specify cloud artifactory proxy data centre: LIT, AM3
    artifactory_dc: LIT 

    # specify one of 11G, 12CR1, 12CR2, 18C, 19C
    # 11G - Oracle 11.2.0.4
    # 12CR1 - Oracle 12.1.0.2
    # 12CR2 - Oracle 12.2.0.1
    # 18C - Oracle 18.x.0.0
    # 19C - Oracle 19.x.0.0
    oracle_version: 19C

    # Specify the name of the database defined on the CRG
    oracle_sid: MYDB1

    # List the Oracle DB app schemas defined on the CRG
    app_schemas: 
      - CSUSR 
      - ARCUSR 

    # Build size options for Build Ops are NORMAL or SMALL.  
    # Build size for Build Ops is always the NORMAL CRG specification
    # For GCP LAB you may select SMALL which reduces redo sizing and archived log multiplexing
    build_size: NORMAL

    # Build type options are STD or UTF8
    # Build type is always STD (standard build, using AL32UTF8). 
    # On occasion, for specific products a UTF8 build will be specified in the CRG.
    build_type: STD

    # To destroy a previous build and re-run the playbook, specify: "cleanup: true"
    # Ensure that you have specified the correct oracle_sid, oracle_version and host before doing this!
    # If you do not intend to cleanup the build then leave the parameter commented out 
    # cleanup: true    


Dependencies
------------
Dependency on common role included in project ans-ems-oracle-lnx-db

Note - Only Oracle versions >=19c are certified on RHEL 8
 - See - https://confluence.kiroha.com/display/ED/Oracle+Database-db+OS+Certification+-+All+Platforms

The minimum expected filesystem size for a Build Ops Oracle build is:
  - /U01 50GB
  - /U02 5GB (small build), 50GB (normal build)
  - /U03 5GB (small build), 50GB (normal build)
  - /U04 100GB
  - /U05 80GB
  - /U06 80GB (U06 archive dest excluded in small build)
  - /Export 200GB
  - /Fast_Recovery 50GB (small build), 180GB (normal build)

Ansible Tower Playbooks
-----------------------
tower*.yml plays are used by ansible tower templates

Build Ops Playbooks
--------------------
Roles can be deployed via command line using the plays cloud*.yml

Syntax Check:
 - ansible-playbook ans-ems-oracle-lnx-db/cloud-deploy-oracle-lnx-db.yml --syntax-check

Dry Run:
 - ansible-playbook -i inventory_file roles/ans-ems-oracle-lnx-db/cloud-deploy-oracle-lnx-db.yml -C -v -u <your_username> --ask-pass --ask-become-pass

Actual Run:
 - ansible-playbook -i inventory_file roles/ans-ems-oracle-lnx-db/cloud-deploy-oracle-lnx-db.yml -u <your_username> --ask-pass --ask-become-pass

Other Notes
-----------
To get the cumulative timing of tasks, please add this to your ansible.cfg default setting:

  callback_whitelist = profile_tasks

License
-------
kiroha
