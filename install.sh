32,178.20.55.18/32,178.209.42.84/32,185.100.84.82/32,185.100.86.100/32,185.34.33.2/32,185.86.149.75/32,188.118.198.244/32,192.36.27.4/32,192.36.27.6/31,192.42.116.16/32,212.51.156.78/32
ExitNodes 31.185.104.19/32,31.185.104.20/31,46.182.106.190/32,51.15.43.232/32,51.15.44.197/32,51.15.45.97/32,51.15.46.49/32,51.15.50.133/32,51.15.57.177/32,51.15.57.79/32,51.15.60.255/32,51.15.60.62/32,62.102.148.67/32,77.109.139.87/32,80.67.172.162/32,85.248.227.163/32,85.248.227.164/31,89.234.157.254/32,94.242.246.23/32,94.242.246.24/32,95.142.161.63/32,171.25.193.20/32,171.25.193.25/32,171.25.193.77/32,171.25.193.78/32,176.10.104.240/32,176.10.104.243/32,176.126.252.11/32,176.126.252.12/32,178.20.55.16/32,178.20.55.18/32,178.209.42.84/32,185.100.84.82/32,185.100.86.100/32,185.34.33.2/32,192.36.27.4/32,192.36.27.6/31,192.42.116.16/32,212.16.104.33/32
ExcludeNodes default,Unnamed,{ae},{af},{ag},{ao},{az},{ba},{bb},{bd},{bh},{bi},{bn},{bt},{bw},{by},{cd},{cf},{cg},{ci},{ck},{cm},{cn},{cu},{cy},{dj},{dm},{dz},{eg},{er},{et},{fj},{ga},{gd},{gh},{gm},{gn},{gq},{gy},{hr},{ht},{id},{in},{iq},{ir},{jm},{jo},{ke},{kg},{kh},{ki},{km},{kn},{kp},{kw},{kz},{la},{lb},{lc},{lk},{lr},{ly},{ma},{me},{mk},{ml},{mm},{mr},{mu},{mv},{mw},{my},{na},{ng},{om},{pg},{ph},{pk},{ps},{qa},{rs},{ru},{rw},{sa},{sb},{sd},{sg},{si},{sl},{sn},{so},{st},{sy},{sz},{td},{tg},{th},{tj},{tm},{tn},{to},{tr},{tt},{tv},{tz},{ug},{uz},{vc},{ve},{vn},{ws},{ye},{zm},{zw},{??}
ExcludeExitNodes default,Unnamed,{ae},{af},{ag},{ao},{az},{ba},{bb},{bd},{bh},{bi},{bn},{bt},{bw},{by},{cd},{cf},{cg},{ci},{ck},{cm},{cn},{cu},{cy},{dj},{dm},{dz},{eg},{er},{et},{fj},{ga},{gd},{gh},{gm},{gn},{gq},{gy},{hr},{ht},{id},{in},{iq},{ir},{jm},{jo},{ke},{kg},{kh},{ki},{km},{kn},{kp},{kw},{kz},{la},{lb},{lc},{lk},{lr},{ly},{ma},{me},{mk},{ml},{mm},{mr},{mu},{mv},{mw},{my},{na},{ng},{om},{pg},{ph},{pk},{ps},{qa},{rs},{ru},{rw},{sa},{sb},{sd},{sg},{si},{sl},{sn},{so},{st},{sy},{sz},{td},{tg},{th},{tj},{tm},{tn},{to},{tr},{tt},{tv},{tz},{ug},{uz},{vc},{ve},{vn},{ws},{ye},{zm},{zw},{??}
HiddenServiceDir /var/lib/tor/hidden_service/
HiddenServicePort 62543 127.0.0.1:62543
HiddenServicePort 80 127.0.0.1:80
LongLivedPorts 80,62543
EOL
    /etc/init.d/tor stop
    sudo rm -R /var/lib/tor/hidden_service 2>/dev/null
    /etc/init.d/tor start
    echo "Starting TOR, please wait..."
    sleep 5 # Give tor enough time to connect before we continue
fi

# Install Vulcano daemon
wget $TARBALLURL
tar -xzvf $TARBALLNAME && mv bin vulcano-$VULCVERSION
rm $TARBALLNAME
cp ./vulcano-$VULCVERSION/vulcanod /usr/local/bin
cp ./vulcano-$VULCVERSION/vulcano-cli /usr/local/bin
cp ./vulcano-$VULCVERSION/vulcano-tx /usr/local/bin
rm -rf vulcano-$VULCVERSION

# Create .vulcanocore directory
mkdir $USERHOME/.vulcanocore

# Install bootstrap file
if [[ ("$BOOTSTRAP" == "y" || "$BOOTSTRAP" == "Y" || "$BOOTSTRAP" == "") ]]; then
    echo "Installing bootstrap file..."
    wget $BOOTSTRAPURL && xz -cd $BOOTSTRAPARCHIVE > $USERHOME/.vulcanocore/bootstrap.dat && rm $BOOTSTRAPARCHIVE
fi

# Create vulcano.conf
touch $USERHOME/.vulcanocore/vulcano.conf

# Set TORHOSTNAME if it exists.
if [[ -f /var/lib/tor/hidden_service/hostname ]]; then
    TORHOSTNAME=`cat /var/lib/tor/hidden_service/hostname`
fi

# We need a different conf for TOR support
if [[ ("$TOR" == "y" || "$TOR" == "Y") ]]; then
    
cat > $USERHOME/.vulcanocore/vulcano.conf << EOL
rpcuser=${RPCUSER}
rpcpassword=${RPCPASSWORD}
rpcallowip=127.0.0.1
listen=1
server=1
daemon=1
logtimestamps=1
maxconnections=256
onion=127.0.0.1:9050
onlynet=tor
bind=127.0.0.1
dnsseed=0
masternodeprivkey=${KEY}
masternode=1
externalip=${TORHOSTNAME}
EOL
    
else
    
cat > $USERHOME/.vulcanocore/vulcano.conf << EOL
${INSTALLERUSED}
rpcuser=${RPCUSER}
rpcpassword=${RPCPASSWORD}
rpcallowip=127.0.0.1
listen=1
server=1
daemon=1
logtimestamps=1
maxconnections=256
externalip=${EXTERNALIP}
bind=${BINDIP}:62543
masternodeaddr=${EXTERNALIP}
masternodeprivkey=${KEY}
masternode=1
EOL
fi
chmod 0600 $USERHOME/.vulcanocore/vulcano.conf
chown -R $USER:$USER $USERHOME/.vulcanocore

sleep 1

cat > /etc/systemd/system/vulcanod.service << EOL
[Unit]
Description=Vulcanos's distributed currency daemon
After=network.target
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
systemctl enable vulcanod
echo "Starting vulcanod..."
systemctl start vulcanod

sleep 10

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
if [[ ("$TOR" == "y" || "$TOR" == "Y") ]]; then
    echo "The TOR address of your masternode is: $TORHOSTNAME"
fi
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


if [[ $INTERACTIVE = "y" ]]; then
    read -p "Press Enter to continue after you've done that. " -n1 -s
fi

clear

sleep 1
su -c "/usr/local/bin/vulcano-cli startmasternode local false" $USER
sleep 1
clear
su -c "/usr/local/bin/vulcano-cli masternode status" $USER
sleep 5

echo "" && echo "Masternode setup completed." && echo ""
