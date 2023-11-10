#! /bin/bash

encryptionprogram=$(whiptail --title "Encryption" --radiolist \
"Choose encryption backend" 20 78 2 \
"Veracrypt" "Well known encryption suite for crossplatform applications" ON \
"LUKS" "cryptsetup/LUKS based on Linux standards" OFF \
3>&2 2>&1 1>&3 )
echo "encryption backend chosen: "$encryptionprogram

install_encryption_program() {
    echo "start install encryption program"
    if [ $pkgmanager == "apt-get" ]; then
        packageinstall "btrfs-progs"
    elif $OS == ; then
        echo "other os, install btrfs-progs?"
    fi

    if [[ $encryptionprogram == *"Veracrypt"* ]]; then
        if (which "veracrypt"); then #veracrypt already installed
            echo "veracrypt already installed"
        else
            whiptail --title "Veracrypt install" --msgbox "Veracrypt download and install in progress" 8 78
            cd /tmp
            echo "installing veracrypt"
            wget -q https://launchpad.net/veracrypt/trunk/1.25.9/+download/veracrypt-1.25.9-setup.tar.bz2
            tar -xvf veracrypt-1.25.9-setup.tar.bz2
            ./veracrypt-1.25.9-setup-console-x64
            rm veracrypt*
            whiptail --title "Veracrypt install" --msgbox "Veracrypt download and install successfull." 8 78
        fi
        
    fi
    if [[ $encryptionprogram == *"LUKS"* ]]; then
        echo "encryption program chosen LUKS"
        whiptail --title "Cryptsetup install" --msgbox "Cryptsetup install in progress" 8 78
        echo "installing Cryptsetup"
        packageinstall "cryptsetup"
        packageinstall "util-linux"
    fi
    echo "finish install encryption program"
}

doyoualreadyhaveencryptedvolume() {
    if (whiptail --title "Encrypted volume" --yesno "Do you already have and encrypted volume? (must be btrfs)" 8 78); then
        alreadyhaveencryptedvolume=true
    else
        alreadyhaveencryptedvolume=false
    fi
    echo "alreadyhaveencryptedvolume: $alreadyhaveencryptedvolume"
}

diskformatting() {
    echo "start diskformatting"
    if (whiptail --title "Encrypted volume" --yesno "Do you want formatting?" 8 78); then
        echo "want disformatting true"
        chosenfilesystem=$(whiptail --title "Filesystem" --radiolist \
        "Filesystem for the new partition:" 20 78 10 \
        "btrfs" "BTRFS" OFF \
        "ext4" "EXT4" OFF \
        "something else" "" OFF \
        3>&2 2>&1 1>&3 )
        if [ "${chosenfilesystem}" == "something else" ] ; then
            chosenfilesystem=$(whiptail --inputbox "What filesystem would you like to use?" 8 78 ext4 --title "Filesystem" 3>&1 1>&2 2>&3)
        fi
        echo "chosenfilesystem: $chosenfilesystem"

        #choose disk partition for formatting              
        diskstring=$(lsblk -r -n -o NAME,SIZE)
        declare n=""
        for word in $diskstring
        do
            n+="$word "
            if [ $(( i % 2 )) -eq 0 ]; then
               n+="OFF "
            fi
            ((i++))
        done
        partitiontoformat=$(whiptail --title "Filesystem" --radiolist \
        "Which partition would you like formatted?" 20 78 5 \
        $n \
        3>&2 2>&1 1>&3 )
        partitiontoformat="/dev/$partitiontoformat"
        echo "partitiontoformat: $partitiontoformat"
        umount $partitiontoformat 2>/dev/null
        wipefs -a $partitiontoformat
        mkfs -t $chosenfilesystem $partitiontoformat >/dev/null
        whiptail --title "Filesystem" --msgbox "${partitiontoformat} has been formatted as $chosenfilesystem" 8 78
        echo "${partitiontoformat} has been formatted as $chosenfilesystem"
    else
        echo "no formatting"
    fi
    echo "finish diskformatting"
}

persistentmount() {
    echo "start persistentmount"
    if [ -z "$chosenfilesystem" ]; then
      chosenfilesystem=$(whiptail --inputbox "What filesystem do you have on \
      your partition?" 8 78 ext4 --title "Filesystem" 3>&1 1>&2 2>&3)
      echo "chosenfilesystem: $chosenfilesystem"
    fi

    partitiontomount=$partitiontoformat
    if [ -z "$partitiontomount" ]; then
        diskstring=$(lsblk -r -n -o NAME,SIZE)
        declare n="start "
        for word in $diskstring
        do
            n+="$word "
            if [ $(( i % 2 )) -eq 0 ]; then
                n+="OFF "
            fi
            ((i++))
        done
        partitiontomount=$(whiptail --title "Filesystem" --radiolist \
        "Which partition would you like use?" 20 78 5 \
        $n \
        3>&2 2>&1 1>&3 )
        echo "partitiontomount: $partitiontomount"
    fi
    
    diskuid=$(lsblk -o NAME,uuid | grep $partitiontomount | awk '{print $2}')
    echo "diskuid: $diskuid"
    umount /dev/disk/by-uuid/$diskuid 2>/dev/null
    
    mountpath=$(whiptail --inputbox "Where do you want to persistently mount \
    the databases?\neg. /media/project" 8 78 /media/project --title "Mountpaths" 3>&1 1>&2 2>&3)
    
    encvolumelocation=$(whiptail --inputbox "Where do you want to keep \
    the container for the encrypted volume?\neg. /media/project/data" 8 78 $mountpath/data --title "Encrypted volume location" 3>&1 1>&2 2>&3)
    
    encmountpath=$(whiptail --inputbox "Where do you want to mount \
    the encrypted volume?\neg. /media/project/mountedcontainer" 8 78 $mountpath/mountedcontainer --title "Encrypted mountpath" 3>&1 1>&2 2>&3)
    echo "encmountpath: $encmountpath"
    echo "encvolumelocation: $encvolumelocation"
    echo "mountpath: $mountpath"
    echo "mountpath=\"$mountpath\"" >> /etc/sswg/config.txt
    echo "encmountpath=\"$encmountpath\"" >> /etc/sswg/config.txt
    echo "encvolumelocation=\"$encvolumelocation\"" >> /etc/sswg/config.txt
    mkdir $mountpath
    echo "fstab: UUID="$diskuid $mountpath "$chosenfilesystem defaults 0 0"
    echo "UUID="$diskuid $mountpath "$chosenfilesystem defaults 0 0" >>/etc/fstab
    mount -a
    cd $mountpath
    touch $encvolumelocation
    mkdir $encmountpath
    echo "finish persistentmount"
}

createvolume() {
    echo "start createvolume"
    volumesize=$(whiptail --title "Volume creation" --inputbox "Now creating new encrypted container.\
    \n Volume size? eg. 200M or 10G" 8 78 3>&1 1>&2 2>&3)
    volumepassword=$(whiptail --title "Volume creation" \
    --passwordbox "Password for the encrypted volume:" 8 78 3>&1 1>&2 2>&3)
    openssl rand -base64 -out /tmp/randomdata.txt 10240
    echo "volumesize: $volumesize"
    if [[ $encryptionprogram == *"Veracrypt"* ]]; then
        veracrypt --create $encvolumelocation --size $volumesize --password $password --encryption=AES --hash=SHA-512 --volume-type=normal --filesystem=Btrfs --pim 0 --keyfiles "" --random-source /tmp/randomdata.txt
    fi
    if [[ $encryptionprogram == *"LUKS"* ]]; then
        fallocate -l $volumesize $encvolumelocation
        # can use dd if=/dev/urandom of=$encvolumelocation bs=1M count=$volumesize/MB instead
        cryptsetup luksFormat $encvolumelocation
        echo $volumepassword | cryptsetup open --type luks $encvolumelocation sswg -q -
        mkfs -t btrfs /dev/mapper/sswg >/dev/null
        umount /dev/mapper/sswg
        cryptsetup close sswg
    fi
    rm /tmp/randomdata.txt
    whiptail --title "Volume creation" --msgbox "Successfully created volume at $encvolumelocation" 8 78
    echo "Successfully created volume at $encvolumelocation"
    echo "finish createvolume"
}

mountvolume() {
    echo "start mountvolume"
    if [ -z "$volumepassword" ]; then
        volumepassword=$(whiptail --passwordbox "Password for the encrypted volume:" \
        8 78 --title "Mounting encrypted container" 3>&1 1>&2 2>&3)
    else
        echo "volumepassword already known from creation"
    fi

    if [[ $encryptionprogram == *"Veracrypt"* ]]; then
        #mount new veracrypt volume
        echo veracrypt --mount $encmountpath --password not_shown --pim 0 --keyfiles "" --protect-hidden no --slot 11 --verbose
        veracrypt --mount $encvolumelocation $encmountpath --password $volumepassword --pim 0 --keyfiles "" --protect-hidden no --slot 11 --verbose &>/dev/null
        whiptail --title "Mounting encrypted container" --msgbox "The encrypted container was successfully mounted." 8 78
        echo "The encrypted container was successfully mounted."
    fi
    if [[ $encryptionprogram == *"LUKS"* ]]; then
        #mounting luks volume
        #cryptsetup luksOpen $encvolumelocation sswg
        echo $volumepassword | cryptsetup open --type luks $encvolumelocation sswg -q -
        mount /dev/mapper/sswg $encmountpath
    fi
    echo "finish mountvolume"
}

install_encryption_program
doyoualreadyhaveencryptedvolume
if [ $alreadyhaveencryptedvolume == true ]; then
    persistentmount
    mountvolume
else
    diskformatting
    persistentmount
    createvolume
    mountvolume
fi