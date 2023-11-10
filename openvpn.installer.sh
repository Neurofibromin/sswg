#! /bin/bash
RED='\033[0;31m'
NC='\033[0m' # No Color

i=0
while [ $i -lt 5 ]; do
  echo ".............................."
  i=$(($i + 1))
done
echo -e "..........."${RED}"OpenVPN"$NC"............"
i=0
while [ $i -lt 5 ]; do
  echo ".............................."
  i=$(($i + 1))
done

#get paths for configs and create OpenVPN root folder
read encmountpath <$configdir/encmountpath
openvpnpath=$encmountpath/OpenVPN
mkdir $openvpnpath
echo -e ${RED}$openvpnpath" is the folder for the OpenVPN config/PKI"$NC
echo -e ${RED}"Installing "$NC"OpenVPN"
apt-get install openvpn -y >/dev/null

#installing dependencies
echo -e ${RED}"Installing "$NC"dependencies"
apt-get install git tar curl grep dnsutils grepcidr whiptail net-tools bsdmainutils bash-completion -y >/dev/null
echo iptables-persistent iptables-persistent/autosave_v4 boolean true | sudo debconf-set-selections
echo iptables-persistent iptables-persistent/autosave_v6 boolean true | sudo debconf-set-selections
apt-get -y install iptables-persistent >/dev/null
sleep 4

#generating server x509 name (code from PiVPN):
host_name="$(hostname -s)"
# Generate a random UUID for this server so that we can use
# verify-x509-name later that is unique for this server
# installation.
NEW_UUID="$(< /proc/sys/kernel/random/uuid)"
# Create a unique server name using the host name and UUID
SERVER_NAME="${host_name}_${NEW_UUID}"

#download EasyRSA-3
cd $openvpnpath
echo -e ${RED}"EasyRSA-3 Install"$NC
wget -q https://github.com/OpenVPN/easy-rsa/releases/download/v3.1.2/EasyRSA-3.1.2.tgz
tar -xf EasyRSA-3.1.2.tgz &>/dev/null
rm EasyRSA-3.1.2.tgz
cd EasyRSA-3.1.2

#adjust vars parameters for easyrsa and initialize the PKI
echo -e ${RED}"PKI initialization, generating certificates and keys."$NC
./easyrsa --batch init-pki &>/dev/null
cp vars.example pki/vars
#algorithm set to elliptic curves
sed -i \
  "s/#set_var EASYRSA_ALGO.*/set_var EASYRSA_ALGO ec/" \
  pki/vars
#10 years set for certificate
sed -i \
  's/#set_var EASYRSA_CRL_DAYS.*/set_var EASYRSA_CRL_DAYS 3650/' \
  pki/vars
#elliptic curve is set to 521 bit
sed_pattern="s/#set_var EASYRSA_CURVE.*/"
sed_pattern="${sed_pattern} set_var EASYRSA_CURVE"
sed_pattern="${sed_pattern} secp521r1/"
sed -i "${sed_pattern}" pki/vars


#generating CA cert and key
./easyrsa --batch build-ca nopass &>/dev/null
cp pki/ca.crt $openvpnpath/ca.crt
#generating server cert and key
./easyrsa --batch build-server-full "${SERVER_NAME}" nopass &>/dev/null
cp pki/issued/${SERVER_NAME}.crt $openvpnpath/${SERVER_NAME}.crt
cp pki/private/${SERVER_NAME}.key $openvpnpath/${SERVER_NAME}.key
#generating HMAC key
openvpn --genkey secret pki/ta.key &>/dev/null
cp pki/ta.key $openvpnpath/ta.key
#generating certificate revocation list (empty for now)
./easyrsa gen-crl &>/dev/null
cp pki/crl.pem $openvpnpath/crl.pem

#add openvpn linux user
ovpnUserGroup="openvpn:openvpn"
if ! getent passwd "${ovpnUserGroup%:*}"; then
  useradd --system --home /var/lib/openvpn/ --shell /usr/sbin/nologin "${ovpnUserGroup%:*}"
fi
chown openvpn:openvpn $openvpnpath/crl.pem
echo "Server certificates and keys generated, new openvpn linux user added."

#ipv4 forwarding turned on, same as net.ipv4.ip_forward=1
#may not work on armbian
#sed -i "s/#net.ipv4.ip_forward.*/net.ipv4.ip_forward=1/" /etc/sysctl.conf
#reload kernel parameters at runtime from /etc/sysctl.conf:
##sysctl -p
sysctl -w net.ipv4.ip_forward=1

#ask for port to be used by server
#copy config file to destination
cp $projectroot/openvpn.server.conf $openvpnpath/openvpn.server.conf
read -p "Protocoll UDP, which port would you like to use? (eg.1194) " portnumber
if [ -z "$portnumber" ] || [ $portnumber == "1194" ]; then
  echo "You have chosen to keep using the 1194 port"
  portnumber="1194"
else
  echo "You chose $portnumber port"
  sed -i "s/port 1194*/port $portnumber/" $openvpnpath/openvpn.server.conf
fi

#set openvpn.server.conf certificate and key paths and allocate random subnet for use
echo -e ${RED}"server config file generation"$NC
subnet=10.$(($RANDOM%255)).$(($RANDOM%255)).0
cp $projectroot/openvpn.clientgenerator.sh $openvpnpath/openvpn.clientgenerator.sh
sed -i "s/server 10.0.8.0.*/server $subnet 255.255.255.0/" $openvpnpath/openvpn.server.conf
sed -i "s/ca ca.crt/ca ${openvpnpath//\//\\\/}\/ca.crt/" $openvpnpath/openvpn.server.conf
sed -i "s/cert server.crt/cert ${openvpnpath//\//\\\/}\/${SERVER_NAME}.crt/" $openvpnpath/openvpn.server.conf
sed -i "s/key server.key/key ${openvpnpath//\//\\\/}\/${SERVER_NAME}.key/" $openvpnpath/openvpn.server.conf
sed -i "s/tls-crypt ta.key/tls-crypt ${openvpnpath//\//\\\/}\/ta.key/" $openvpnpath/openvpn.server.conf
sed -i "s/crl-verify crl.pem/crl-verify ${openvpnpath//\//\\\/}\/crl.pem/" $openvpnpath/openvpn.server.conf

#generating Defaults.txt which will be used for client configs
read -p "DNS name or ip address to be used: (eg. example.contoso.com) " dnsname
echo -e "${RED}$dnsname${NC} was chosen as server dns/connetion ip"
cat <<EOT >>$openvpnpath/Default.txt
client
dev tun
proto udp
remote $dnsname $portnumber
resolv-retry infinite
nobind
remote-cert-tls server
tls-version-min 1.2
verify-x509-name ${SERVER_NAME} name
cipher AES-256-CBC
auth SHA256
auth-nocache
verb 3
EOT

#generating certificates for one client
echo -e $RED"Client name:\n (default: client1) "$NC
read clientname
if [ -z "$clientname" ]; then
  clientname="client1"
fi
echo "${clientname} will be used as client name"
./easyrsa build-client-full ${clientname}
cp ./pki/issued/${clientname}.crt $openvpnpath/${clientname}.crt
cp ./pki/private/${clientname}.key $openvpnpath/${clientname}.key

#ovpns creation
#comments from Eric Jodoin's script
DEFAULT="$openvpnpath/Default.txt"
FILEEXT="$openvpnpath/${clientname}.ovpn"
CRT="$openvpnpath/${clientname}.crt"
KEY="$openvpnpath/${clientname}.key"
CA="$openvpnpath/ca.crt"
TA="$openvpnpath/ta.key"
echo "Client cert found: $CRT"
echo "Client Private Key found: $KEY"
echo "CA public Key found: $CA"
echo "tls-auth Private Key found: $TA"
#Ready to make a new .opvn file - Start by populating with the default file
cat $DEFAULT > $FILEEXT
#Now, append the CA Public Cert
echo "<ca>" >> $FILEEXT
cat $CA >> $FILEEXT
echo "</ca>" >> $FILEEXT
#Next append the client Public Cert
echo "<cert>" >> $FILEEXT
cat $CRT | sed -ne '/-BEGIN CERTIFICATE-/,/-END CERTIFICATE-/p' >> $FILEEXT
echo "</cert>" >> $FILEEXT
#Then, append the client Private Key
echo "<key>" >> $FILEEXT
cat $KEY >> $FILEEXT
echo "</key>" >> $FILEEXT
#Finally, append the TA Private Key
echo "<tls-crypt>" >> "$FILEEXT"
cat "$TA" >> $FILEEXT
echo "</tls-crypt>" >> $FILEEXT
echo "Done! $FILEEXT Successfully Created."

#changing iptables to allow vpn traffic
#asking for network interface
read -p "what is the local ip of the server (on the interface the openvpn functionality is desired on) (eg. 192.168.1.50)" localip
echo "Choose interface "
ip -o link
read -p "interface name: (eg. eth0)" interfacename
#iptables -t nat -A POSTROUTING -s $subnet/24 -o $interfacename -j SNAT --to-source $localip
#echo "iptables -t nat -A POSTROUTING -s $subnet/24 -o $interfacename -j SNAT --to-source $localip"
iptables -t nat -I POSTROUTING -s "${subnet}/24" -o "${interfacename}" -j MASQUERADE
sed -i "s/#iptables rule*/iptables -t nat -I POSTROUTING -s ${subnet}\/24 -o ${interfacename} -j MASQUERADE/" $projectroot/startup.sh
#echo "iptables -t nat -I POSTROUTING -s ${subnet}/24 -o ${interfacename} -j MASQUERADE -m comment --comment OpenVPN-nat-rule"
#consider https://gist.github.com/mattbell87/ec1c1fa974fa989249a4bd0fbc8b8857
#saving changes with iptables-persistent
iptables-save >/dev/null

sudo openvpn $openvpnpath/openvpn.server.config &
echo -e "${RED}OpenVPN${NC} server install finished, you can generate ${RED}new clients${NC} with $openvpnpath/openvpn.clientgenerator.sh\n\n\n\n\n"