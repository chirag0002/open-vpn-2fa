#!/usr/bin/env bash
set -ex

EASY_RSA_LOC="/etc/ovpn/easyrsa"
SERVER_CERT="${EASY_RSA_LOC}/pki/issued/server.crt"

OVPN_SRV_NET=${OVPN_SERVER_NET:-10.10.0.0}
OVPN_SRV_MASK=${OVPN_SERVER_MASK:-255.255.255.0}

set -e

TARGETARCH=$(dpkg --print-architecture) 

sudo apt update -y

sudo apt install -y openvpn iptables

if [ ! -f "/usr/local/bin/easyrsa" ]; then
  sudo apt install easy-rsa
  sudo ln -sf /usr/share/easy-rsa/easyrsa /usr/local/bin/easyrsa
fi

if [ ! -f "/usr/local/bin/openvpn-user" ]; then
  cd /tmp
  wget "https://github.com/pashcovich/openvpn-user/releases/download/v1.0.4/openvpn-user-linux-${TARGETARCH}.tar.gz" -O - | sudo tar xz -C /usr/local/bin
fi

if [ -f "/usr/local/bin/openvpn-user-${TARGETARCH}" ]; then
  sudo ln -sf /usr/local/bin/openvpn-user-${TARGETARCH} /usr/local/bin/openvpn-user
fi

mkdir -p /etc/ovpn/easyrsa
mkdir -p /etc/ovpn/ccd

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

cp -f /home/ubuntu/ovpn/setup/openvpn.conf /etc/ovpn/openvpn.conf

[ -d $EASY_RSA_LOC/pki ] && chmod 755 $EASY_RSA_LOC/pki
[ -f $EASY_RSA_LOC/pki/crl.pem ] && chmod 644 $EASY_RSA_LOC/pki/crl.pem


if [ ! -f "/usr/local/lib/security/pam_google_authenticator.so" ]; then
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
  qrencode

  cd /tmp
  rm -rf google-authenticator-libpam
  git clone https://github.com/google/google-authenticator-libpam
  cd google-authenticator-libpam/
  ./bootstrap.sh
  ./configure
  make
  make install
  rm -rf google-authenticator-libpam
fi

if [ ! -f "/etc/pam.d/openvpn" ]; then
  bash -c 'cat > /etc/pam.d/openvpn <<EOF
  auth    requisite       /usr/local/lib/security/pam_google_authenticator.so secret=/etc/google-auth/\${USER}  user=root
  account    required     pam_permit.so'
fi

if [ ! -f "/etc/ovpn/google-auth.sh" ]; then
  sudo mkdir -p /etc/google-auth
  sudo chown -R root /etc/google-auth

  sudo bash -c 'cat > /etc/ovpn/google-auth.sh <<EOF
  #!/bin/bash
  
  CLIENT=\$1
  HOST=\$(hostname)
  R="\e[0;91m"
  G="\e[0;92m"
  W="\e[0;97m"
  B="\e[1m"
  C="\e[0m"
  
  google-authenticator -t -d -f -r 3 -R 30 -W -C -s "/etc/google-auth/\${CLIENT}" || { echo -e "\${R}\${B}error generating QR code\${C}"; exit 1; }
  secret=\$(head -n 1 "/etc/google-auth/\${CLIENT}")
  qrencode -t PNG -o "/etc/google-auth/\${CLIENT}.png" "otpauth://totp/\${CLIENT}@\${HOST}?secret=\${secret}&issuer=openvpn" || { echo -e "\${R}\${B}Error generating PNG\${C}"; exit 1; }'
  
  sudo chmod +x /etc/ovpn/google-auth.sh
fi

openvpn --config /etc/ovpn/openvpn.conf