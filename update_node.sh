#!/bin/bash

# Make sure curl is installed
apt-get -qq update
apt -qqy install curl
clear

TARBALLURL=`curl -LS https://api.github.com/repos/VulcanoCrypto/Vulcano/releases/latest | grep href | grep linux64 | cut -d '"' -f 2 | cut -d "/" -f 2-7`
TARBALLNAME=`curl -LS https://api.github.com/repos/VulcanoCrypto/Vulcano/releases/latest | grep href | grep linux64 | cut -d '"' -f 2 | cut -d "/" -f 7`
VULCVERSION=`curl -LS https://api.github.com/repos/VulcanoCrypto/Vulcano/releases/latest | grep href | grep linux64 | cut -d '"' -f 2 | cut -d "-" -f 2`

clear
echo "This script will update your masternode to version $VULCVERSION"
read -p "Press Ctrl-C to abort or any other key to continue. " -n1 -s
clear

if [ "$(id -u)" != "0" ]; then
  echo "This script must be run as root."
  exit 1
fi

USER=`ps u $(pgrep vulcanod) | grep vulcanod | cut -d " " -f 1`
USERHOME=`eval echo "~$USER"`

echo "Shutting down masternode..."
if [ -e /etc/systemd/system/vulcanod.service ]; then
  systemctl stop vulcanod
else
  su -c "vulcano-cli stop" $USER
fi

echo "Installing Vulcano $VULCVERSION..."
mkdir ./vulcano-temp && cd ./vulcano-temp
wget $TARBALLURL
tar -xzvf $TARBALLNAME && mv bin vulcano-$VULCVERSION
yes | cp -rf ./vulcano-$VULCVERSION/vulcanod /usr/local/bin
yes | cp -rf ./vulcano-$VULCVERSION/vulcano-cli /usr/local/bin
cd ..
rm -rf ./vulcano-temp

if [ -e /usr/bin/vulcanod ];then rm -rf /usr/bin/vulcanod; fi
if [ -e /usr/bin/vulcano-cli ];then rm -rf /usr/bin/vulcano-cli; fi
if [ -e /usr/bin/vulcano-tx ];then rm -rf /usr/bin/vulcano-tx; fi

# Remove addnodes from vulcano.conf
# sed -i '/^addnode/d' $USERHOME/.vulcano/vulcano.conf

# Add Fail2Ban memory hack if needed
if ! grep -q "ulimit -s 256" /etc/default/fail2ban; then
  echo "ulimit -s 256" | sudo tee -a /etc/default/fail2ban
  systemctl restart fail2ban
fi

echo "Restarting Vulcano daemon..."
if [ -e /etc/systemd/system/vulcanod.service ]; then
  systemctl disable vulcanod
  rm /etc/systemd/system/vulcanod.service
fi

cat > /etc/systemd/system/vulcanod.service << EOL
[Unit]
Description=Vulcano's distributed currency daemon
After=network.target
[Service]
Type=forking
User=${USER}
WorkingDirectory=${USERHOME}
ExecStart=/usr/local/bin/vulcanod -conf=${USERHOME}/.vulcano/vulcano.conf -datadir=${USERHOME}/.vulcano
ExecStop=/usr/local/bin/vulcano-cli -conf=${USERHOME}/.vulcano/vulcano.conf -datadir=${USERHOME}/.vulcano stop
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

sleep 10

clear

if ! systemctl status vulcanod | grep -q "active (running)"; then
  echo "ERROR: Failed to start vulcanod. Please contact support."
  exit
fi

echo "Waiting for wallet to load..."
until su -c "vulcano-cli getinfo 2>/dev/null | grep -q \"version\"" $USER; do
  sleep 1;
done

clear

echo "Your masternode is syncing. Please wait for this process to finish."
echo "This can take up to a few hours. Do not close this window."
echo ""

until su -c "vulcano-cli mnsync status 2>/dev/null | grep '\"IsBlockchainSynced\" : true' > /dev/null" $USER; do
  echo -ne "Current block: "`su -c "vulcano-cli getinfo" $USER | grep blocks | awk '{print $3}' | cut -d ',' -f 1`'\r'
  sleep 1
done

clear

cat << EOL

Now, you need to start your masternode. If you haven't already, please add this
node to your masternode.conf now, restart and unlock your desktop wallet, go to
the Masternodes tab, select your new node and click "Start Alias."

EOL

read -p "Press Enter to continue after you've done that. " -n1 -s

clear

su -c "vulcano-cli masternode status" $USER

cat << EOL

Masternode update completed.

EOL
