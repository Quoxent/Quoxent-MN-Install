#!/bin/bash

# Make sure curl is installed
apt-get -qq update
apt -qqy install curl jq
clear

TARBALLURL=$(curl -s https://api.github.com/repos/vulcanocrypto/vulcano/releases/latest | grep browser_download_url | grep -e "vulcano-node.*linux64" | cut -d '"' -f 4)
TARBALLNAME=$(curl -s https://api.github.com/repos/vulcanocrypto/vulcano/releases/latest | grep browser_download_url | grep -e "vulcano-node.*linux64" | cut -d '"' -f 4 | cut -d "/" -f 9)
VULCVERSION=$(curl -s https://api.github.com/repos/vulcanocrypto/vulcano/releases/latest | grep browser_download_url | grep -e "vulcano-node.*linux64" | cut -d '"' -f 4 | cut -d "/" -f 8)

LOCALVERSION=$(vulcano-cli --version | cut -d " " -f 6)
REMOTEVERSION=$(curl -s https://api.github.com/repos/vulcanocrypto/vulcano/releases/latest | jq -r ".tag_name")

if [[ "$LOCALVERSION" = "$REMOTEVERSION" ]]; then
  echo "No update necessary."
  exit
fi

clear
echo "This script will update your masternode to version $VULCVERSION"
read -rp "Press Ctrl-C to abort or any other key to continue. " -n1 -s
clear

if [ "$(id -u)" != "0" ]; then
  echo "This script must be run as root."
  exit 1
fi

USER=$(ps -o user= -p "$(pgrep vulcanod)")
USERHOME=$(eval echo "~$USER")

echo "Downloading new version..."
wget "$TARBALLURL"

echo "Shutting down masternode..."
if [ -e /etc/systemd/system/vulcanod.service ]; then
  systemctl stop vulcanod
else
  su -c "vulcano-cli stop" "$USER"
fi

echo "Installing vulcano $VULCVERSION..."
rm /usr/local/bin/vulcanod /usr/local/bin/vulcano-cli
tar -xzvf "$TARBALLNAME" -C /usr/local/bin
rm "$TARBALLNAME"

if [ -e /usr/bin/vulcanod ];then rm -rf /usr/bin/vulcanod; fi
if [ -e /usr/bin/vulcano-cli ];then rm -rf /usr/bin/vulcano-cli; fi
if [ -e /usr/bin/vulcano-tx ];then rm -rf /usr/bin/vulcano-tx; fi

# Remove addnodes from vulcano.conf
sed -i '/^addnode/d' "$USERHOME/.vulcanocore/vulcano.conf"

# Add Fail2Ban memory hack if needed
if ! grep -q "ulimit -s 256" /etc/default/fail2ban; then
  echo "ulimit -s 256" | sudo tee -a /etc/default/fail2ban
  systemctl restart fail2ban
fi

echo "Restarting vulcano daemon..."
if [ -e /etc/systemd/system/vulcanod.service ]; then
  systemctl disable vulcanod
  rm /etc/systemd/system/vulcanod.service
fi

cat > /etc/systemd/system/vulcanod.service << EOL
[Unit]
Description=vulcanos's distributed currency daemon
After=network-online.target
[Service]
Type=forking
User=${USER}
WorkingDirectory=${USERHOME}
ExecStart=/usr/local/bin/vulcanod -conf=${USERHOME}/.vulcanocore/vulcano.conf -datadir=${USERHOME}/.vulcanocore
ExecStop=/usr/local/bin/vulcano-cli -conf=${USERHOME}/.vulcanocore/vulcano.conf -datadir=${USERHOME}/.vulcanocore stop
Restart=on-failure
RestartSec=1m
StartLimitIntervalSec=5m
StartLimitInterval=5m
StartLimitBurst=3
[Install]
WantedBy=multi-user.target
EOL
sudo systemctl enable vulcanod
sudo systemctl start vulcanod

echo "Starting vulcanod, will check status in 60 seconds..."
sleep 60

clear

if ! systemctl status vulcanod | grep -q "active (running)"; then
  echo "ERROR: Failed to start vulcanod. Please contact support."
  exit
fi

echo "Installing vulcano Autoupdater..."
rm -f /usr/local/bin/vulcanoupdate
curl -o /usr/local/bin/vulcanoupdate https://raw.githubusercontent.com/vulcanocrypto/vulcano-MN-Install/master/vulcanoupdate
chmod a+x /usr/local/bin/vulcanoupdate

if [ ! -f /etc/systemd/system/vulcanoupdate.service ]; then
cat > /etc/systemd/system/vulcanoupdate.service << EOL
[Unit]
Description=vulcanos's Masternode Autoupdater
After=network-online.target
[Service]
Type=oneshot
User=root
WorkingDirectory=${USERHOME}
ExecStart=/usr/local/bin/vulcanoupdate
EOL
fi

if [ ! -f /etc/systemd/system/vulcanoupdate.timer ]; then
cat > /etc/systemd/system/vulcanoupdate.timer << EOL
[Unit]
Description=vulcanos's Masternode Autoupdater Timer

[Timer]
OnBootSec=1d
OnUnitActiveSec=1d 

[Install]
WantedBy=timers.target
EOL
fi

systemctl enable vulcanoupdate.timer
systemctl start vulcanoupdate.timer

echo "Waiting for wallet to load..."
until su -c "vulcano-cli getinfo 2>/dev/null | grep -q \"version\"" "$USER"; do
  sleep 1;
done

clear

echo "Your masternode is syncing. Please wait for this process to finish."
echo "This can take up to a few hours. Do not close this window."
echo ""

until su -c "vulcano-cli mnsync status 2>/dev/null | grep '\"IsBlockchainSynced\": true' > /dev/null" "$USER"; do 
  echo -ne "Current block: $(su -c "vulcano-cli getblockcount" "$USER")\\r"
  sleep 1
done

clear

cat << EOL

Now, you need to start your masternode. If you haven't already, please add this
node to your masternode.conf now, restart and unlock your desktop wallet, go to
the Masternodes tab, select your new node and click "Start Alias."

EOL

read -rp "Press Enter to continue after you've done that. " -n1 -s

clear

su -c "vulcano-cli masternode status" "$USER"

cat << EOL

Masternode update completed.

EOL
