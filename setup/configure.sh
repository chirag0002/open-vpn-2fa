#!/usr/bin/env bash
set -ex

EASY_RSA_LOC="/etc/openvpn/easyrsa"
SERVER_CERT="${EASY_RSA_LOC}/pki/issued/server.crt"

OVPN_SRV_NET=${OVPN_SERVER_NET:-192.168.100.0}
OVPN_SRV_MASK=${OVPN_SERVER_MASK:-255.255.255.0}
OVPN_PASSWD_AUTH=false

cd $EASY_RSA_LOC

if [ -e "$SERVER_CERT" ]; then
  echo "Found existing certs - reusing"
else
  if [ ${OVPN_ROLE:-"master"} = "slave" ]; then
    echo "Waiting for initial sync data from master"
    while [ $(wget -q localhost/api/sync/last/try -O - | wc -m) -lt 1 ]
    do
      sleep 5
    done
  else
    echo "Generating new certs"
    easyrsa init-pki
    cp -R /usr/share/easy-rsa/* $EASY_RSA_LOC/pki
    echo "ca" | easyrsa build-ca nopass
    easyrsa build-server-full server nopass
    easyrsa gen-dh
    openvpn --genkey --secret ./pki/ta.key
  fi
fi
easyrsa gen-crl

iptables -t nat -D POSTROUTING -s ${OVPN_SRV_NET}/${OVPN_SRV_MASK} ! -d ${OVPN_SRV_NET}/${OVPN_SRV_MASK} -j MASQUERADE || true
iptables -t nat -A POSTROUTING -s ${OVPN_SRV_NET}/${OVPN_SRV_MASK} ! -d ${OVPN_SRV_NET}/${OVPN_SRV_MASK} -j MASQUERADE

mkdir -p /dev/net
if [ ! -c /dev/net/tun ]; then
    mknod /dev/net/tun c 10 200
fi

cp -f /etc/openvpn/setup/openvpn.conf /etc/openvpn/openvpn.conf

if [ ${OVPN_PASSWD_AUTH} = "true" ]; then
  mkdir -p /etc/openvpn/scripts/
  cp -f /etc/openvpn/setup/auth.sh /etc/openvpn/scripts/auth.sh
  chmod +x /etc/openvpn/scripts/auth.sh
  echo "auth-user-pass-verify /etc/openvpn/scripts/auth.sh via-file" | tee -a /etc/openvpn/openvpn.conf
  echo "script-security 2" | tee -a /etc/openvpn/openvpn.conf
  echo "verify-client-cert require" | tee -a /etc/openvpn/openvpn.conf
  openvpn-user db-init --db.path=$EASY_RSA_LOC/pki/users.db
fi

[ -d $EASY_RSA_LOC/pki ] && chmod 755 $EASY_RSA_LOC/pki
[ -f $EASY_RSA_LOC/pki/crl.pem ] && chmod 644 $EASY_RSA_LOC/pki/crl.pem

sudo mkdir -p /etc/openvpn/ccd

sudo chown -R root /etc/google-auth

apt update && apt install -y \
  build-essential \
  linux-headers-$(uname -r) \
  autoconf \
  automake \
  libtool \
  cmake \
  make \
  git \
  libpam0g-dev \
  libpam-google-authenticator \
  libqrencode-dev
cd /tmp
rm -rf google-authenticator-libpam
git clone https://github.com/google/google-authenticator-libpam
cd google-authenticator-libpam/
./bootstrap.sh
./configure
make
make install

bash -c 'cat > /etc/pam.d/openvpn <<EOF
auth    requisite       /usr/local/lib/security/pam_google_authenticator.so secret=/etc/google-auth/${USER}  user=root
account    required     pam_permit.so
EOF'

bash -c 'cat > /etc/openvpn/google-auth.sh <<EOF
#!/bin/bash

CLIENT=$1
HOST=$(hostname)
R="\e[0;91m"
G="\e[0;92m"
W="\e[0;97m"
B="\e[1m"
C="\e[0m"

google-authenticator -t -d -f -r 3 -R 30 -W -C -s "/etc/google-auth/${CLIENT}" || { echo -e "${R}${B}error generating QR code${C}"; exit 1; }
secret=$(head -n 1 "/etc/google-auth/${CLIENT}")
qrencode -t PNG -o "/etc/google-auth/${CLIENT}.png" "otpauth://totp/${CLIENT}@${HOST}?secret=${secret}&issuer=openvpn" || { echo -e "${R}${B}Error generating PNG${C}"; exit 1; }
EOF'

sudo chmod +x /etc/openvpn/google-auth.sh
sudo chmod +x ./bootstrap.sh
sudo chmod +x ./build.sh


openvpn --config /etc/openvpn/openvpn.conf --client-config-dir /etc/openvpn/ccd --port 1194 --proto tcp --management 127.0.0.1 8989 --dev tun --server ${OVPN_SRV_NET} ${OVPN_SRV_MASK}