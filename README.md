# docker-mailserver
Provides SMTP and IMAP mail services for PASS integration tests.

## PASS README

The PASS `docker-mailserver` repository is forked from [docker-mailserver](https://github.com/tomav/docker-mailserver).  It provides SMTP and IMAP mail services, used by other components of PASS in integration tests.

## Running `docker-mailserver`

`docker-mailserver` has a number of environment variables that dictate behavior, and they're documented below.  Here are the variables that are used in [Notification Services](https://github.com/OA-PASS/notification-services/blob/master/notification-integration/pom.xml):

|Environment Variable  |Description
|----------------------|---
|`DMS_DEBUG`           |Set to `1` to see debug logs on the docker console
|`DOMAINNAME`          |The domain name that will receive mail.  I set it to `local.domain`
|`ENABLE_SPAMASSASSIN` |Set to `1` to enable SA.  I disable it because sometimes reverse DNS lookups slow things down, and SA isn't needed for integration.
|`HOSTNAME`            |The hostname that the container should use.  I set it to `mail`
|`ONE_DIR`             |Set to `1` to collapse all of the data to be persisted in a single directory on a docker volume.
|`OVERRIDE_HOSTNAME`   |I found I had to set this for the MDP configuration to `mail.local.domain` (i.e. `HOSTNAME` concatenated with `DOMAINNAME`)
|`PERMIT_DOCKER`       |Set to `network` to allow all hosts on the Docker network to connect
|`SMTP_ONLY`           |Set to `1` to only run SMTP (e.g. and not IMAP or POP3)
|`TLS_LEVEL`           |Set to `intermediate` so most IMAP clients can connect using SSL or TLS

> Out of the box, the above environment variables work.  Attempting to use a `DOMAINNAME`, `HOSTNAME`, or `OVERRIDE_HOSTNAME` that differs from from `mail.local.domain` won't work.


The following ports are exposed, and must be published if you want to use them externally.  Normally I publish them all (`docker run -P` flag).

|Exposed Ports |Description
|--------------|---
|25            |Traditional SMTP
|110           |POP3
|143           |IMAP
|465           |SMTPS (IANA)
|587           |ESMTP Mail Submission
|993           |IMAPS
|995           |POP3S
|4190          |Sieve Filter Management


## Example Docker command line usage

`docker run -P -e HOSTNAME=mail -e DOMAINNAME=local.domain -e OVERRIDE_HOSTNAME=mail.local.domain -e PERMIT_DOCKER=network -e ONE_DIR=1 -e TLS_LEVEL=intermediate -e ENABLE_SPAMASSASSIN=0 oapass/docker-mailserver:latest`

## Example Maven Docker Plugin usage

```xml
<plugin>
    <groupId>io.fabric8</groupId>
    <artifactId>docker-maven-plugin</artifactId>
    <configuration>
        <images>
            <image>
                <alias>mail</alias>
                <name>${docker.tvial.docker-mailserver.version}</name>
                <run>
                    <wait>
                        <time>${mail.waitms}</time>
                    </wait>
                    <skip>${mail.skip}</skip>
                    <hostname>mail</hostname>
                    <domainname>local.domain</domainname>
                    <ports>
                        <port>${mail.smtp.port}:25</port>
                        <port>${mail.imap.port}:143</port>
                        <port>${mail.imaps.port}:993</port>
                        <port>${mail.msp.tls.port}:587</port>
                    </ports>
                    <volumes>
                        <bind>
                            <volume>maildata:/var/mail</volume>
                            <volume>mailstate:/var/mail-state</volume>
                        </bind>
                    </volumes>
                    <env>
                        <HOSTNAME>mail</HOSTNAME>
                        <DOMAINNAME>local.domain</DOMAINNAME>
                        <DMS_DEBUG>0</DMS_DEBUG>
                        <ONE_DIR>1</ONE_DIR>
                        <SMTP_ONLY>0</SMTP_ONLY>
                        <PERMIT_DOCKER>network</PERMIT_DOCKER>
                        <OVERRIDE_HOSTNAME>mail.local.domain</OVERRIDE_HOSTNAME>
                        <TLS_LEVEL>intermediate</TLS_LEVEL>
                        <ENABLE_SPAMASSASSIN>0</ENABLE_SPAMASSASSIN>
                    </env>
                </run>
            </image>
        </images>
    </configuration>
    <executions>
        <execution>
            <id>start-docker-its</id>
            <phase>pre-integration-test</phase>
            <goals>
                <goal>start</goal>
            </goals>
        </execution>
        <execution>
            <id>stop-docker-its</id>
            <phase>post-integration-test</phase>
            <goals>
                <goal>stop</goal>
            </goals>
        </execution>
    </executions>
</plugin>
```

## Configuring an IMAP client

Once the `docker-mailserver` is running with its ports published, you ought to be able to connect to it using IMAPS (port 993).  

> IIRC, plain text IMAP will not allow you to login.

- The IP address of the server is `localhost` or the IP address of your active `docker-machine`.  
- Use the IMAPS protocol over port `993` (or the Docker-published equivalent port).
    - Some clients have a "Use SSL" checkbox or equivalent- go ahead and check that box
- Use `<user>@mail.localdomain` as the user name (information on adding a user is below)

## Sending email

Email can only be sent to existing `<user>@mail.localdomain` accounts.  `docker-mailserver` is not set up to relay email to outside domains.

- The IP address of the SMTP server is `localhost` or the IP address of your active `docker-machine`.
- I use port `25` but you may also have success with the Mail Submission Port (MSP) `587`
- No username or password, or encryption, is necessary with port `25`
    - "Use SSL" ought to be unchecked
    - "Allow unencrypted authentication" should be checked

## Adding and configuring email accounts

Edit `Dockerfile`, and add a `useradd` command to create a Unix account.

Then, run `create-account.sh <account>`, found in the base directory of this repository.  It will start the docker mailserver, and execute `doveadm pw` on the running container to add the account.

For example: `./create-account.sh gary` will create a user named `gary`, and that will enable `gary@mail.local.domain` to receive email, and login using IMAP to retrieve the email.

Finally, build a new image with the new accounts: `docker build -t oapass/docker-mailserver .`

## Original README


A fullstack but simple mail server (smtp, imap, antispam, antivirus...).
Only configuration files, no SQL database. Keep it simple and versioned.
Easy to deploy and upgrade.

Includes:

- postfix with smtp or ldap auth
- dovecot for sasl, imap (and optional pop3) with ssl support, with ldap auth
- saslauthd with ldap auth
- [amavis](https://www.amavis.org/)
- [spamassasin](http://spamassassin.apache.org/) supporting custom rules
- [clamav](https://www.clamav.net/) with automatic updates
- opendkim
- opendmarc
- [fail2ban](https://www.fail2ban.org/wiki/index.php/Main_Page)
- [fetchmail](http://www.fetchmail.info/fetchmail-man.html)
- [postscreen](http://www.postfix.org/POSTSCREEN_README.html)
- [postgrey](https://postgrey.schweikert.ch/)
- basic [sieve support](https://github.com/tomav/docker-mailserver/wiki/Configure-Sieve-filters) using dovecot
- [LetsEncrypt](https://letsencrypt.org/) and self-signed certificates
- [setup script](https://github.com/tomav/docker-mailserver/wiki/Setup-docker-mailserver-using-the-script-setup.sh) to easily configure and maintain your mailserver
- persistent data and state (but think about backups!)
- [integration tests](https://travis-ci.org/tomav/docker-mailserver)
- [automated builds on docker hub](https://hub.docker.com/r/tvial/docker-mailserver/)

Why I created this image: [Simple mail server with Docker](http://tvi.al/simple-mail-server-with-docker/)

Before you open an issue, please have a look this `README`, the [Wiki](https://github.com/tomav/docker-mailserver/wiki/) and Postfix/Dovecot documentation.

## Requirements

Recommended:
- 1 CPU
- 1GB RAM

Minimum:
- 1 CPU
- 512MB RAM

**Note:** You'll need to deactivate some services like ClamAV to be able to run on a host with 512MB of RAM.

## Usage

#### Get latest image

    docker pull tvial/docker-mailserver:latest

#### Get the tools

Download the docker-compose.yml, the .env and the setup.sh files:

    curl -o setup.sh https://raw.githubusercontent.com/tomav/docker-mailserver/master/setup.sh; chmod a+x ./setup.sh

    curl -o docker-compose.yml https://raw.githubusercontent.com/tomav/docker-mailserver/master/docker-compose.yml.dist

    curl -o .env https://raw.githubusercontent.com/tomav/docker-mailserver/master/.env.dist

#### Create a docker-compose environment

- Edit the `.env` to your liking. Adapt this file with your FQDN.
- Install [docker-compose](https://docs.docker.com/compose/) in the version `1.6` or higher.

#### Create your mail accounts

    ./setup.sh email add <user@domain> [<password>]

#### Generate DKIM keys

    ./setup.sh config dkim

Now the keys are generated, you can configure your DNS server by just pasting the content of `config/opendkim/keys/domain.tld/mail.txt` in your `domain.tld.hosts` zone.

#### Start the container

    docker-compose up -d mail

You're done!

And don't forget to have a look at the remaining functions of the `setup.sh` script

#### SPF/Forwarding Problems

If you got any problems with SPF and/or forwarding mails, give [SRS](https://github.com/roehling/postsrsd/blob/master/README.md) a try. You enable SRS by setting `ENABLE_SRS=1`. See the variable description for further information.

#### For informational purposes:

Your config folder will be mounted in `/tmp/docker-mailserver/`. To understand how things work on boot, please have a look at [start-mailserver.sh](https://github.com/tomav/docker-mailserver/blob/master/target/start-mailserver.sh)

`restart: always` ensures that the mail server container (and ELK container when using the mail server together with ELK stack) is automatically restarted by Docker in cases like a Docker service or host restart or container exit.

#### Exposed ports
* 25 receiving email from other mailservers
* 465 SSL Client email submission
* 587 TLS Client email submission
* 143 StartTLS IMAP client
* 993 TLS/SSL IMAP client
* 110 POP3 client
* 995 TLS/SSL POP3 client

`Note: Port 25 is only for receiving email from other mailservers and not for submitting email. You need to use port 465 or 587 for this.`

##### Examples with just the relevant environmental variables:

```yaml
version: '2'

services:
  mail:
    image: tvial/docker-mailserver:latest
    hostname: mail
    domainname: domain.com
    container_name: mail
    ports:
    - "25:25"
    - "143:143"
    - "587:587"
    - "993:993"
    volumes:
    - maildata:/var/mail
    - mailstate:/var/mail-state
    - ./config/:/tmp/docker-mailserver/
    environment:
    - ENABLE_SPAMASSASSIN=1
    - ENABLE_CLAMAV=1
    - ENABLE_FAIL2BAN=1
    - ENABLE_POSTGREY=1
    - ONE_DIR=1
    - DMS_DEBUG=0
    cap_add:
    - NET_ADMIN
    - SYS_PTRACE

volumes:
  maildata:
    driver: local
  mailstate:
    driver: local
```

__for ldap setup__:

```yaml
version: '2'

services:
  mail:
    image: tvial/docker-mailserver:latest
    hostname: mail
    domainname: domain.com
    container_name: mail
    ports:
      - "25:25"
      - "143:143"
      - "587:587"
      - "993:993"
    volumes:
      - maildata:/var/mail
      - mailstate:/var/mail-state
      - ./config/:/tmp/docker-mailserver/
    environment:
      - ENABLE_SPAMASSASSIN=1
      - ENABLE_CLAMAV=1
      - ENABLE_FAIL2BAN=1
      - ENABLE_POSTGREY=1
      - ONE_DIR=1
      - DMS_DEBUG=0
      - ENABLE_LDAP=1
      - LDAP_SERVER_HOST=ldap # your ldap container/IP/ServerName
      - LDAP_SEARCH_BASE=ou=people,dc=localhost,dc=localdomain
      - LDAP_BIND_DN=cn=admin,dc=localhost,dc=localdomain
      - LDAP_BIND_PW=admin
      - LDAP_QUERY_FILTER_USER="(&(mail=%s)(mailEnabled=TRUE))"
      - LDAP_QUERY_FILTER_GROUP="(&(mailGroupMember=%s)(mailEnabled=TRUE))"
      - LDAP_QUERY_FILTER_ALIAS="(&(mailAlias=%s)(mailEnabled=TRUE))"
      - DOVECOT_PASS_FILTER="(&(objectClass=PostfixBookMailAccount)(uniqueIdentifier=%n))"
      - DOVECOT_USER_FILTER="(&(objectClass=PostfixBookMailAccount)(uniqueIdentifier=%n))"
      - ENABLE_SASLAUTHD=1
      - SASLAUTHD_MECHANISMS=ldap
      - SASLAUTHD_LDAP_SERVER=ldap
      - SASLAUTHD_LDAP_BIND_DN=cn=admin,dc=localhost,dc=localdomain
      - SASLAUTHD_LDAP_PASSWORD=admin
      - SASLAUTHD_LDAP_SEARCH_BASE=ou=people,dc=localhost,dc=localdomain
      - POSTMASTER_ADDRESS=postmaster@localhost.localdomain
    cap_add:
      - NET_ADMIN
      - SYS_PTRACE

volumes:
  maildata:
    driver: local
  mailstate:
    driver: local
```

# Environment variables

Please check [how the container starts](https://github.com/tomav/docker-mailserver/blob/master/target/start-mailserver.sh) to understand what's expected. Also if an option doesn't work as documented here, check if you are running the latest image!

Value in **bold** is the default value.

## General

##### DMS_DEBUG

  - **0** => Debug disabled
  - 1 => Enables debug on startup

##### ENABLE_CLAMAV

  - **0** => Clamav is disabled
  - 1 => Clamav is enabled

##### ONE_DIR

  - **0** => state in default directories
  - 1 => consolidate all states into a single directory (`/var/mail-state`) to allow persistence using docker volumes

##### ENABLE_POP3

  - **empty** => POP3 service disabled
  - 1 => Enables POP3 service

##### ENABLE_FAIL2BAN

  - **0** => fail2ban service disabled
  - 1 => Enables fail2ban service

If you enable Fail2Ban, don't forget to add the following lines to your `docker-compose.yml`:

    cap_add:
      - NET_ADMIN

Otherwise, `iptables` won't be able to ban IPs.

##### SMTP_ONLY

  - **empty** => all daemons start
  - 1 => only launch postfix smtp

##### SSL_TYPE

  - **empty** => SSL disabled
  - letsencrypt => Enables Let's Encrypt certificates
  - custom => Enables custom certificates
  - manual => Let's you manually specify locations of your SSL certificates for non-standard cases
  - self-signed => Enables self-signed certificates

Please read [the SSL page in the wiki](https://github.com/tomav/docker-mailserver/wiki/Configure-SSL) for more information.

##### TLS_LEVEL

  - **empty** => modern
  - modern => Enables TLSv1.2 and modern ciphers only. (default)
  - intermediate => Enables TLSv1, TLSv1.1 and TLSv1.2 and broad compatibility ciphers.
  - old => NOT implemented. If you really need it, then customize the TLS ciphers overriding postfix and dovecot settings [ wiki](https://github.com/tomav/docker-mailserver/wiki/

##### SPOOF_PROTECTION
Configures the handling of creating mails with forged sender addresses.
  - **empty** => Mail address spoofing allowed. Any logged in user may create email messages with a forged sender address. See also [Wikipedia](https://en.wikipedia.org/wiki/Email_spoofing)(not recommended, but default for backwards compatibility reasons)
  - 1 => (recommended) Mail spoofing denied. Each user may only send with his own or his alias addresses. Addresses with [extension delimiters](http://www.postfix.org/postconf.5.html#recipient_delimiter) are not able to send messages.

##### ENABLE_SRS
Enables the Sender Rewriting Scheme. SRS is needed if your mail server acts as forwarder. See [postsrsd](https://github.com/roehling/postsrsd/blob/master/README.md#sender-rewriting-scheme-crash-course) for further explanation.
  - **0** => Disabled
  - 1 => Enabled

##### PERMIT_DOCKER

Set different options for mynetworks option (can be overwrite in postfix-main.cf)
  - **empty** => localhost only
  - host => Add docker host (ipv4 only)
  - network => Add all docker containers (ipv4 only)

##### VIRUSMAILS_DELETE_DELAY

Set how many days a virusmail will stay on the server before being deleted
  - **empty** => 7 days


##### ENABLE_POSTFIX_VIRTUAL_TRANSPORT

This Option is activating the Usage of POSTFIX_DAGENT to specify a ltmp client different from default dovecot socket.

- **empty** => disabled
- 1 => enabled

##### POSTFIX_DAGENT

Enabled by ENABLE_POSTFIX_VIRTUAL_TRANSPORT. Specify the final delivery of postfix

- **empty**: fail
- `lmtp:unix:private/dovecot-lmtp` (use socket)
- `lmtps:inet:<host>:<port>` (secure lmtp with starttls, take a look at https://sys4.de/en/blog/2014/11/17/sicheres-lmtp-mit-starttls-in-dovecot/)
- `lmtp:<kopano-host>:2003` (use kopano as mailstore)
- etc.

##### ENABLE_MANAGESIEVE

  - **empty** => Managesieve service disabled
  - 1 => Enables Managesieve on port 4190

##### OVERRIDE_HOSTNAME

  - **empty** => uses the `hostname` command to get the mail server's canonical hostname
  - => Specify a fully-qualified domainname to serve mail for.  This is used for many of the config features so if you can't set your hostname (e.g. you're in a container platform that doesn't let you) specify it in this environment variable.

##### POSTMASTER_ADDRESS

  - **empty** => postmaster@domain.com
  - => Specify the postmaster address


##### POSTSCREEN_ACTION

  - **enforce** => Allow other tests to complete. Reject attempts to deliver mail with a 550 SMTP reply, and log the helo/sender/recipient information. Repeat this test the next time the client connects.
  - drop => Drop the connection immediately with a 521 SMTP reply. Repeat this test the next time the client connects.
  - ignore => Ignore the failure of this test. Allow other tests to complete. Repeat this test the next time the client connects. This option is useful for testing and collecting statistics without blocking mail.


##### REPORT_RECIPIENT

  Enables a report being sent (created by pflogsumm) on a regular basis.
  - **0** => Report emails are disabled
  - 1 => Using POSTMASTER_ADDRESS as the recipient
  - => Specify the recipient address

##### REPORT_SENDER

  Change the sending address for mail report
  - **empty** => mailserver-report@hostname
  - => Specify the report sender (From) address


##### REPORT_INTERVAL

  changes the interval in which a report is being sent.
  - **daily** => Send a daily report
  - weekly => Send a report every week
  - monthly => Send a report every month

Note: This Variable actually controls logrotate inside the container and rotates the log depending on this setting. The main log output is still available in its entirety via `docker logs mail` (Or your respective container name). If you want to control logrotation for the docker generated logfile see: [Docker Logging Drivers](https://docs.docker.com/config/containers/logging/configure/)

## Spamassassin

##### ENABLE_SPAMASSASSIN

  - **0** => Spamassassin is disabled
  - 1 => Spamassassin is enabled

##### SA_TAG

  - **2.0** => add spam info headers if at, or above that level

Note: this spamassassin setting needs `ENABLE_SPAMASSASSIN=1`

##### SA_TAG2

  - **6.31** => add 'spam detected' headers at that level

Note: this spamassassin setting needs `ENABLE_SPAMASSASSIN=1`

##### SA_KILL

  - **6.31** => triggers spam evasive actions

Note: this spamassassin setting needs `ENABLE_SPAMASSASSIN=1`

##### SA_SPAM_SUBJECT

  - **\*\*\*SPAM\*\*\*** => add tag to subject if spam detected

Note: this spamassassin setting needs `ENABLE_SPAMASSASSIN=1`

## Fetchmail

##### ENABLE_FETCHMAIL
  - **0** => `fetchmail` disabled
  - 1 => `fetchmail` enabled

##### FETCHMAIL_POLL
  - **300** => `fetchmail` The number of seconds for the interval

## LDAP

##### ENABLE_LDAP

  - **empty** => LDAP authentification is disabled
  - 1 => LDAP authentification is enabled
  - NOTE:
    - A second container for the ldap service is necessary (e.g. [docker-openldap](https://github.com/osixia/docker-openldap))
    - For preparing the ldap server to use in combination with this continer [this](http://acidx.net/wordpress/2014/06/installing-a-mailserver-with-postfix-dovecot-sasl-ldap-roundcube/) article may be helpful

##### LDAP_START_TLS

  - **empty** => no
  - yes => LDAP over TLS enabled for Postfix

##### LDAP_SERVER_HOST

  - **empty** => mail.domain.com
  - => Specify the dns-name/ip-address where the ldap-server
  - NOTE: If you going to use the mailserver in combination with docker-compose you can set the service name here

##### LDAP_SEARCH_BASE

  - **empty** => ou=people,dc=domain,dc=com
  - => e.g. LDAP_SEARCH_BASE=dc=mydomain,dc=local

##### LDAP_BIND_DN

  - **empty** => cn=admin,dc=domain,dc=com
  - => take a look at examples of SASL_LDAP_BIND_DN

##### LDAP_BIND_PW

  - **empty** => admin
  - => Specify the password to bind against ldap

##### LDAP_QUERY_FILTER_USER

  - e.g. `"(&(mail=%s)(mailEnabled=TRUE))"`
  - => Specify how ldap should be asked for users

##### LDAP_QUERY_FILTER_GROUP

  - e.g. `"(&(mailGroupMember=%s)(mailEnabled=TRUE))"`
  - => Specify how ldap should be asked for groups

##### LDAP_QUERY_FILTER_ALIAS

  - e.g. `"(&(mailAlias=%s)(mailEnabled=TRUE))"`
  - => Specify how ldap should be asked for aliases

##### DOVECOT_TLS

  - **empty** => no
  - yes => LDAP over TLS enabled for Dovecot

## Dovecot

##### DOVECOT_USER_FILTER

  - e.g. `"(&(objectClass=PostfixBookMailAccount)(uniqueIdentifier=%n))"`

##### DOVECOT_PASS_FILTER

  - e.g. `"(&(objectClass=PostfixBookMailAccount)(uniqueIdentifier=%n))"`

## Postgrey

##### ENABLE_POSTGREY

  - **0** => `postgrey` is disabled
  - 1 => `postgrey` is enabled

##### POSTGREY_DELAY

  - **300** => greylist for N seconds

Note: This postgrey setting needs `ENABLE_POSTGREY=1`

##### POSTGREY_MAX_AGE

  - **35** => delete entries older than N days since the last time that they have been seen

Note: This postgrey setting needs `ENABLE_POSTGREY=1`

##### POSTGREY_TEXT

  - **Delayed by postgrey** => response when a mail is greylisted

Note: This postgrey setting needs `ENABLE_POSTGREY=1`

## SASL Auth

##### ENABLE_SASLAUTHD

  - **0** => `saslauthd` is disabled
  - 1 => `saslauthd` is enabled

##### SASLAUTHD_MECHANISMS

  - empty => pam
  - `ldap` => authenticate against ldap server
  - `shadow` => authenticate against local user db
  - `mysql` => authenticate against mysql db
  - `rimap` => authenticate against imap server
  - NOTE: can be a list of mechanisms like pam ldap shadow

##### SASLAUTHD_MECH_OPTIONS

  - empty => None
  - e.g. with SASLAUTHD_MECHANISMS rimap you need to specify the ip-address/servername of the imap server  ==> xxx.xxx.xxx.xxx

##### SASLAUTHD_LDAP_SERVER

  - empty => localhost

##### SASLAUTHD_LDAP_SSL

  - empty or 0 => `ldap://` will be used
  - 1 => `ldaps://` will be used

##### SASLAUTHD_LDAP_BIND_DN

  - empty => anonymous bind
  - specify an object with priviliges to search the directory tree
  - e.g. active directory: SASLAUTHD_LDAP_BIND_DN=cn=Administrator,cn=Users,dc=mydomain,dc=net
  - e.g. openldap: SASLAUTHD_LDAP_BIND_DN=cn=admin,dc=mydomain,dc=net

##### SASLAUTHD_LDAP_PASSWORD

  - empty => anonymous bind

##### SASLAUTHD_LDAP_SEARCH_BASE

  - empty => Reverting to SASLAUTHD_MECHANISMS pam
  - specify the search base

##### SASLAUTHD_LDAP_FILTER

  - empty => default filter `(&(uniqueIdentifier=%u)(mailEnabled=TRUE))`
  - e.g. for active directory: `(&(sAMAccountName=%U)(objectClass=person))`
  - e.g. for openldap: `(&(uid=%U)(objectClass=person))`

##### SASL_PASSWD

  - **empty** => No sasl_passwd will be created
  - string => `/etc/postfix/sasl_passwd` will be created with the string as password

## SRS (Sender Rewriting Scheme)

##### SRS_EXCLUDE_DOMAINS

  - **empty** => Envelope sender will be rewritten for all domains
  - provide comma seperated list of domains to exclude from rewriting

##### SRS_SECRET

  - **empty** => generated when the container is started for the first time
  - provide a secret to use in base64
  - you may specify multiple keys, comma separated. the first one is used for signing and the remaining will be used for verification. this is how you rotate and expire keys
  - if you have a cluster/swarm make sure the same keys are on all nodes
  - example command to generate a key: `dd if=/dev/urandom bs=24 count=1 2>/dev/null | base64`

##### SRS_DOMAINNAME

  - **empty** => Derived from OVERRIDE_HOSTNAME, DOMAINNAME, or the container's hostname
  - Set this if auto-detection fails, isn't what you want, or you wish to have a separate container handle DSNs

## Multi-domain Relay Hosts

#### RELAY_HOST

  - **empty** => don't configure relay host
  - default host to relay mail through

#### RELAY_PORT

  - **empty** => 25
  - default port to relay mail through

#### RELAY_USER

  - **empty** => no default
  - default relay username (if no specific entry exists in postfix-sasl-password.cf)

#### RELAY_PASSWORD

  - **empty** => no default
  - password for default relay user
