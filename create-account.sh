#!/bin/bash
docker run --rm \
  -e OVERRIDE_HOSTNAME=mail.local.domain \
  -e MAIL_USER="${1}" \
  -e MAIL_PASS=moo \
  -ti oapass/docker-mailserver:latest \
  /bin/sh -c 'echo "$MAIL_USER|$(doveadm pw -s SHA512-CRYPT -u $MAIL_USER -p $MAIL_PASS)"' >> config/postfix-accounts.cf
 
docker run --rm \
  -e OVERRIDE_HOSTNAME=mail.local.domain \
  -e MAIL_USER="${1}" \
  -e MAIL_PASS=moo \
  -ti oapass/docker-mailserver:latest \
  /bin/sh -c 'useradd $MAIL_USER'
