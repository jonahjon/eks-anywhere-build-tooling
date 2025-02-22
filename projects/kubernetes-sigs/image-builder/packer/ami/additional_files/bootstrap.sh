#!/bin/bash
source /etc/eks/logging.sh

set -uxo pipefail

SCRIPT_LOG=/var/log/eks-bootstrap.log
touch $SCRIPT_LOG

# save stdout and stderr to file descriptors 3 and 4,
# then redirect them to "$SCRIPT_LOG"
# restore stdout and stderr at bottom of script
exec 3>&1 4>&2 >>$SCRIPT_LOG 2>&1

echo "127.0.0.1   $(hostname)" >>/etc/hosts

NETWORK_CONFIG_PATH=/tmp/network.yaml
NETPLAN_CONFIG_PATH=/etc/netplan/config.yaml

# configure DNI
DNI_COUNT=$(grep -E "dniCount" $NETWORK_CONFIG_PATH | awk '{print $2}')
DNI_LIST=$(ip -br link | grep -Ev 'lo|ens3' | awk '{print $1}')
while [ -z "$DNI_LIST" ] || [[ $(echo "$DNI_LIST" | wc -l) != "$DNI_COUNT" ]]
do
  # creating DNI is a separate api call, which has some delays
  log::info "DNI is not ready, retrying"
  sleep 5
  DNI_LIST=$(ip -br link | grep -Ev 'lo|ens3' | awk '{print $1}')
done
log::info "Using DNI: $DNI_LIST"

DEFAULT_GATEWAY=$(ip r | grep default | awk '{print $3}')
log::info "Using default gateway: $DEFAULT_GATEWAY"

# route imds traffic to private nic
cat<<EOF >"$NETPLAN_CONFIG_PATH"
network:
    version: 2
    renderer: networkd
    ethernets:
        ens3:
            routes:
                - to: 169.254.169.254
                  via: $DEFAULT_GATEWAY
EOF

METRIC=0
INDEX=1
for DNI in $(ip -br link | grep -Ev 'lo|ens3' | awk '{print $1}')
do
MAC=$(ip -br link | grep -E "$DNI" |  awk '{print $3}')
if ! grep -q "static" "$NETWORK_CONFIG_PATH"
then
echo "Configuring DHCP"
cat<<EOF >>"$NETPLAN_CONFIG_PATH"
        $DNI:
            set-name: $DNI
            dhcp4: true
            dhcp-identifier: mac
            dhcp4-overrides:
                route-metric: $METRIC
                send-hostname: true
                hostname: $(hostname)
            match:
                macaddress: $MAC
EOF
else
echo "Configuring static ips: $(cat $NETWORK_CONFIG_PATH)"
STATIC_IP=$(awk -v j="$INDEX" '/address/{i++}i==j{print;exit}' $NETWORK_CONFIG_PATH | awk '{print $3}')
GATEWAY=$(awk -v j="$INDEX" '/gateway/{i++}i==j{print;exit}' $NETWORK_CONFIG_PATH | awk '{print $2}')
if grep -A 2 "$STATIC_IP" "$NETWORK_CONFIG_PATH" | grep -q "primary"
then
METRIC=0
else
METRIC=50
fi
cat<<EOF >>"$NETPLAN_CONFIG_PATH"
        $DNI:
            set-name: $DNI
            addresses:
                - $STATIC_IP
            routes:
                - to: default
                  via: $GATEWAY
                  metric: $METRIC
            match:
                macaddress: $MAC
EOF
fi
METRIC=50
((INDEX=INDEX+1))
done

netplan --debug apply

sleep 5
DNI_IP_LIST=$(ip route show | grep -Ev 'default|lo|ens3'  | awk '{print $9}' | sort | uniq)
while [ -z "$DNI_IP_LIST" ] || [[ $(echo "$DNI_IP_LIST" | wc -l) != "$DNI_COUNT" ]]
do
    # if ip is not ready in 5 s, need to retry netplan apply
    log::info "IP is not ready, retrying"
    netplan --debug apply
    sleep 5
    DNI_IP_LIST=$(ip route show | grep -Ev 'default|lo|ens3' | awk '{print $9}' | sort | uniq)
done
log::info "IP leased: $DNI_IP_LIST"

log::info "network configuration finished"

# mount container data volume if exists
DEVICE=$(lsblk | grep -E vd | awk '{print $1}')
if [ -n "$DEVICE" ]; then
    log::info "found new device /dev/$DEVICE"

    # stop containerd and kubelet
    systemctl stop containerd
    systemctl stop kubelet

    MOUNT_POINT=/var/lib/containerd
    BACKUP_DIR=/var/lib/containerd_backup

    # backup containerd data
    mv "$MOUNT_POINT" "$BACKUP_DIR"

    # recreate dir
    mkdir "$MOUNT_POINT"

    # format disk
    mkfs -t ext4 /dev/"$DEVICE"

    # mount new device
    echo "/dev/$DEVICE $MOUNT_POINT     ext4    defaults        0 0" >>/etc/fstab
    mount -a

    # move containerd data back
    mv "$BACKUP_DIR"/* "$MOUNT_POINT"/
    rm -rf "$BACKUP_DIR"

    # restart containerd and kubelet
    systemctl restart containerd
    systemctl restart kubelet

    log::info "successfully mounted new device /dev/$DEVICE"
else
    log::info "no new device found, skipping volume mount process"
fi

# restore stdout and stderr
exec 1>&3 2>&4
