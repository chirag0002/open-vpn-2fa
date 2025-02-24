# Go Application Usage Guide

## 📌 Prerequisites
```bash
chmod +x setup/setup.sh
sudo ./setup/setup.sh

./setup/configure.sh
./build.sh
```

---

## 🚀 Running the Application Manually
You can run the application in the foreground:
```bash
./ovpn-admin
```
To run it in the background:
```bash
./ovpn-admin &
```
To check if it's running:
```bash
ps aux | grep ovpn-admin
```
To stop it:
```bash
pkill -f ovpn-admin
```

---

## 🔥 Running the Application as a Systemd Service

## ovpn-admin portal
### 1️⃣ Create a Systemd Service File
```bash
sudo vi /etc/systemd/system/ovpn-admin.service
```
Add the following:
```
[Unit]
Description=ovpn-admin web portal
After=network.target

[Service]
ExecStart=/home/ubuntu/open-vpn-2fa/ovpn-admin
Restart=always
User=ubuntu
WorkingDirectory=/home/ubuntu/open-vpn-2fa\
StandardOutput=append:/var/log/ovpn-admin.log
StandardError=append:/var/log/ovpn-admin-error.log

[Install]
WantedBy=multi-user.target
```

### 3️⃣ Reload Systemd and Enable the Service
```bash
sudo systemctl daemon-reload
sudo systemctl enable ovpn-admin
sudo systemctl start ovpn-admin
```

### 4️⃣ Manage the Service
Check the service status:
```bash
systemctl status ovpn-admin
```
Stop the service:
```bash
sudo systemctl stop ovpn-admin
```
Restart the service:
```bash
sudo systemctl restart ovpn-admin
```
Disable from startup:
```bash
sudo systemctl disable ovpn-admin
```
View logs:
```bash
journalctl -u ovpn-admin -f
```

## ovpn
### 1️⃣ Create a Systemd Service File
```bash
sudo vi /etc/systemd/system/ovpn.service
```
Add the following:
```
[Unit]
Description=open vpn service
After=network.target

[Service]
WorkingDirectory=/etc/ovpn
ExecStart=/usr/sbin/openvpn --config /etc/ovpn/openvpn.conf
Restart=on-failure
StandardOutput=append:/var/log/ovpn.log
StandardError=append:/var/log/ovpn-error.log

[Install]
WantedBy=multi-user.target
```

### 3️⃣ Reload Systemd and Enable the Service
```bash
sudo systemctl daemon-reload
sudo systemctl enable ovpn
sudo systemctl start ovpn
```

### 4️⃣ Manage the Service
Check the service status:
```bash
systemctl status ovpn
```
Stop the service:
```bash
sudo systemctl stop ovpn
```
Restart the service:
```bash
sudo systemctl restart ovpn
```
Disable from startup:
```bash
sudo systemctl disable ovpn
```
View logs:
```bash
journalctl -u ovpn -f
```
---

## ✅ Conclusion
Now, your Go application is properly managed as a system service using `systemctl`. It will automatically start on system boot and restart on failure.

Enjoy! 🚀