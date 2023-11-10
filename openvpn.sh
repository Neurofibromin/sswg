#! /bin/bash


openvpn_getfolder() {
    echo "start openvpn_getfolder"
    if (whiptail --title "OpenVPN" --yesno \
    "Do you want to change the working folder for OpenVPN?" 10 78); then
        if [ $encmountpath != "" ]; then #check if encryption is used
            #there is encryption, but should it be used for OpenVPN?
            openvpnpath=$(whiptail --title "OpenVPN" --inputbox \
            "Which folder would you like to use for OpenVPN?" 8 78 $encmountpath/OpenVPN 3>&1 1>&2 2>&3)
        else
            openvpnpath=$(whiptail --title "OpenVPN" --inputbox \
            "Which folder would you like to use for OpenVPN?" 8 78 /etc/sswg/OpenVPN 3>&1 1>&2 2>&3)        
        fi
    else
        if [ $encmountpath != "" ]; then #check if encryption is used
            openvpnpath="$encmountpath/OpenVPN"        
        else
            openvpnpath="/etc/sswg/OpenVPN"
        fi    
    fi
    mkdir $openvpnpath
    echo "openvpnpath: $openvpnpath"
    echo "openvpnpath=\"$openvpnpath\"" >> /etc/sswg/config.txt
    whiptail --title "OpenVPN" --msgbox "Install successfull.\n$openvpnpath is the folder for the OpenVPN config/PKI" 8 78
    echo "finish openvpn_getfolder"
}
install_openvpn() {
    whiptail --title "OpenVPN install" --msgbox "OpenVPN and its dependencies are being installed" 8 78
    packageinstall "openvpn git tar curl grep dnsutils grepcidr net-tools bsdmainutils bash-completion"

}
easyrsa_all() {
    echo "start easyrsa_all"
    #generating server x509 name (code from PiPVN):
    host_name="$(hostname -s)"
    # Generate a random UUID for this server so that we can use
    # verify-x509-name later that is unique for this server
    # installation.
    NEW_UUID="$(< /proc/sys/kernel/random/uuid)"
    # Create a unique server name using the host name and UUID
    SERVER_NAME="${host_name}_${NEW_UUID}"

    #download EasyRSA-3
    cd $openvpnpath
    whiptail --title "EasyRSA-3 Install" --msgbox \
    "EasyRSA is being installed and PKI is set up." 8 78
    wget -q https://github.com/OpenVPN/easy-rsa/releases/download/v3.1.4/EasyRSA-3.1.4.tgz
    tar -xf EasyRSA-3.1.4.tgz &>/dev/null
    rm EasyRSA-3.1.4.tgz
    cd EasyRSA-3.1.4

    #adjust vars parameters for easyrsa and initialize the PKI
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

    whiptail --title "EasyRSA" --msgbox "Key generation and PKI setup finished." 8 78
    echo "Key generation and PKI setup finished."
    echo "finish easyrsa_all"
}
generate_openvpn_config() {
    #set openvpn.server.conf certificate and key paths and allocate random subnet for use
    whiptail --title "OpenVPN" --msgbox "OpenVPN server config file generation" 8 78
    echo "OpenVPN server config file generation"
    #write config file to destination
    cat << EOT >> $openvpnpath/openvpn.server.conf
    dev tun
    proto udp
    port 1194
    ca ca.crt
    cert server.crt
    key server.key
    dh none
    ecdh-curve secp384r1
    topology subnet
    server 10.0.8.0 255.255.255.0
    # pushes the dns server address to the client
    push "dhcp-option DNS 208.67.222.222" 
    push "dhcp-option DNS 208.67.220.220"
    client-to-client
    #client-config-dir #########
    keepalive 10 120
    remote-cert-tls client
    tls-version-min 1.2
    tls-crypt ta.key
    cipher AES-256-CBC
    auth SHA256
    user openvpn
    group openvpn
    persist-key
    persist-tun
    crl-verify crl.pem

    ifconfig-pool-persist ipp.txt
    ;push "route 192.168.10.0 255.255.255.0"
    ;push "route 192.168.20.0 255.255.255.0"
    # Override the Client default gateway by using 0.0.0.0/1 and
    # 128.0.0.0/1 rather than 0.0.0.0/0. This has the benefit of
    # overriding but not wiping out the original default gateway.
    push "redirect-gateway def1"

    # Prevent DNS leaks on Windows
    push "block-outside-dns"

    # logging settings
    status openvpn-status.log
    status-version 3
    ;syslog
    verb 3
EOT
    subnet=10.$(($RANDOM%255)).$(($RANDOM%255)).0
    cat << EOT >> $openvpnpath/openvpn.clientgenerator.sh
    #! /bin/bash
    . /etc/sswg/config.txt
    #openvpnpath=$openvpnpath
    cd $openvpnpath/EasyRSA-3.1.2
    clientname=client$RANDOM
    clientname2=$(whiptail --title "OpenVPN" --inputbox "Client name: (default: client1)" 8 78 client1 3>&1 1>&2 2>&3)
    if [ -z "$clientname2" ]; then
        whiptail --title "OpenVPN" --msgbox "${clientname} will be used as client name" 8 78
    else
        clientname="${clientname2}"
        whiptail --title "OpenVPN" --msgbox "${clientname} will be used as client name" 8 78
    fi
    ./easyrsa build-client-full ${clientname}
    cp ./pki/issued/${clientname}.crt $openvpnpath/${clientname}.crt
    cp ./pki/private/${clientname}.key $openvpnpath/${clientname}.key
    DEFAULT="$openvpnpath/Default.txt"
    FILEEXT="$openvpnpath/${clientname}.ovpn"
    CRT="$openvpnpath/${clientname}.crt"
    KEY="$openvpnpath/${clientname}.key"
    CA="$openvpnpath/ca.crt"
    TA="$openvpnpath/ta.key"
    whiptail --title "OpenVPN" --msgbox "Client cert \
    found: $CRT\nClient Private Key found: $KEY\nCA \
    public Key found: $CA\ntls-auth Private Key found: $TA" 12 78
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
    echo "<tls-crypt>" >> $FILEEXT
    cat $TA >> $FILEEXT
    echo "</tls-crypt>" >> $FILEEXT
    whiptail --title "OpenVPN" --msgbox "Done! $FILEEXT Successfully Created." 8 78
EOT
    sed -i "s/server 10.0.8.0.*/server $subnet 255.255.255.0/" $openvpnpath/openvpn.server.conf
    sed -i "s/ca ca.crt/ca ${openvpnpath//\//\\\/}\/ca.crt/" $openvpnpath/openvpn.server.conf
    sed -i "s/cert server.crt/cert ${openvpnpath//\//\\\/}\/${SERVER_NAME}.crt/" $openvpnpath/openvpn.server.conf
    sed -i "s/key server.key/key ${openvpnpath//\//\\\/}\/${SERVER_NAME}.key/" $openvpnpath/openvpn.server.conf
    sed -i "s/tls-crypt ta.key/tls-crypt ${openvpnpath//\//\\\/}\/ta.key/" $openvpnpath/openvpn.server.conf
    sed -i "s/crl-verify crl.pem/crl-verify ${openvpnpath//\//\\\/}\/crl.pem/" $openvpnpath/openvpn.server.conf
    echo "finished OpenVPN server config file generation"
}
askforopenvpnport() {
    #ask for port to be used by server
    openvpnportnumber=$(whiptail --title "OpenVPN" --inputbox "Protocoll UDP, which port would you like to use? (eg.1194)" 8 78 1194 3>&1 1>&2 2>&3)
    if [ -z "$openvpnportnumber" ] || [ $openvpnportnumber == "1194" ]; then
        whiptail --title "OpenVPN" --msgbox "You have chosen the port 1194" 8 78
        openvpnportnumber="1194"
    else
        whiptail --title "OpenVPN" --msgbox "You have chosen the port $openvpnportnumber" 8 78
        sed -i "s/port 1194*/port $openvpnportnumber/" $openvpnpath/openvpn.server.conf
    fi
    echo "openvpnportnumber: $openvpnportnumber"
}
generate_defaultstxt() {
    #generating Defaults.txt which will be used for client configs
    domainname=$(whiptail --title "OpenVPN" --inputbox \
    "DNS name or ip address to be used: (eg. example.contoso.com)" \
    8 78 3>&1 1>&2 2>&3)
    echo "domainname $domainname"
    whiptail --title "OpenVPN" --msgbox "$domainname was chosen as server dns/connection ip" 8 78
    export DOMAINNAME=$domainname
    cat <<EOT >>$openvpnpath/Default.txt
    client
    dev tun
    proto udp
    remote $domainname $openvpnportnumber
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
}
openvpnclientgenerate() {
    #generating certificates for one client
    clientname=$(whiptail --title "OpenVPN" --inputbox "Client name: (default: client1)" 8 78 client1 3>&1 1>&2 2>&3)
    if [ -z "$clientname" ]; then
        clientname="client1"
    fi
    whiptail --title "OpenVPN" --msgbox "${clientname} will be used as client name" 8 78
    echo "openvpn clientgeneration clientname: $clientname"
    ./easyrsa build-client-full ${clientname}
    cp ./pki/issued/${clientname}.crt $openvpnpath/${clientname}.crt
    cp ./pki/private/${clientname}.key $openvpnpath/${clientname}.key
}
ovpnscreator() {
    #ovpns creation
    echo "ovpns creation"
    #comments from Eric Jodoin's script
    DEFAULT="$openvpnpath/Default.txt"
    FILEEXT="$openvpnpath/${clientname}.ovpn"
    CRT="$openvpnpath/${clientname}.crt"
    KEY="$openvpnpath/${clientname}.key"
    CA="$openvpnpath/ca.crt"
    TA="$openvpnpath/ta.key"
    whiptail --title "OpenVPN" --msgbox "Client cert \
    found: $CRT\nClient Private Key found: $KEY\nCA \
    public Key found: $CA\ntls-auth Private Key found: $TA" 12 78
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
    whiptail --title "OpenVPN" --msgbox "Done! $FILEEXT Successfully Created." 8 78
    echo "$FILEEXT Successfully Created"
}
interface_ip_security() {
    echo iptables-persistent iptables-persistent/autosave_v4 boolean true | sudo debconf-set-selections
    echo iptables-persistent iptables-persistent/autosave_v6 boolean true | sudo debconf-set-selections


    #ipv4 forwarding turned on, same as net.ipv4.ip_forward=1
    #may not work on armbian
    #sed -i "s/#net.ipv4.ip_forward.*/net.ipv4.ip_forward=1/" /etc/sysctl.conf
    #reload kernel parameters at runtime from /etc/sysctl.conf:
    ##sysctl -p
    sysctl -w net.ipv4.ip_forward=1

    #changing iptables to allow vpn traffic
    #asking for network interface
    interfacechoose=""
    interfacenames=$(ip -o link | awk '{print $2}' | sed 's/.$//')
    for interface in $interfacenames
    do
        interfacechoose+="$interface "
        interfacechoose+=\"$(ip -f inet addr show $interface | awk '/inet / {print $2}')\"
        interfacechoose+=" OFF "
    done
    interfacechoose+="other None_of_these_manual OFF"
    interfacename=$(whiptail --title "OpenVPN" --radiolist "Which network interface would you like " 20 78 10 $interfacechoose 3>&1 1>&2 2>&3)

    if [ $interfacename == "other" ]; then
        #set ip and interface manually
        interfacename=$(whiptail --title "OpenVPN" --inputbox \
        "Manual input\nInterface name: (eg. eth0)" 8 78 3>&1 1>&2 2>&3)
        localip=$(whiptail --title "OpenVPN" --inputbox \
        "Manual input\nWhat is the local ip of the server\n(on \
        the interface the openvpn \
        functionality is desired on)\n(eg. 192.168.1.50)" 8 78 3>&1 1>&2 2>&3)
    else
        #set ip address automatically
        localip=$(ip -f inet addr show $interfacename | awk '/inet / {print $2}')
        if [ -z "$localip" ]; then
            whiptail --title "Error" --msgbox \
            "Chosen interface $interfacename does not \
            have ip associated with it." 8 78
            exit 1
        fi
    fi
    
    #iptables -t nat -A POSTROUTING -s $subnet/24 -o $interfacename -j SNAT --to-source $localip
    #echo "iptables -t nat -A POSTROUTING -s $subnet/24 -o $interfacename -j SNAT --to-source $localip"
    iptables -t nat -I POSTROUTING -s "${subnet}/24" -o "${interfacename}" -j MASQUERADE
    sed -i "s/#iptables rule*/iptables -t nat -I POSTROUTING -s ${subnet}\/24 -o ${interfacename} -j MASQUERADE/" $projectroot/startup.sh
    #echo "iptables -t nat -I POSTROUTING -s ${subnet}/24 -o ${interfacename} -j MASQUERADE -m comment --comment OpenVPN-nat-rule"
    #consider https://gist.github.com/mattbell87/ec1c1fa974fa989249a4bd0fbc8b8857
    #saving changes with iptables-persistent
    iptables-save >/dev/null

}


. /etc/sswg/config.txt
install_openvpn
openvpn_getfolder
packageinstall "iptables-persistent"
easyrsa_all
#add openvpn linux user
ovpnUserGroup="openvpn:openvpn"
if ! getent passwd "${ovpnUserGroup%:*}"; then
useradd --system --home /var/lib/openvpn/ --shell /usr/sbin/nologin "${ovpnUserGroup%:*}"
fi
chown openvpn:openvpn $openvpnpath/crl.pem

generate_openvpn_config
askforopenvpnport
generate_defaultstxt
openvpnclientgenerate
ovpnscreator
interface_ip_security

sudo openvpn $openvpnpath/openvpn.server.config & &>/dev/null
whiptail --title "OpenVPN" --msgbox "OpenVPN installation, setup and initial client generation is finished,\nthe server is running at $openvpnportnumber on $localip at $interfacename.\nYou can generate new clients with $openvpnpath/openvpn.clientgenerator.sh" 14 78
echo -e "OpenVPN installation, setup and initial client generation is finished,\nthe server is running at $openvpnportnumber on $localip at $interfacename.\nYou can generate new clients with $openvpnpath/openvpn.clientgenerator.sh"