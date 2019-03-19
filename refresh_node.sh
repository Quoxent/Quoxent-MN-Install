#!/bin/bash

# Make sure curl is installed
apt-get -qq update
apt -qqy install curl jq
clear

BOOTSTRAPURL=$(curl -s https://api.github.com/repos/vulcanocrypto/vulcano/releases/latest | grep bootstrap.dat.xz | grep browser_download_url | cut -d '"' -f 4)
BOOTSTRAPARCHIVE="bootstrap.dat.xz"

clear
echo "This script will refresh your masternode."
read -rp "Press Ctrl-C to abort or any other key to continue. " -n1 -s
clear

if [ "$(id -u)" != "0" ]; then
  echo "This script must be run as root."
  exit 1
fi

USER=$(ps -o user= -p "$(pgrep vulcanod)")
USERHOME=$(eval echo "~$USER")

if [ -e /etc/systemd/system/vulcanod.service ]; then
  systemctl stop vulcanod
else
  su -c "vulcano-cli stop" "$USER"
fi

echo "Refreshing node, please wait."

sleep 5

rm -rf "$USERHOME/.vulcanocore/blocks"
rm -rf "$USERHOME/.vulcanocore/database"
rm -rf "$USERHOME/.vulcanocore/chainstate"
rm -rf "$USERHOME/.vulcanocore/peers.dat"

cp "$USERHOME/.vulcanocore/vulcano.conf" "$USERHOME/.vulcanocore/vulcano.conf.backup"
sed -i '/^addnode/d' "$USERHOME/.vulcanocore/vulcano.conf"

echo "Installing bootstrap file..."
wget "$BOOTSTRAPURL" && xz -cd $BOOTSTRAPARCHIVE > "$USERHOME/.vulcanocore/bootstrap.dat" && rm $BOOTSTRAPARCHIVE

# Install peers.dat - Can be removed after seeder issue is resolved
wget https://github.com/VulcanoCrypto/Vulcano/releases/download/v2.1.0.0/peers.dat.xz && xz -cd peers.dat.xz > $USERHOME/.vulcanocore/peers.dat && rm peers.dat.xz

if [ -e /etc/systemd/system/vulcanod.service ]; then
  sudo systemctl start vulcanod
else
  su -c "vulcanod -daemon" "$USER"
fi

echo "Starting vulcanod, will check status in 60 seconds..."
sleep 60

clear

if ! systemctl status vulcanod | grep -q "active (running)"; then
  echo "ERROR: Failed to start vulcanod. Please contact support."
  exit
fi

echo "Waiting for wallet to load..."
until su -c "vulcano-cli getinfo 2>/dev/null | grep -q \"version\"" "$USER"; do
  sleep 1;
done

clear

echo "Your masternode is syncing. Please wait for this process to finish."
echo "This can take up to a few hours. Do not close this window."
echo ""

until [ -n "$(vulcano-cli getconnectioncount 2>/dev/null)"  ]; do
  sleep 1
done

until su -c "vulcano-cli mnsync status 2>/dev/null | grep '\"IsBlockchainSynced" : true' > /dev/null" "$USER"; do 
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

sleep 1
su -c "/usr/local/bin/vulcano-cli startmasternode local false" "$USER"
sleep 1
clear
su -c "/usr/local/bin/vulcano-cli masternode status" "$USER"
sleep 5

echo "" && echo "Masternode refresh completed." && echo ""
