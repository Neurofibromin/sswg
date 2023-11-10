#! /bin/bash

. /etc/sswg/config.txt
#encmountpath=$encmountpath


whiptail --title "Samba install" --msgbox "Installing Samba and \
dependencies" 7 78
packageinstall "samba samba-common-bin cifs-utils"
sambapassword=$(whiptail --title "Samba" --passwordbox \
"What password would you like for the Samba share?" 8 78 3>&1 1>&2 2>&3)
echo "sambapassword from user"
echo -ne "$sambapassword\n$sambapassword\n" | smbpasswd -a $USER -s
mv /etc/samba/smb.conf /etc/samba/smb.conf.old
touch /etc/samba/smb.conf

if [ $encmountpath == ""  ]; then #check if encryption is used
    $encmountpath="/etc/sswg"
fi  

sambasharedfolder=$(whiptail --title "Samba" --inputbox \
"Which folder would you like to share?" 8 78 $encmountpath/samba 3>&1 1>&2 2>&3)
echo "sambasharedfolder: $sambasharedfolder"

mkdir $sambasharedfolder
chmod 0740 $sambasharedfolder
cat <<EOT >> /etc/samba/smb.conf
[share]
    path = $sambasharedfolder
    read only = no
    public = no
    writable = yes
EOT
systemctl start smbd &>/dev/null
systemctl disable smbd &>/dev/null
whiptail --title "Samba" --msgbox "Samba setup finished. Shared \
folder is $sambasharedfolder" 8 78