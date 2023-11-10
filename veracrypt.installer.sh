#! /bin/bash
RED='\033[0;31m'
NC='\033[0m' # No Color

i=0
while [ $i -lt 5 ]; do
  echo ".............................."
  i=$(($i + 1))
done
echo -e ".........."${RED}"VeraCrypt"$NC"..........."
i=0
while [ $i -lt 5 ]; do
  echo ".............................."
  i=$(($i + 1))
done
apt-get install btrfs-progs -y &>/dev/null

read -p 'Do you already have and encrypted volume? (must be btrfs) [y/n] ' alreadyhaveencryptedvolume
if [ $alreadyhaveencryptedvolume = 'n' ]; then
  read -p 'Do you want formatting? [y/n] ' wantformat
  if [ $wantformat = 'y' ]; then
    echo -e $RED"You have chosen to format a partition."$NC
    echo -e $RED"Which file system woulf you like for the chosen partition? Preferred btrfs for compatibility (but veracrypt volume will use btrfs anyway). Default: btrfs"$NC
    read chosenfilesystem
    if [ -z "$chosenfilesystem" ]; then
      chosenfilesystem="btrfs"
    fi
    echo -e "You have chosen to use ${RED}$chosenfilesystem"$NC
    read -p "Which partition do you want formatted? eg. /dev/sda1 " partitiontoformat
    umount $partitiontoformat 2>/dev/null
    wipefs -a $partitiontoformat
    mkfs -t $chosenfilesystem $partitiontoformat >/dev/null
    echo -e $RED"${partitiontoformat}$NC has been formatted as ${RED}$chosenfilesystem"$NC
    sleep 3
  else
    echo -e $RED"You have chose not to format. \\n"$NC
    echo -e $RED"What file system do you have at your partition? Preferred btrfs for compatibility (but veracrypt volume will use btrfs anyway). Default: btrfs"$NC
    read chosenfilesystem
    if [ -z "$chosenfilesystem" ]; then
      chosenfilesystem="btrfs"
    fi
  fi
  #choose disk and setup automount
  echo -e ${RED}"Choose the patition on which you want the databases on:"$NC
  lsblk -o NAME,FSTYPE,LABEL,UUID,FSAVAIL,FSUSE%,MOUNTPOINTS
  blkid
  read -p "Disk UID [without the UUID=]: " diskuid
  umount /dev/disk/by-uuid/$diskuid 2>/dev/null
  read -p "Where do you want to persistently mount the databases? eg. /media/project": mountpath
  mountpath="$mountpath"$RND
  echo -e ${RED}$mountpath chosen for permanent mounting directory $NC
  echo $mountpath >$HOME/.config/$RND/mountpath
  encvolumelocation=$mountpath/data
  echo $encvolumelocation >$HOME/.config/$RND/encvolumelocation
  #read -p "Where do you want your encrypted volume mounted? (eg. ${mountpath}/mountedcontainer)" encmountpath
  encmountpath=$mountpath/mountedcontainer
  echo $encmountpath >$HOME/.config/$RND/encmountpath
  mkdir $mountpath

  echo "UUID="$diskuid $mountpath "$chosenfilesystem defaults 0 0" >>/etc/fstab
  mount -a
  cd $mountpath
  touch data #this is encvolumelocation
  mkdir $encmountpath

  #download and install veracrypt
  wget -q "https://launchpad.net/veracrypt/trunk/1.25.9/+download/veracrypt-console-1.25.9-Ubuntu-20.04-"$arch".deb"
  dpkg -i "veracrypt-console-1.25.9-Ubuntu-20.04-"$arch".deb" &>/dev/null
  rm "veracrypt-console-1.25.9-Ubuntu-20.04-"$arch".deb"
  echo -e ${RED}veracrypt successfully installed$NC

  #create veracrypt volume
  echo -e "Now creating new ${RED}VeraCrypt${NC} container"
  read -p 'Size eg. 200M or 10G: ' volumesize
  read -p "Enter password for new volume: "$'\n' -s password
  openssl rand -base64 -out randomdata.txt 10240
  veracrypt --create $encvolumelocation --size $volumesize --password $password --volume-type=normal --encryption=AES --hash=SHA-512 --filesystem=Btrfs --pim 0 --keyfiles "" --random-source randomdata.txt
  rm randomdata.txt

  #mount new veracrypt volume
  veracrypt --mount $encvolumelocation $encmountpath --password $password --pim 0 --keyfiles "" --protect-hidden no --slot 11 --verbose &>/dev/null
  echo -e "${RED}New encrypted container created at $encvolumelocation and mounted at $encmountpath $NC \n\n\n\n\n"
else
  ##you already have encrypted volume
  #download and install veracrypt
  wget -q "https://launchpad.net/veracrypt/trunk/1.25.9/+download/veracrypt-console-1.25.9-Ubuntu-20.04-"$arch".deb"
  dpkg -i "veracrypt-console-1.25.9-Ubuntu-20.04-"$arch".deb" &>/dev/null
  rm "veracrypt-console-1.25.9-Ubuntu-20.04-"$arch".deb"

  echo -e ${RED}"Choose the patition on which you have the encrypted volume on:"$NC
  lsblk -o NAME,FSTYPE,LABEL,UUID,FSAVAIL,FSUSE%,MOUNTPOINTS
  read -p "Disk UID [without the UUID=]: " diskuid
  umount /dev/disk/by-uuid/$diskuid 2>/dev/null
  read -p 'Where do you want your outer volume mounted? eg. /media/project' mountpath
  mountpath="$mountpath"$RND
  echo -e ${RED}$mountpath chosen for permanent mounting directory $NC
  echo $mountpath >$HOME/.config/$RND/mountpath
  mkdir $mountpath
  echo -e $RED"What file system do you have at your partition? Preferred btrfs for compatibility (but veracrypt volume will use btrfs anyway). Default: btrfs"$NC
  read chosenfilesystem
  if [ -z "$chosenfilesystem" ]; then
    chosenfilesystem="btrfs"
  fi
  echo "UUID=$diskuid $mountpath $chosenfilesystem defaults 0 0" >>/etc/fstab
  mount -a
  echo -e $RED"Your volume must not have keyfiles, pim, and hidden volume. It is strongly recommended to have a btrfs veracrypt volume."$NC
  read -p "Location of your encrypted volume: (eg.${mountpath}/data)" encvolumelocation
  if [ -z "$encvolumelocation" ]; then
    encvolumelocation="${mountpath}/data"
  fi
  echo $encvolumelocation >$HOME/.config/$RND/encvolumelocation
  read -p "Where do you want your encrypted volume mounted? (eg. ${mountpath}/mountedcontainer)" encmountpath
  if [ -z "$encmountpath" ]; then
    encmountpath="${mountpath}/mountedcontainer"
  fi
  mkdir $encmountpath
  echo $encmountpath >$HOME/.config/$RND/encmountpath
  read -p "Enter password for your existing veracrypt volume: "$'\n' -s password
  veracrypt --mount $encvolumelocation $encmountpath --password $password --pim 0 --keyfiles "" --protect-hidden no --slot 11 --verbose >/dev/null
  echo -e "${RED}Encrypted container at $encvolumelocation mounted at $encmountpath $NC\n\n\n\n\n"

fi
