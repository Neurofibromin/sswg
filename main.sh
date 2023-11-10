#! /bin/bash

checkos() {
    echo "start checking os"
    if [ -f /etc/os-release ]; then
        # freedesktop.org and systemd
        . /etc/os-release
        OS=$NAME
        VER=$VERSION_ID
    elif type lsb_release >/dev/null 2>&1; then
        # linuxbase.org
        OS=$(lsb_release -si)
        VER=$(lsb_release -sr)
    elif [ -f /etc/lsb-release ]; then
        # For some versions of Debian/Ubuntu without lsb_release command
        . /etc/lsb-release
        OS=$DISTRIB_ID
        VER=$DISTRIB_RELEASE
    elif [ -f /etc/debian_version ]; then
        # Older Debian/Ubuntu/etc.
        OS=Debian
        VER=$(cat /etc/debian_version)
    elif [ -f /etc/SuSe-release ]; then
        # Older SuSE/etc.
        ...
    elif [ -f /etc/redhat-release ]; then
        # Older Red Hat, CentOS, etc.
        ...
    else
        # Fall back to uname, e.g. "Linux <version>", also works for BSD, etc.
        OS=$(uname -s)
        VER=$(uname -r)
    fi

    case $(uname -m) in
    x86_64)
        ARCH=x64  # or AMD64 or Intel64 or whatever
        ;;
    i*86)
        ARCH=x86  # or IA32 or Intel32 or whatever
        ;;
    arm)
        ARCH=arm
        ;;
    aarch64)
        ARCH=arm64
        ;;
    armv8b)
        ARCH=arm64
        ;;
    armv8l)
        ARCH=arm64
        ;;
    arm64)
        ARCH=arm64
        ;;
    *)
        # leave ARCH as-is
        echo "ERROR: Unkown architercture"
        exit 1
        ;;
    esac

    echo "OS:$OS ARCH:$ARCH VER:$VER"


    if [ -x "$(command -v apk)" ]; then
        pkgmanager="apk"
    elif [ -x "$(command -v apt-get)" ]; then 
        pkgmanager="apt-get"
    elif [ -x "$(command -v dnf)" ]; then
        pkgmanager="dnf"
    elif [ -x "$(command -v zypper)" ]; then 
        pkgmanager="zypper"
    elif [ -x "$(command -v yum)" ]; then
        pkgmanager="yum"
    elif [ -x "$(command -v pacman)" ]; then
        pkgmanager="pacman"
    elif [ -x "$(command -v xbps-install)" ]; then 
        pkgmanager="xbps-install"
    else 
        pkgmanager=""
        echo "Package manager unknown."
    fi
    if [ -z $pkgmanager ]; then
        echo "Package manager: $pkgmanager"
    fi
    echo "finish checking os"
}

checkforEXISTINGINSTALL() {
    echo "start check for existing install"
    if [ -d "/etc/sswg" ]; then
        if [ -f "/etc/sswg/config.txt" ]; then
            whiptail --title "Found config" --msgbox "Found old config under /etc/sswg.\nIf you want to reinstall with new config, delete the old one.\nUsing the old config now." 10 78
            echo "Found old config under /etc/sswg"
            EXISTINGINSTALL=true
        else
            EXISTINGINSTALL=false
        fi
    else
        mkdir -p "/etc/sswg"
        if (whiptail --title "Previous install" --yesno "Is there already an installed configuration of sswg?" 10 78); then

            if (whiptail --title "Old config locator" --yesno "Do you have the config file location for the old config?" 8 78); then
                oldconfigpath=$(whiptail --inputbox "Where is the config file for the old config?" 8 78 /etc/sswg --title "Configuration file path" 3>&1 1>&2 2>&3)
                if [ ! -f "oldconfigpath" ]; then
                    whiptail --title "Error" --msgbox "Wrong path, file not present" 8 78
                    echo "ERROR: no old config under $oldconfigpath"
                    sleep 5
                    exit 1
                else
                    echo "Found old config under $oldconfigpath"
                fi

                cp $oldconfigpath /etc/sswg/config.txt
                whiptail --title "Config file copied" --msgbox "Your old config file was copied to /etc/sswg/config.txt" 8 78
            else
                whiptail --title "No config file" --msgbox "You do not have the old config, please add\nthe container manually in the encryption section." 8 78
            fi
            EXISTINGINSTALL=true

        else
            echo "No previous install present, new install is started."
            EXISTINGINSTALL=false
        fi
    fi
    echo "finish check for existing install"
}

chooseservices() {
    selectedservices=$(whiptail --title "Services to install" --checklist \
    "Which services would you like to install?" 20 78 10 \
    "Encryption" "Veracrypt or LUKS" OFF \
    "OpenVPN" "Selfhosted VPN server" OFF \
    "UrBackup" "For backing up your files" OFF \
    "Samba" "Samba-style fileserver" OFF \
    "SFTP" "wip" OFF \
    "NextCloud" "wip" OFF \
    "HotSpot" "wip" OFF \
    3>&2 2>&1 1>&3 )
    echo "Selected services: $selectedservices"
}

executeservices() {
    echo "start executeservices"
    if [[ $selectedservices == *"Encryption"* ]]; then
    cd $projectroot
    echo "starting encryption.sh"
    bash ./encryption.sh
    echo "finished encryption.sh"
    cd $projectroot
    fi
    if [[ $selectedservices == *"OpenVPN"* ]]; then
    cd $projectroot
    echo "starting openvpn.sh"
    bash ./openvpn.sh
    echo "finished openvpn.sh"
    cd $projectroot
    fi
    if [[ $selectedservices == *"UrBackup"* ]]; then
    cd $projectroot
    echo "starting urbackup.sh"
    bash ./urbackup.sh
    echo "finished urbackup.sh"
    cd $projectroot
    fi
    if [[ $selectedservices == *"Samba"* ]]; then
    cd $projectroot
    echo "starting samba.sh"
    bash ./samba.sh
    echo "finished samba.sh"
    cd $projectroot
    fi
    if [[ $selectedservices == *"SFTP"* ]]; then
    echo ""
    fi
    if [[ $selectedservices == *"NextCloud"* ]]; then
    echo ""
    fi
    if [[ $selectedservices == *"HotSpot"* ]]; then
    echo ""
    fi
    echo "finish executeservices"
}

packageinstall() {
    packagesNeeded=$1
    for word in $packagesNeeded
    do
        echo "Installing $word"
        if (which $word); then
            echo "$word was already installed" #already installed
        else
            if [ -x "$(command -v apk)" ];       then sudo apk add --no-cache $word &>/dev/null
            elif [ -x "$(command -v apt-get)" ]; then sudo apt-get install $word -y &>/dev/null
            elif [ -x "$(command -v dnf)" ];     then sudo dnf install $word &>/dev/null
            elif [ -x "$(command -v zypper)" ];  then sudo zypper install $word &>/dev/null
            elif [ -x "$(command -v yum)" ];     then sudo yum install $word &>/dev/null
            elif [ -x "$(command -v pacman)" ];     then sudo pacman -Syu $word &>/dev/null
            elif [ -x "$(command -v xbps-install)" ];     then sudo xbps-install -S $word &>/dev/null
            else echo "FAILED TO INSTALL PACKAGE: Package manager not found. You must manually install: $word">&2; fi
        fi
    done
}


if [ $UID -ne 0 ]; then
	echo "User not root! Please run as root."
	exit 1;
fi

packageinstall "whiptail"
checkos #checks for os and arch

checkforEXISTINGINSTALL #gives back $EXISTINGINSTALL

export -f packageinstall
export OS
export ARCH
export pkgmanager
projectroot=$PWD
export projectroot
export EXISTINGINSTALL

if [ $EXISTINGINSTALL == false ]; then
    chooseservices
    executeservices
fi