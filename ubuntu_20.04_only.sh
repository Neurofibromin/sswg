#! /bin/bash
RED='\033[0;31m'
NC='\033[0m' # No Color


export projectroot=$PWD
((RND=(RANDOM<<15|RANDOM)<<15|RANDOM))
#RND=4191662409282 #mert read only fs
export RND
export configdir=$HOME/.config/$RND
arch=$(dpkg --print-architecture)
export arch

#create directory if it doesn't exist
[ ! -d "$HOME/.config/$RND" ] && mkdir -p "$HOME/.config/$RND"



bash ./veracrypt.installer.sh
read encmountpath <"$configdir"/encmountpath #read only fs
#bash startup.sh #read only fs
bash ./openvpn.installer.sh
#adding config path to the openvpn client generator script (only possible if openvpn.installer.sh has run)
sed -i "s/configdir=config/configdir=${HOME//\//\\\/}\/.config\/$RND/" "$encmountpath"/OpenVPN/openvpn.clientgenerator.sh
bash ./urbackup.installer.sh
bash ./samba.installer.sh
#bash ./nextcloud.installer.sh
#still not working #bash ./ hotspot.installer.sh

sed -i "4 i configdir=$HOME/.config/$RND" "$PWD"/startup.sh # read only fs

bash misc.sh &>/dev/null
echo -e "$RED finished $NC"
checkifactive()
{
  systemctl is-active --quiet $1 && echo "$2 is running" || echo "$2 is not running"
}
checkifactive smbd Samba
checkifactive urbackupsrv Urbackup
checkifactive openvpn Openvpn