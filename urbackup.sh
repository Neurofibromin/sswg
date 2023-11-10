#! /bin/bash

urbackup_getfolder() {
    echo "start urbackup_getfolder"
    if (whiptail --title "Urbackup" --yesno \
    "Do you want to change the working folder for Urbackup?" 10 78); then
        if [ $encmountpath != ""  ]; then #check if encryption is used
            #there is encryption, but should it be used for urbackup?
            urbackuppath=$(whiptail --title "Urbackup" --inputbox \
            "Which folder would you like to use for Urbackup?" 8 78 $encmountpath/urbackup 3>&1 1>&2 2>&3)
        else
            urbackuppath=$(whiptail --title "Urbackup" --inputbox \
            "Which folder would you like to use for Urbackup?" 8 78 /etc/sswg/urbackup 3>&1 1>&2 2>&3)        
        fi
    else
        if [ $encmountpath != ""  ]; then #check if encryption is used
            urbackuppath="$encmountpath/urbackup"        
        else
            urbackuppath="/etc/sswg/urbackup"
        fi    
    fi
    echo "urbackuppath: $urbackuppath"
    mkdir $urbackuppath
    echo "finish urbackup_getfolder"
}

install_urbackup() {
    echo "start install_urbackup"
    if (which urbackupclientctl); then
        #urbackup already installed
        echo "urbackup already installed"
    else
        whiptail --title "Urbackup install" --msgbox "Urbackup server download \
        and install in progress.\nUrbackuppath:$urbackuppath" 8 78
        if [ ${pkgmanager} == "apt-get" ] ; then
            if [ $OS == "Ubuntu" ] ; then
                add-apt-repository ppa:uroni/urbackup
                apt-get update &>/dev/null
                packageinstall "urbackup-server"
                sleep 3
            else
                wget -q "https://hndl.urbackup.org/Server/2.5.31/urbackup-server_2.5.31_"${ARCH}".deb"
                dpkg -i "urbackup-*.deb" >/dev/null
                sleep 3
                rm "urbackup-*.deb"
            fi
        else
            echo "Urbackupinstall OS not yet supported"
            whiptail --title "Urbackup install" --msgbox "OS not yet supported" 8 78
        fi
        whiptail --title "Urbackup install" --msgbox "Urbackup download and \
        install successfull for OS: $OS." 8 78
    fi
    echo "finish install_urbackup"
}


. /etc/sswg/config.txt
#encmountpath=$encmountpath
urbackup_getfolder
packageinstall "sqlite3"
install_urbackup
chown urbackup:urbackup "$urbackuppath"

###configs: /etc/default/urbackupsrv, /etc/urbackup/backupfolder, /var/urbackup/*
##changing configs and starting urbackup
rm /etc/urbackup/backupfolder
touch /etc/urbackup/backupfolder
echo "$urbackuppath" > /etc/urbackup/backupfolder
urbackuppassword=$(whiptail --passwordbox "Password for Urbackup \"admin\" user:" \
8 78 --title "Urbackup" 3>&1 1>&2 2>&3)
urbackupsrv reset-admin-pw -a admin -p $urbackuppassword >/dev/null

sqlite3 /var/urbackup/backup_server_settings.db 'UPDATE settings SET value = "'$urbackuppath'" WHERE key = "backupfolder";' >/dev/null

systemctl restart urbackupsrv.service >/dev/null
systemctl disable urbackupsrv.service >/dev/null
whiptail --title "Urbackup" --msgbox "Urbackup install and setup finished.\nFurther \
setup available from web interface (port:55414)" 8 78