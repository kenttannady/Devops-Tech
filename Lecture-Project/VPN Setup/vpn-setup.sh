#!/bin/bash

# Install OpenVPN and EasyRSA
apt-get update
apt-get install -y openvpn easy-rsa

# Set up PKI
make-cadir /etc/openvpn/easy-rsa
cd /etc/openvpn/easy-rsa

# Configure vars
echo "set_var EASYRSA_REQ_COUNTRY \"US\"" > vars
echo "set_var EASYRSA_REQ_PROVINCE \"California\"" >> vars
echo "set_var EASYRSA_REQ_CITY \"San Francisco\"" >> vars
echo "set_var EASYRSA_REQ_ORG \"${local.app_name}\"" >> vars
echo "set_var EASYRSA_REQ_EMAIL \"admin@${local.app_name}.com\"" >> vars
echo "set_var EASYRSA_REQ_OU \"${local.app_name} VPN\"" >> vars
echo "set_var EASYRSA_ALGO \"ec\"" >> vars
echo "set_var EASYRSA_DIGEST \"sha512\"" >> vars

# Initialize PKI
./easyrsa init-pki
export EASYRSA_BATCH=1
./easyrsa build-ca nopass
./easyrsa gen-req server nopass
./easyrsa sign-req server server
./easyrsa gen-dh
openvpn --genkey --secret pki/ta.key

# Generate server config
cat > /etc/openvpn/server.conf <<EOF
port 1194
proto udp
dev tun
ca /etc/openvpn/easy-rsa/pki/ca.crt
cert /etc/openvpn/easy-rsa/pki/issued/server.crt
key /etc/openvpn/easy-rsa/pki/private/server.key
dh /etc/openvpn/easy-rsa/pki/dh.pem
auth SHA512
tls-crypt /etc/openvpn/easy-rsa/pki/ta.key
topology subnet
server 10.8.0.0 255.255.255.0
push "route 192.168.56.0 255.255.255.0"
ifconfig-pool-persist /var/log/openvpn/ipp.txt
push "dhcp-option DNS 8.8.8.8"
push "dhcp-option DNS 8.8.4.4"
keepalive 10 120
cipher AES-256-CBC
user nobody
group nogroup
persist-key
persist-tun
status /var/log/openvpn/openvpn-status.log
verb 3
explicit-exit-notify 1
EOF

# Enable IP forwarding
echo "net.ipv4.ip_forward=1" >> /etc/sysctl.conf
sysctl -p

# Configure firewall
iptables -t nat -A POSTROUTING -s 10.8.0.0/24 -o eth0 -j MASQUERADE
iptables -t nat -A POSTROUTING -s 10.8.0.0/24 -o eth1 -j MASQUERADE
iptables-save > /etc/iptables.rules

# Start OpenVPN
systemctl enable --now openvpn@server

# Generate client config
mkdir -p /etc/openvpn/client-configs
cat > /etc/openvpn/client-configs/client.ovpn <<EOF
client
dev tun
proto udp
remote ${local.app_name}-vpn 1194
resolv-retry infinite
nobind
persist-key
persist-tun
remote-cert-tls server
auth SHA512
cipher AES-256-CBC
ignore-unknown-option block-outside-dns
block-outside-dns
verb 3
<ca>
$(cat /etc/openvpn/easy-rsa/pki/ca.crt)
</ca>
<cert>
$(cat /etc/openvpn/easy-rsa/pki/issued/client.crt)
</cert>
<key>
$(cat /etc/openvpn/easy-rsa/pki/private/client.key)
</key>
<tls-crypt>
$(cat /etc/openvpn/easy-rsa/pki/ta.key)
</tls-crypt>
EOF