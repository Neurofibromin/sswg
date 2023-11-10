#! /bin/bash

RED='\033[0;31m'
NC='\033[0m' # No Color

i=0
while [ $i -lt 5 ]
do
echo ".............................."
i=$(($i+1))
done
echo -e ".........."${RED}"NextCloud"$NC"..........."
i=0
while [ $i -lt 5 ]
do
echo ".............................."
i=$(($i+1))
done

#read and create directory for nextcloud
read encmountpath <$HOME/.config/$RND/encmountpath
#nextcloudpath=$encmountpath/nextcloud
nextcloudpath="/nextcloud"
mkdir $nextcloudpath
mkdir $nextcloudpath/data
chown -R www-data:www-data $nextcloudpath

#install dependencies
echo -e ${RED}"Starting nextcloud dependency install"$NC
apt-get install apache2 mariadb-server libapache2-mod-php php-gd php-mysql \
php-curl php-mbstring php-intl php-gmp php-bcmath php-xml php-imagick php-zip -y &>/dev/null
echo -e ${RED}"Dependency"$NC" install finished"

#set up database
echo -e ${RED}"Database "$NC"setup"
echo -e "\nNextcloud db new user username (should be p1ne): "
read nextclouddbusername
echo -e "\nChoose new password for $nextclouddbusername: "
read -s password
echo -e "\nRootpass to interact with mysql:"
read -s rootpasswd
mysql -uroot -p${rootpasswd} -e "CREATE USER '${nextclouddbusername}'@'localhost' IDENTIFIED BY '${password}';"
mysql -uroot -p${rootpasswd} -e "CREATE DATABASE IF NOT EXISTS nextcloud CHARACTER SET utf8mb4 COLLATE utf8mb4_general_ci;"
mysql -uroot -p${rootpasswd} -e "GRANT ALL PRIVILEGES ON nextcloud.* TO '${nextclouddbusername}'@'localhost';"
mysql -uroot -p${rootpasswd} -e "FLUSH PRIVILEGES;"


#download, copy and permission for nextcloud stack
echo -e ${RED}"Downloading Nextcloud tar"$NC
cd $nextcloudpath
wget -q https://download.nextcloud.com/server/releases/latest.tar.bz2
tar -xjvf latest.tar.bz2 >/dev/null
mv nextcloud /var/www
chown -R www-data:www-data /var/www/nextcloud

#ssl
read -p "What is the domain name of the server? without www (eg. contoso.com)" domainname
#call ssl.cert.generator.sh to generate the certs, handla the permissions and copy them for location
bash $projectroot/ssl.cert.generator.sh $domainname $nextcloudpath

#apache configuration
echo -e "Configuring ${RED}Apache${NC}"
cp $projectroot/apache.configs.conf /etc/apache2/sites-available/nextcloud.conf
chown www-data:www-data /etc/apache2/sites-available/nextcloud.conf
#disable the default configs
a2dissite 000-default.conf &>/dev/null
a2dissite default-ssl.conf &>/dev/null
sed -i "s/ServerName cloud.nextcloud.com*/ServerName $domainname/" /etc/apache2/sites-available/nextcloud.conf
sed -i "s/SSLCertificateFile \/path\/cert.pem*/SSLCertificateFile ${nextcloudpath//\//\\\/}\/certs\/fullchain.pem/" /etc/apache2/sites-available/nextcloud.conf
sed -i "s/SSLCertificateKeyFile \/path\/private.key*/SSLCertificateKeyFile ${nextcloudpath//\//\\\/}\/certs\/privkey.pem/" /etc/apache2/sites-available/nextcloud.conf
a2enmod -q rewrite socache_shmcb headers mime dir env ssl &>/dev/null
a2enmod -q setenvif &>/dev/null #If you’re running mod_fcgi instead of the standard mod_php also enable
#a2ensite default-ssl
a2ensite nextcloud.conf &>/dev/null
apachectl configtest
apachectl stop &>/dev/null
apachectl start &>/dev/null
service apache2 restart &>/dev/null

#install the extracted nextcloud dir
echo -e "Installing the extracted tarball."
echo -e "Nextcloud admin creation. What would you like the admin username to be?"
read nextcloudaminuser
echo -e "Nextcloud new admin password for $nextcloudaminuser"
read -s nextcloudaminpassword
cd /var/www/nextcloud/
#Using the php occ command from the nextcloud dir to finish the install (instead of the webui)
echo -e "Creating admin user and finalising install..."
sudo -u www-data php occ  maintenance:install --database \
"mysql" --database-name "nextcloud"  --database-user "${nextclouddbusername}" --database-pass \
"${password}" --admin-user "${nextcloudaminuser}" --admin-pass "${nextcloudaminpassword}" --data-dir "$nextcloudpath/data"
echo -e "${RED}Nextcloud install done${NC}"

#Adding trusted domain names to the nextcloud config array #######################
sed -i \
  "s/*0 => 'localhost',*/0 => 'localhost', 1 => '$domainname', 2 => 'www.$domainname', /" \
  /var/www/nextcloud/config/config.php


sed -i "s/^\s*0*/worked/" /var/www/nextcloud/config/config.php


#hardening security
#set up fail2ban, according to the nextcloud documentation presets
echo "Setting up fail2ban"
apt-get install fail2ban -y &>/dev/null
cat <<EOT >>/etc/fail2ban/filter.d/nextcloud.conf
[Definition]
_groupsre = (?:(?:,?\s*"\w+":(?:"[^"]+"|\w+))*)
failregex = ^\{%(_groupsre)s,?\s*"remoteAddr":"<HOST>"%(_groupsre)s,?\s*"message":"Login failed:
            ^\{%(_groupsre)s,?\s*"remoteAddr":"<HOST>"%(_groupsre)s,?\s*"message":"Trusted domain error.
datepattern = ,?\s*"time"\s*:\s*"%%Y-%%m-%%d[T ]%%H:%%M:%%S(%%z)?"
EOT
##nextcloud log file must be linked correctly, but permissions do not need to be changed:
cat <<EOT >>/etc/fail2ban/jail.d/nextcloud.local
[nextcloud]
backend = auto
enabled = true
port = 80,443
protocol = tcp
filter = nextcloud
maxretry = 3
bantime = 86400
findtime = 43200
logpath = $nextcloudpath/data/nextcloud.log
EOT
systemctl start fail2ban &>/dev/null
systemctl disable fail2ban &>/dev/null
sleep 3
fail2ban-client status nextcloud

#redirect http to https, disable http connections - all done in apache.configs.conf
#########Apache has to be configured to use the .htaccess file

#installing modsec
apt-get install libapache2-mod-security2 git -y >/dev/null
cp /etc/modsecurity/modsecurity.conf-recommended /etc/modsecurity/modsecurity.conf
sed -i "s/SecRuleEngine DetectionOnly*/SecRuleEngine On/" /etc/modsecurity/modsecurity.conf
sed -i "s/SecDataDir \/tmp\/*/SecDataDir \/var\/cache\/modsecurity/" /etc/modsecurity/modsecurity.conf
sed -i "s/SecTmpDir \/tmp\/*/SecTmpDir \/var\/cache\/modsecurity/" /etc/modsecurity/modsecurity.conf
cd $nextcloudpath
git clone https://github.com/SpiderLabs/owasp-modsecurity-crs.git
cd owasp-modsecurity-crs
mv crs-setup.conf.example /etc/modsecurity/crs-setup.conf
mv rules/ /etc/modsecurity
rm -rf $nextcloudpath/owasp-modsecurity-crs
#adding config setting to config file
a2enmod security2
sed -i "/^\s*IncludeOptional \/etc\/modsecurity\/*/a Include \/etc\/modsecurity\/rules\/\*.conf" /etc/apache2/mods-enabled/security2.conf
sed -i "s/^\s*IncludeOptional \/usr\/share\/modsecurity-crs\/*/#IncludeOptional \/usr\/share\/modsecurity-crs\//" /etc/apache2/mods-enabled/security2.conf



#apt-get install snapd
#snap install nextcloud
#for upgrading the database
#sudo -u www-data php occ upgrade