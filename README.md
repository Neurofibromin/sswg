# sswg

server setup with graphical user interface



## Current status

Not under active development. There are so many good alternatives available.

## alternatives

[CasaOS](https://casaos.io/)<br/>
[openmediavault](https://www.openmediavault.org/)<br/>
[TrueNAS Core](https://www.truenas.com/)<br/>


## Usage
### run with:
> sudo bash main.sh

## working features:
**whiptail** for easy interaction<br/>
veracrypt volume creation <br/>
LUKS volume creation <br/>
persistent mounting of partition<br/>
partition formatting<br/>
dotfile generation<br/>
samba setup<br/>
urbackup server install and initial setup<br/>
NextCloud setup and apache settings configuration<br/>
certbot ingetgration (with some manual intervention)<br/>
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
set certificate best before length for openvpn clients<br/>

global/local variables in functions<br/>
implement other OS apart from ubuntu/debian

base64 enc?:<br/>
openssl base64 < sound.m4a<br/>
and then in the script:<br/>
```
    S=<<SOUND
    YOURBASE64GOESHERE
    SOUND
    echo $S | openssl base64 -d | play
```

sed startup.sh no such file or directory (openvpn end)<br/>
cryptsetup volumecreation asks for password in console<br/>
veracrypt install console

## sources:
https://github.com/StarshipEngineer/OpenVPN-Setup/ <br/>
https://github.com/OpenVPN/easy-rsa <br/>
https://pivpn.io/ <br/>
