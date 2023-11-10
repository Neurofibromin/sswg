#! /bin/bash
RED='\033[0;31m'
NC='\033[0m' # No Color


#getting the mountpath, creating urbackup subdirectory

i=0
while [ $i -lt 5 ]
do
echo ".............................."
i=$(($i+1))
done
echo -e "..........."${RED}"Urbackup"$NC"..........."
i=0
while [ $i -lt 5 ]
do
echo ".............................."
i=$(($i+1))
done

read encmountpath <$configdir/encmountpath
mkdir $encmountpath/urbackup
urbackuppath="$encmountpath/urbackup"

echo -e ${RED}$urbackuppath " is the path for urbackup.${NC}\nPlease Wait for install..."

#installing urbackup and dependencies
apt-get install sqlite3 -y >/dev/null
wget -q "https://hndl.urbackup.org/Server/2.5.28/urbackup-server_2.5.28_"${arch}".deb"
dpkg -i "urbackup-server_2.5.28_"$arch".deb" >/dev/null
sleep 3
echo -e "${RED}Urbackup${NC} download finished."
chown urbackup:urbackup "$urbackuppath"
rm "urbackup-server_2.5.28_"$arch".deb"
#systemctl stop urbackupsrv.service



###configs: /etc/default/urbackupsrv, /etc/urbackup/backupfolder, /var/urbackup/*
##changing configs and starting urbackup
rm /etc/urbackup/backupfolder
touch /etc/urbackup/backupfolder
echo "$urbackuppath" > /etc/urbackup/backupfolder
read -p "Choose new admin password for the web interface of Urbackup: " -s password
urbackupsrv reset-admin-pw -a admin -p $password >/dev/null

sqlite3 /var/urbackup/backup_server_settings.db 'UPDATE settings SET value = "'$urbackuppath'" WHERE key = "backupfolder";' >/dev/null


systemctl restart urbackupsrv.service >/dev/null
systemctl disable urbackupsrv.service >/dev/null
echo -e ${RED}"Urbackup"$NC" install and setup finished. Further setup available from web interface (port:55414)\n\n\n\n\n"