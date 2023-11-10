#! /bin/bash
#sets up hostapd, dnsmasq, dhcpcd, and iptables
systemctl stop systemd-resolved
systemctl disable systemd-resolved
systemctl mask systemd-resolved
apt install hostapd
systemctl unmask hostapd
systemctl enable hostapd
systemctl start hostapd
apt install dnsmasq
apt install dhcpcd5
DEBIAN_FRONTEND=noninteractive apt install -y netfilter-persistent iptables-persistent
cat <<EOT >> /etc/dhcpcd.conf
interface wlan0
    static ip_address=192.168.4.1/24
    nohook wpa_supplicant
EOT
echo "net.ipv4.ip_forward=1" >> /etc/sysctl.d/routed-ap.conf
iptables -t nat -A POSTROUTING -o eth0 -j MASQUERADE
netfilter-persistent save
mv /etc/dnsmasq.conf /etc/dnsmasq.conf.orig
cat <<EOT >> /etc/dnsmasq.conf
interface=wlan0 # Listening interface
dhcp-range=192.168.4.2,192.168.4.20,255.255.255.0,24h
                # Pool of IP addresses served via DHCP
domain=wlan     # Local wireless DNS domain
address=/gw.wlan/192.168.4.1
                # Alias for this router
EOT

sudo rfkill unblock wlan
read -p "SSID for hotspot: eg. MyHotspot" hotspotssid
read -p "Password for hotspot (WPA2):" -s hotspotpassword
echo -e $RED Change your country code in /etc/hostapd/hostapd.conf manually$NC

cat <<EOT >> /etc/hostapd/hostapd.conf
country_code=GB
interface=wlan0
ssid=$hotspotssid
hw_mode=a
channel=58
macaddr_acl=0
auth_algs=1
ignore_broadcast_ssid=1
wpa=2
wpa_passphrase=$hotspotpassword
wpa_key_mgmt=WPA-PSK
wpa_pairwise=TKIP
rsn_pairwise=CCMP
EOT