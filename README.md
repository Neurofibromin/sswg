# server-handling
initial zero trust server

## run with:
> sudo bash ubuntu_20.04_only.sh

## working features:
veracrypt volume creation <br/>
persistent mounting of partition<br/>
partition formatting<br/>
dotfile generation<br/>
samba setup<br/>
urbackup server install and initial setup<br/>
openvpn server setup and client creation


## limitations:
chosen disk must not be already in fstab<br/>
is not autostarted, startup.sh must be run at every startup<br/>
only routed vpn (not bridged)	<br/>
veracrypt container can't be ntfs (you want btrfs anyway)<br/>
ipv6 forwarding has to be blocked manually<br/>
the certbot certificates aren't renewed

## bugs:
as script is run as sudo, the /root/.config has the dotfiles... also the smb user added is root.<br/>
openvpn sed iptables doesn't work<br/>
openvpn process stops after a while? use symbolic links

## features to add:
automate urbackup config<br/>
check for sensitive data<br/>
check armbian net.ipv4.ip_forward=1<br/>
set certificate best before length for openvpn clients

## sources:
https://github.com/StarshipEngineer/OpenVPN-Setup/ <br/>
https://github.com/OpenVPN/easy-rsa <br/>
https://pivpn.io/ <br/>