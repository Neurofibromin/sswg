#! /bin/bash
#on system start mount volume, start services
# inserted into line 4: "configdir=$HOME/.config/$RND"
#configdir=/root/.config/4191662409282 #temp because of read only fs
#iptables rule


read mountpath <"$configdir"/mountpath
read encmountpath <"$configdir"/encmountpath
read encvolumelocation <"$configdir"/encvolumelocation

#mouning veracrypt container
read -p "Password for mounting $encvolumelocation to $encmountpath: " -s password ##commented because of read only fs (act no)
#password=""
veracrypt --mount "$encvolumelocation" "$encmountpath" --password "$password" --pim 0 --keyfiles "" --protect-hidden no --slot 11 --verbose
echo -e "${RED}Encrypted container at $encvolumelocation mounted on $encmountpath $NC"



#start services

openvpn "$encmountpath"/OpenVPN/openvpn.server.conf &
systemctl start urbackupsrv.service
systemctl start smbd.service
systemctl start fail2ban
echo startup finished