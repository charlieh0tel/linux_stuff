#!/bin/bash

set -o errexit
set -o nounset
set -o xtrace

DOMAIN="murgatroid.com"
ADMINADDR="ch@murgatroid.com"

[[ -d /etc/nullmailer ]] || { echo "/etc/nullmailer missing — is nullmailer installed?" >&2; exit 1; }

rm -f /etc/nullmailer/me
echo "$DOMAIN" > /etc/nullmailer/defaultdomain
echo "$DOMAIN" > /etc/nullmailer/defaulthost
echo "$ADMINADDR" > /etc/nullmailer/adminaddr
echo "smtp" > /etc/nullmailer/remotes
chmod 0600 /etc/nullmailer/remotes
 
echo "$DOMAIN" > /etc/mailname
 
cat > /etc/mailutils.conf << EOF
address {
  email-domain ${DOMAIN};
};
EOF

