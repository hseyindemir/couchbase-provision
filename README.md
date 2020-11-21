couchbase-provision
=========

Generic Ansible role for couchbase cluster formation. This role is responsible for creating and configuring couchbase cluster. It includes;
* Installation of required couchbase packages
* Cluster formation
  * Initializing all nodes with different data directory
  * Creating cluster for the main node
  * Adding the other nodes to the cluster
* Cluster configuration
  * Setting autofailover configuration
  * Creating default user groups
  * Configuring backup

Requirements
------------

* Jinja2 >= 2.8
* Ansible >= 2.9

Role Variables
--------------
```ansible
couchbase_version: 6.5.1
rhel_jdk_version: java-1.8.0-openjdk
debian_jdk_version: openjdk-8-jdk
rhel_cb_package: https://packages.couchbase.com/releases/couchbase-release/couchbase-release-1.0-x86_64.rpm
debian_cb_package: https://packages.couchbase.com/releases/couchbase-release/couchbase-release-1.0-amd64.deb
mountpoint: /cb-data
do_init_different_mounpoint: 'yes'
```


Example Playbook
----------------

```ansible
---
- hosts: all
  become: true
  roles:
    - role: couchbase-provision
- name: Initialize the cluster on the coordinator node
  hosts: couchbase-main
  tasks:
  - name: Initialize the Cluster from Couchbase-Main Node
    shell: /opt/couchbase/bin/couchbase-cli cluster-init -c {{ ansible_ssh_host }}:8091  --cluster-username={{ couchbase_user }} --cluster-password={{ couchbase_password }} --cluster-port=8091 --cluster-ramsize=2048 --services=data
    become: true
    args:
      executable: /bin/bash
    ignore_errors: yes

- name: Add nodes to cluster after cluster formation
  hosts: couchbase-others
  become: true
  tasks:
  - name: Add Node to the Cluster
    shell: /opt/couchbase/bin/couchbase-cli server-add --cluster {{ cb_main_node }} --username {{ couchbase_user }} --password {{ couchbase_password }} --server-add={{ ansible_ssh_host }} --server-add-username={{ couchbase_user }} --server-add-password={{ couchbase_password }} --services={{ node_role }}
    become: true
    args:
      executable: /bin/bash
    ignore_errors: yes

- name: Couchbase Cluster Formation Post Configuration
  hosts: couchbase-main
  become: true
  tasks:
  - name: Rebalance Cluster
    shell: /opt/couchbase/bin/couchbase-cli rebalance --cluster {{ cb_main_node }} --username {{ couchbase_user }} --password {{ couchbase_password }} --no-progress-bar
    become: true
    args:
      executable: /bin/bash
    ignore_errors: yes
  - name: Configure autofailover
    shell: /opt/couchbase/bin/couchbase-cli setting-autofailover -c {{ cb_main_node }} -u {{ couchbase_user }} --password {{ couchbase_password }} --enable-auto-failover 1 --auto-failover-timeout 30
    become: true
    args:
      executable: /bin/bash
    ignore_errors: yes

  - name: Configure wizard group
    shell: /opt/couchbase/bin/couchbase-cli user-manage --cluster http://{{ cb_main_node }} --username {{ couchbase_user }} --password {{ couchbase_password }} --set-group --group-name theMagic --roles cluster_admin
    become: true
    args:
      executable: /bin/bash
    ignore_errors: yes
  - name: Configure replication group
    shell: /opt/couchbase/bin/couchbase-cli user-manage \
           --cluster http://{{ cb_main_node }} \
           --username {{ couchbase_user }} \
           --password {{ couchbase_password }} \
           --set-group \
           --group-name replicationGroup \
           --roles replication_admin
    become: true
    args:
      executable: /bin/bash
    ignore_errors: yes

  - name: Configure monitoring group
    shell: /opt/couchbase/bin/couchbase-cli user-manage \
           --cluster http://{{ cb_main_node }} \
           --username {{ couchbase_user }} \
           --password {{ couchbase_password }} \
           --set-group \
           --group-name monitoringGroup \
           --roles ro_admin
    become: true
    args:
      executable: /bin/bash
    ignore_errors: yes

  - name: Configure dataops group
    shell: /opt/couchbase/bin/couchbase-cli user-manage \
           --cluster http://{{ cb_main_node }} \
           --username {{ couchbase_user }} \
           --password {{ couchbase_password }} \
           --set-group \
           --group-name dataOpsGroup \
           --roles data_dcp_reader[*]
    become: true
    args:
      executable: /bin/bash
    ignore_errors: yes

  - name: Configure adpplicationadmin group
    shell: /opt/couchbase/bin/couchbase-cli user-manage \
           --cluster http://{{ cb_main_node }} \
           --username {{ couchbase_user }} \
           --password {{ couchbase_password }} \
           --set-group \
           --group-name applicationAdminGroup \
           --roles bucket_full_access[*],data_reader[*],data_writer[*],views_admin[*],query_select[*],query_insert[*],query_update[*],query_delete[*],query_manage_index[*],fts_admin[*],analytics_manager[*],data_dcp_reader[*]
    become: true
    args:
      executable: /bin/bash
    ignore_errors: yes
- name: Configure Backup for Cluster
  hosts: couchbase-backup
  become: true
  roles:
    - role: cb-backup
      vars:
        cluster_name: "{{ couchbase_backup_logical_name }}"
        username: "{{ couchbase_user }}"
        password: "{{ couchbase_password }}"
        server_address: "{{ cb_main_node }}"
        period: 30
        mountpoint: /cb-data
- name: Install exporters
  hosts: all
  roles:
    - role: mesaguy.prometheus
      vars:
        prometheus_manage_client_tgroups: false
        prometheus_node_exporter_port: 9120
        prometheus_couchbase_exporter_blakelead_port: 9421
        prometheus_couchbase_exporter_blakelead_env_vars:
          CB_EXPORTER_DB_USER: "{{ couchbase_user }}"
          CB_EXPORTER_DB_PASSWORD: "{{ couchbase_password }}"
        prometheus_node_exporter_textfiles_directory: '/opt/prometheus/etc/node_exporter_textfiles'
        prometheus_components:
          - node_exporter
          - couchbase_exporter_blakelead
```
Example Inventory
----------------

```ansible
[couchbase-main]
node-1 ansible_ssh_host=ip_1 node_role=data


[couchbase-others]
node-2 ansible_ssh_host=ip_2 node_role=data
node-3 ansible_ssh_host=ip_3 node_role=data

[couchbase-backup]
node-backup ansible_ssh_host=ip_4

[all:vars]
cb_main_node=ip_1
couchbase_user=some_god_mode_user
couchbase_password=some_pass
cluster_name=a_pretty_cluster_name
couchbase_backup_logical_name=a_pretty_name
ansible_ssh_user=some_ssh_user
ansible_ssh_private_key_file=pem_file_if_exists
```

Running the Playbook
------------------
```bash
ansible-playbook -i inventory deployment.yml
```


Contributors
------------------
* Hüseyin DEMİR
