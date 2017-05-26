
#!/bin/bash

# echo commands and exit on any error
set -xe

# determine our ORDINAL value
ORDINAL=${1#*-}

if [[ $ORDINAL -eq 1 ]]; then

  # for purposes of recovery ordinal value of 1 is considered the master

  # check for the backup file
  [[ -f /tmp/etcd-backup.tar.gz ]] || echo "** failed to find backup, exiting"

  # stop etcd2 (should have already been stopped by ansible tasks)
  systemctl stop etcd2

  # remove old datadir
  rm -rf /var/lib/etcd2/member

  # extract backup
  tar xfzv /tmp/etcd-backup.tar.gz -C /var/lib/etcd2
  # fix permissions
  chown -R etcd:etcd /var/lib/etcd2

  # create our drop-in
  cat << EOF > /etc/systemd/system/etcd2.service.d/98-force-new-cluster.conf
[Service]
Environment="ETCD_FORCE_NEW_CLUSTER=true"
Environment="ETCD_ADVERTISE_CLIENT_URLS=http://$2:2379"
Environment="ETCD_INITIAL_ADVERTISE_PEER_URLS=http://$2:2380"
Environment="ETCD_LISTEN_CLIENT_URLS=http://0.0.0.0:2379"
Environment="ETCD_LISTEN_PEER_URLS=http://0.0.0.0:2380"
EOF

  # reload systemd and start etcd2
  systemctl daemon-reload
  systemctl start etcd2

  # etcd takes a few seconds to come up, sleep an arbitrary amount
  /bin/sleep 8

  # now we need to update our member
  MEMBER_ID=`etcdctl member list | grep $2 | awk -F: '{print $1}'`

  etcdctl member update $MEMBER_ID http://$2:2380

fi
