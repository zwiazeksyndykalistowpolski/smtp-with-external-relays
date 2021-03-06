#!/bin/bash

set -e

#
# Original file from https://github.com/MarvAmBass/docker-versatile-postfix released under MIT license
#

function print_help {
cat <<EOF
        Generic Postfix Setup Script
===============================================

to create a new postfix server for your domain
you should use the following commands:

  docker run -p 25:25 -v /maildirs:/var/mail \
         dockerimage/postfix \
         yourdomain.com \
         user1:password \
         user2:password \
         userN:password

this creates a new smtp server which listens
on port 25, stores mail under /mailsdirs
and has serveral user accounts like
user1 with password "password" and a mail
address user1@yourdomain.com
________________________________________________
by MarvAmBass
EOF
}

if [ "-h" == "$1" ] || [ "--help" == "$1" ] || [ -z $1 ] || [ "" == "$1" ]
then
    print_help
    exit 0
fi

echo ">> Setting up postfix for: $1"

# add domain
postconf -e myhostname="$1"
postconf -e mydestination="$1"
echo "$1" > /etc/mailname
echo "Domain $1" >> /etc/opendkim.conf

if [ ${#@} -gt 1 ]
then
  echo " >> Adding users..."

  # all arguments but skip first argumenti
  i=0
  for ARG in "$@"
  do
    if [ $i -gt 0 ] && [ "$ARG" != "${ARG/://}" ]
    then
      USER=`echo "$ARG" | cut -d":" -f1`
      echo "    >> Adding user: $USER"

      # shellcheck disable=SC2210
      adduser -s /bin/bash $USER -D || true

      echo "$ARG" | chpasswd
      if [ ! -d /var/spool/mail/$USER ]
      then
          mkdir -p /var/spool/mail/$USER
      fi
      chown -R $USER:mail /var/spool/mail/$USER
      chmod -R a=rwx /var/spool/mail/$USER
      chmod -R o=- /var/spool/mail/$USER
    fi

    i=`expr $i + 1`
  done
fi

# DKIM
if [[ "${ENABLE_DKIM}" == "true" ]]
then
  echo ">> Enabling DKIM support"
  echo "   Canonicalization $DKIM_CANONICALIZATION" >> /etc/opendkim.conf

  postconf -e milter_default_action="accept"
  postconf -e milter_protocol="2"
  postconf -e smtpd_milters="inet:localhost:8891"
  postconf -e non_smtpd_milters="inet:localhost:8891"

  # Generate a key if there is no one
  if [ ! -f /etc/postfix/dkim/dkim.key ]
  then
    echo ">> No dkim.key found - generate one..."
    opendkim-genkey -s $DKIM_SELECTOR -d $1
    mkdir -p /etc/postfix/dkim/
    mv "/$DKIM_SELECTOR.private" /etc/postfix/dkim/dkim.key
    echo " >> Printing out public dkim key:"
    cat $DKIM_SELECTOR.txt
    mv $DKIM_SELECTOR.txt /etc/postfix/dkim/dkim.public
    echo " >> [!!!] Please add this key to your DNS System, you should also make sure that path /etc/postfix/dkim/ is in a persistent volume"
  fi
  echo " >> Change user and group of /etc/postfix/dkim/dkim.key to opendkim"
  chown -R opendkim:opendkim /etc/postfix/dkim/
  chmod -R o-rwX /etc/postfix/dkim/
  chmod o=- /etc/postfix/dkim/dkim.key
fi

# Configure /etc/opendkim/custom.conf file
cat <<EOF > /etc/opendkim/custom.conf
KeyFile                 /etc/postfix/dkim/dkim.key
Selector                $DKIM_SELECTOR
SOCKET                  inet:8891@localhost
EOF

# add aliases
> /etc/aliases
if [[ "${ALIASES}" != "" ]]
then
  IFS=';' read -ra ADDR <<< "$ALIASES"
  for i in "${ADDR[@]}"; do
    echo "$i" >> /etc/aliases
    echo ">> Adding $i to /etc/aliases"
  done
fi
echo ">> The new /etc/aliases file:"
cat /etc/aliases
newaliases

##
# POSTFIX RAW Config ENVs
##
if env | grep '^POSTFIX_RAW_CONFIG_'
then
  echo -e "\n## POSTFIX_RAW_CONFIG ##\n" >> /etc/postfix/main.cf
  env | grep '^POSTFIX_RAW_CONFIG_' | while read I_CONF
  do
    CONFD_CONF_NAME=$(echo "$I_CONF" | cut -d'=' -f1 | sed 's/POSTFIX_RAW_CONFIG_//g' | tr '[:upper:]' '[:lower:]')
    CONFD_CONF_VALUE=$(echo "$I_CONF" | sed 's/^[^=]*=//g')

    echo "${CONFD_CONF_NAME} = ${CONFD_CONF_VALUE}" >> /etc/postfix/main.cf
  done
fi

# preparing directories
mkdir -p /var/run/saslauthd /run/opendkim
chown root:root /etc/postfix -R

# disable choot, not required in docker container
postconf -F smtp/inet/chroot=n

# starting services
echo " >> Starting supervisor"
supervisord -c /etc/supervisor/supervisord.conf

# print logs
echo " >> Printing the logs"
touch /var/log/mail.log /var/log/mail.err /var/log/mail.warn
chmod a+rw /var/log/mail.*
tail -F /var/log/mail.*
