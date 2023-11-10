#! /bin/bash
#creates a directory for samba share and shares it
RED='\033[0;31m'
NC='\033[0m' # No Color

i=0
while [ $i -lt 5 ]
do
echo ".............................."
i=$(($i+1))
done
echo -e "............"${RED}"Samba"$NC"............."
i=0
while [ $i -lt 5 ]
do
echo ".............................."
i=$(($i+1))
done




echo "Wait for install..."
apt-get install samba samba-common-bin cifs-utils -y &>/dev/null
echo "Samba and its dependecies installed."
read encmountpath <$HOME/.config/$RND/encmountpath
mkdir $encmountpath/samba
chmod 0740 $encmountpath/samba
read -p "What password would you like for the Samba share? " -s sambapassword
echo -ne "$sambapassword\n$sambapassword\n" | smbpasswd -a $USER -s
mv /etc/samba/smb.conf /etc/samba/smb.conf.old
touch /etc/samba/smb.conf
cat <<EOT >> /etc/samba/smb.conf
[share]
    path = $encmountpath/samba
    read only = no
    public = no
    writable = yes
EOT
systemctl start smbd &>/dev/null
systemctl disable smbd &>/dev/null

echo -e "${RED}Samba${NC} setup finished\n\n\n\n\n"