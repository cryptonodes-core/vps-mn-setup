#!/bin/bash

clear
echo "This script will refresh your CNMC masternode."
read -p "Press Ctrl-C to abort or any other key to continue. " -n1 -s
clear

if [ "$(id -u)" != "0" ]; then
  echo "This script must be run as root."
  exit 1
fi

USER=`ps u $(pgrep cryptonodesd) | grep cryptonodesd | cut -d " " -f 1`
USERHOME=`eval echo "~$USER"`

if [ -e /etc/systemd/system/cryptonodesd.service ]; then
  systemctl stop cryptonodesd
else
  su -c "cryptonodes-cli stop" $CNMCUSER
fi

echo "Refreshing CNMC node, please wait."

sleep 5

rm -rf $USERHOME/.cryptonodes/blocks
rm -rf $USERHOME/.cryptonodes/database
rm -rf $USERHOME/.cryptonodes/chainstate
rm -rf $USERHOME/.cryptonodes/sporks
rm -rf $USERHOME/.cryptonodes/mncache.dat
rm -rf $USERHOME/.cryptonodes/mnpayments.dat
rm -rf $USERHOME/.cryptonodes/peers.dat

cp $USERHOME/.cryptonodes/cryptonodes.conf $USERHOME/.cryptonodes/cryptonodes.conf.backup
sed -i '/^addnode/d' $USERHOME/.cryptonodes/cryptonodes.conf

if [ -e /etc/systemd/system/cryptonodesd.service ]; then
  sudo systemctl start cryptonodesd
else
  su -c "cryptonodesd -daemon" $USER
fi

echo "Your CNMC masternode is syncing. Please wait for this process to finish."
echo "This can take up to a few hours. Do not close this window." && echo ""

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

where <mymnalias> is the name of your CNMC masternode alias (without brackets)

EOL

read -p "Press Enter to continue after you've done that. " -n1 -s

clear

sleep 1
su -c "/usr/local/bin/cryptonodes-cli startmasternode local false" $USER
sleep 1
clear
su -c "/usr/local/bin/cryptonodes-cli masternode status" $USER
sleep 5

echo "" && echo "CNMC Masternode refresh completed." && echo ""
