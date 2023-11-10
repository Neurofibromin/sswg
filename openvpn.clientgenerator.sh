#! /bin/bash
RED='\033[0;31m'
NC='\033[0m' # No Color
i=0
while [ $i -lt 5 ]; do
  echo ".............................."
  i=$(($i + 1))
done
echo -e ".."${RED}"OpenVPN client generation"$NC"..."
i=0
while [ $i -lt 5 ]; do
  echo ".............................."
  i=$(($i + 1))
done
configdir=config
read encmountpath <$configdir/encmountpath
openvpnpath=$encmountpath/OpenVPN
cd $openvpnpath/EasyRSA-3.1.2
clientname=client$RANDOM
echo -e $RED"Client name:\n (default: ${clientname}) "$NC
read clientname2
if [ -z "$clientname2" ]; then
  echo "${clientname} will be used as client name"
else
  clientname="${clientname2}"
  echo "${clientname} will be used as client name"
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
echo "Client cert found: $CR"
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
echo "<tls-crypt>" >> $FILEEXT
cat $TA >> $FILEEXT
echo "</tls-crypt>" >> $FILEEXT
echo "Done! $FILEEXT Successfully Created."