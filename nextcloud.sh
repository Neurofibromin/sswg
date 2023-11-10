#! /bin/bash

nextcloud_getfolder() {
    if (whiptail --title "Nextcloud" --yesno \
    "Do you want to change the working folder for Nextcloud?" 10 78); then
        if [ $encmountpath != "" ]; then #check if encryption is used
            #there is encryption, but should it be used for Nextcloud?
            nextcloudpath=$(whiptail --title "Nextcloud" --inputbox \
            "Which folder would you like to use for Nextcloud?" 8 78 $encmountpath/Nextcloud 3>&1 1>&2 2>&3)
        else
            nextcloudpath=$(whiptail --title "Nextcloud" --inputbox \
            "Which folder would you like to use for Nextcloud?" 8 78 /etc/sswg/Nextcloud 3>&1 1>&2 2>&3)        
        fi
    else
        if [ -z $encmountpath ]; then #check if encryption is used
            nextcloudpath="$encmountpath/Nextcloud"        
        else
            nextcloudpath="/etc/sswg/Nextcloud"
        fi    
    fi
    mkdir $nextcloudpath
    echo "nextcloudpath=\"$nextcloudpath\"" >> /etc/sswg/config.txt
    mkdir $nextcloudpath
    mkdir $nextcloudpath/data
    chown -R www-data:www-data $nextcloudpath
}
install_nextcloud_depend() {
    packageinstall "apache2 mariadb-server libapache2-mod-php php-gd php-mysql \
    php-curl php-mbstring php-intl php-gmp php-bcmath php-xml php-imagick php-zip"
    whiptail --title "Nextcloud" --msgbox \
    "Nextcloud and its dependencies have been installed." 8 78
}
nextcloud_database_setup() {
    #set up database
    nextclouddbusername=$(whiptail --title "Nextcloud" --inputbox "Nextcloud db new user username:" 8 78 3>&1 1>&2 2>&3)
    nextclouddbpassword=$(whiptail --title "Nextcloud" --passwordbox "Choose new password for $nextclouddbusername:" 8 78 3>&1 1>&2 2>&3)
    rootpasswd=$(whiptail --title "Nextcloud" --passwordbox "Root password to interact with mysql (for raised privileges):" 8 78 3>&1 1>&2 2>&3)
    mysql -uroot -p${rootpasswd} -e "CREATE USER '${nextclouddbusername}'@'localhost' IDENTIFIED BY '${nextclouddbpassword}';"
    mysql -uroot -p${rootpasswd} -e "CREATE DATABASE IF NOT EXISTS nextcloud CHARACTER SET utf8mb4 COLLATE utf8mb4_general_ci;"
    mysql -uroot -p${rootpasswd} -e "GRANT ALL PRIVILEGES ON nextcloud.* TO '${nextclouddbusername}'@'localhost';"
    mysql -uroot -p${rootpasswd} -e "FLUSH PRIVILEGES;"
}
download_nextcloud_tar() {
    #download, copy and permission for nextcloud stack
    whiptail --title "Nextcloud installer" --msgbox \
    "Downloading Nextcloud tar" 8 78
    cd $nextcloudpath
    wget -q https://download.nextcloud.com/server/releases/latest.tar.bz2
    tar -xjvf latest.tar.bz2 >/dev/null
    mv nextcloud /var/www
    chown -R www-data:www-data /var/www/nextcloud
}
ssl_all() {
    if [ -z $DOMAINNAME ]; then
        domainname=$(whiptail --title "OpenVPN" --inputbox \
        "DNS name or ip address to be used: (eg. example.contoso.com)" \
        8 78 3>&1 1>&2 2>&3)
        export DOMAINNAME=$domainname
    fi
    #generate ssl cert
    #install certbot
    if [ which certbot ]; then
        #certbot already installed
    else
        #install certbot
        packageinstall "snapd"
        snap install core &>/dev/null
        snap refresh core &>/dev/null
        snap install --classic certbot &>/dev/null
        ln -s /snap/bin/certbot /usr/bin/certbot
    fi
    #if using port 80/443: sudo certbot --apache and its finished - certbot with letsencrypt only connects to port 80/443 on external ip
    certbot certonly --manual --preferred-challenges dns -d ${domainname} -d www.${domainname}
    #manually add dns txt record
    mkdir $nextcloudpath/certs
    cp /etc/letsencrypt/live/$domainname/fullchain.pem $nextcloudpath/certs/fullchain.pem
    cp /etc/letsencrypt/live/$domainname/privkey.pem $nextcloudpath/certs/privkey.pem
    chown www-data:www-data $nextcloudpath/certs/fullchain.pem
    chown www-data:www-data $nextcloudpath/certs/privkey.pem
}
create_apache_config() {
    cat << EOT >> /etc/apache2/sites-available/nextcloud.conf
    # generated 2023, Mozilla Guideline v5.6, Apache 2.4.41, OpenSSL 1.1.1k, modern configuration
    # https://ssl-config.mozilla.org/#server=apache&version=2.4.41&config=modern&openssl=1.1.1k&guideline=5.6
    #/etc/apache2/sites-available/nextcloud.conf
    SSLProtocol             all -SSLv3 -TLSv1 -TLSv1.1 -TLSv1.2
    SSLHonorCipherOrder     off
    SSLSessionTickets       off
    SSLUseStapling On
    SSLStaplingCache "shmcb:logs/ssl_stapling(32768)"
    <VirtualHost *:80>
        RewriteEngine On
        RewriteCond %{REQUEST_URI} !^/\.well\-known/acme\-challenge/
        RewriteRule ^(.*)$ https://%{HTTP_HOST}$1 [R=301,L]
        
        ServerName cloud.nextcloud.com
        #does the same thing as the rewriterule #Redirect permanent / https://cloud.nextcloud.com/
    </VirtualHost>
    <VirtualHost *:443>
        SSLEngine on
    SSLCertificateFile /path/cert.pem
    SSLCertificateKeyFile /path/private.key
        # enable HTTP/2, if available
        Protocols h2 http/1.1
        
        ServerName cloud.nextcloud.com
        <IfModule mod_headers.c> # HTTP Strict Transport Security (mod_headers is required) (63072000 seconds)
        Header always set Strict-Transport-Security "max-age=63072000; includeSubDomains"
        </IfModule>
        <IfModule mod_dav.c>
            Dav off
        </IfModule>

        Alias /nextcloud "/var/www/nextcloud/"
        <Directory /var/www/nextcloud/>
        Require all granted
        AllowOverride All
        Options FollowSymLinks MultiViews
        Satisfy Any
        </Directory>
    </VirtualHost>
EOT
}
apache_config() {
    #apache configuration
    packageinstall "openssl"
    whiptail --title "Nextcloud" --msgbox "Configuring Apache" 8 78
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
}
install_nextcloud_tar() {
    #install the extracted nextcloud dir
    whiptail --title "Nextcloud" --msgbox \
    "Installing the extracted tarball.\nCreating admin user and finalising install..." \
    8 78

    nextcloudaminuser=$(whiptail --title "Nextcloud" --inputbox \
    "Nextcloud admin creation.\nWhat would you like the admin username to be?" \
    8 78 3>&1 1>&2 2>&3)

    nextcloudaminpassword=$(whiptail --title "Nextcloud" --passwordbox \
    "Nextcloud new admin password for $nextcloudaminuser" \
    8 78 3>&1 1>&2 2>&3)

    cd /var/www/nextcloud/
    #Using the php occ command from the nextcloud dir to finish the install (instead of the webui)
    sudo -u www-data php occ  maintenance:install --database \
    "mysql" --database-name "nextcloud"  --database-user "${nextclouddbusername}" --database-pass \
    "${nextclouddbpassword}" --admin-user "${nextcloudaminuser}" --admin-pass "${nextcloudaminpassword}" --data-dir "$nextcloudpath/data"
    
    whiptail --title "Nextcloud" --msgbox \
    "Nextcloud install done" 8 78
}
fail2ban_setup() {
    #set up fail2ban, according to the nextcloud documentation presets
    whiptail --title "Nextcloud" --msgbox "Setting up fail2ban" 8 78
    packageinstall "fail2ban"
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
}
modsecurity_install() {
    #installing modsec
    packageinstall "libapache2-mod-security2"
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
}


whiptail --title "Nextcloud installer" --msgbox \
"Nextcloud and its dependencies are being installed" 8 78

. /etc/sswg/config.txt
encmountpath=$encmountpath
nextcloud_getfolder
install_nextcloud_depend
nextcloud_database_setup
download_nextcloud_tar
ssl_all
create_apache_config
apache_config
install_nextcloud_tar

#Adding trusted domain names to the nextcloud config array #######################
sed -i \
  "s/*0 => 'localhost',*/0 => 'localhost', 1 => '$domainname', 2 => 'www.$domainname', /" \
  /var/www/nextcloud/config/config.php
sed -i "s/^\s*0*/worked/" /var/www/nextcloud/config/config.php
#hardening security
fail2ban_setup
#########Apache has to be configured to use the .htaccess file
modsecurity_install
#apt-get install snapd
#snap install nextcloud
#for upgrading the database
#sudo -u www-data php occ upgrade