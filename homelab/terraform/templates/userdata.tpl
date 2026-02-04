#!/bin/bash

dnf update -y

cat <<EOF > /etc/sysctl.d/99-nat.conf
net.ipv4.ip_forward = 1
net.ipv4.conf.all.send_redirects = 0
EOF

sysctl -p /etc/sysctl.d/99-nat.conf

dnf install -y iptables-services

# Configure NAT iptables rules
iptables -t nat -A POSTROUTING -s ${private_subnet_cidr} -o eth0 -j MASQUERADE

# Set FORWARD policy to ACCEPT (Docker may change this to DROP)
iptables -P FORWARD ACCEPT

# Add FORWARD rules for NAT functionality
iptables -A FORWARD -i eth0 -m state --state RELATED,ESTABLISHED -j ACCEPT
iptables -A FORWARD -s ${private_subnet_cidr} -o eth0 -j ACCEPT

# If Docker is present, add rules to DOCKER-USER chain (evaluated before Docker's rules)
if iptables -L DOCKER-USER -n &>/dev/null; then
    iptables -I DOCKER-USER -i eth0 -m state --state RELATED,ESTABLISHED -j ACCEPT
    iptables -I DOCKER-USER -s ${private_subnet_cidr} -o eth0 -j ACCEPT
fi

service iptables save

systemctl enable iptables
systemctl start iptables

dnf install -y amazon-cloudwatch-agent

systemctl enable amazon-ssm-agent
systemctl start amazon-ssm-agent

echo "NAT instance configured successfully at $(date)" >> /var/log/nat-setup.log
echo "Private subnet CIDR: ${private_subnet_cidr}" >> /var/log/nat-setup.log