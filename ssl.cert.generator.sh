#! /bin/bash
#generate ssl cert
echo -e "Installing certbot..."
apt-get install snapd -y >/dev/null
snap install core &>/dev/null
snap refresh core &>/dev/null
snap install --classic certbot &>/dev/null
ln -s /snap/bin/certbot /usr/bin/certbot
domainname=$1
nextcloudpath=$2
#if using port 80/443: sudo certbot --apache and its finished - certbot with letsencrypt only connects to port 80/443 on external ip
certbot certonly --manual --preferred-challenges dns -d ${domainname} -d www.${domainname}
#manually add dns txt record
mkdir $nextcloudpath/certs
cp /etc/letsencrypt/live/$domainname/fullchain.pem $nextcloudpath/certs/fullchain.pem
cp /etc/letsencrypt/live/$domainname/privkey.pem $nextcloudpath/certs/privkey.pem
chown www-data:www-data $nextcloudpath/certs/fullchain.pem
chown www-data:www-data $nextcloudpath/certs/privkey.pem