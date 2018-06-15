#!/bin/bash

TARBALLURL="https://github.com/cryptonodes-core/cryptonodes-core/releases/download/1.2.0.2/cryptonodes-x86_64-linux-gnu.tar.gz"
TARBALLNAME="cryptonodes-x86_64-linux-gnu.tar.gz"
CNMCVERSION="1.2.0.2"

CHARS="/-\|"

clear
echo "This script will update your CNMC masternode to version $CNMCVERSION"
read -p "Press Ctrl-C to abort or any other key to continue. " -n1 -s
clear

if [ "$(id -u)" != "0" ]; then
  echo "This script must be run as root."
  exit 1
fi

USER=`ps u $(pgrep cryptonodesd) | grep cryptonodesd | cut -d " " -f 1`
USERHOME=`eval echo "~$USER"`

echo "Shutting down masternode..."
if [ -e /etc/systemd/system/cryptonodesd.service ]; then
  systemctl stop cryptonodesd
else
  su -c "cryptonodes-cli stop" $USER
fi

echo "Installing Cryptonodes $CNMCVERSION..."
mkdir ./cryptonodes-temp && cd ./cryptonodes-temp
wget $TARBALLURL
tar -xzvf $TARBALLNAME && mv bin cryptonodes-$CNMCVERSION
yes | cp -rf ./cryptonodes-$CNMCVERSION/cryptonodesd /usr/local/bin
yes | cp -rf ./cryptonodes-$CNMCVERSION/cryptonodes-cli /usr/local/bin
cd ..
rm -rf ./cryptonodes-temp

if [ -e /usr/bin/cryptonodesd ];then rm -rf /usr/bin/cryptonodesd; fi
if [ -e /usr/bin/cryptonodes-cli ];then rm -rf /usr/bin/cryptonodes-cli; fi
if [ -e /usr/bin/cryptonodes-tx ];then rm -rf /usr/bin/cryptonodes-tx; fi

sed -i '/^addnode/d' $USERHOME/.cryptonodes/cryptonodes.conf

echo "Restarting Cryptonodes daemon..."
if [ -e /etc/systemd/system/cryptonodesd.service ]; then
  systemctl start cryptonodesd
else
  cat > /etc/systemd/system/cryptonodesd.service << EOL
[Unit]
Description=cryptonodesd
After=network.target
[Service]
Type=forking
User=${USER}
WorkingDirectory=${USERHOME}
ExecStart=/usr/local/bin/cryptonodesd -conf=${USERHOME}/.cryptonodes/cryptonodes.conf -datadir=${USERHOME}/.cryptonodes
ExecStop=/usr/local/bin/cryptonodes-cli -conf=${USERHOME}/.cryptonodes/cryptonodes.conf -datadir=${USERHOME}/.cryptonodes stop
Restart=on-abort
[Install]
WantedBy=multi-user.target
EOL
  sudo systemctl enable cryptonodesd
  sudo systemctl start cryptonodesd
fi
clear

echo "Your CNMC masternode is syncing. Please wait for this process to finish."

until su -c "cryptonodes-cli mnsync status 2>/dev/null | grep '\"IsBlockchainSynced\" : true' > /dev/null" $USER; do
  for (( i=0; i<${#CHARS}; i++ )); do
    sleep 2
    echo -en "${CHARS:$i:1}" "\r"
  done
done

clear

cat << EOL

Now, you need to start your CNMC masternode. Please go to your desktop CNMC wallet and
enter the following line into your debug console:

startmasternode alias false <mymnalias>

where <mymnalias> is the name of your masternode alias (without brackets)

EOL

read -p "Press Enter to continue after you've done that. " -n1 -s

clear

su -c "cryptonodes-cli masternode status" $USER

cat << EOL

CNMC Masternode update completed.

EOL
