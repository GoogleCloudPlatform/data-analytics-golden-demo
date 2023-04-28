#! /bin/bash

# https://cloud.google.com/datastream/docs/private-connectivity#set-up-reverse-proxy
# Your connection will most likely fail. VM is missing firewall rule allowing TCP ingress traffic from 35.235.240.0/20 on port 22.

export DB_ADDR=REPLACE_DB_ADDR
export DB_PORT=5432
export ETH_NAME=$(ip -o link show | awk -F': ' '{print $2}' | grep -v lo)
export LOCAL_IP_ADDR=$(ip -4 addr show $ETH_NAME | grep -Po 'inet \K[\d.]+')
sudo echo 1 > /proc/sys/net/ipv4/ip_forward
sudo iptables -t nat -A PREROUTING -p tcp -m tcp --dport $DB_PORT -j DNAT --to-destination $DB_ADDR:$DB_PORT
sudo iptables -t nat -A POSTROUTING -j SNAT --to-source $LOCAL_IP_ADDR

# list tables
# sudo iptables -L -n -t nat