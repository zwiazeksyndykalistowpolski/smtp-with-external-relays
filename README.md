Postfix with optional external relays
=====================================

Simple docker image extending [marvambass/versatile-postfix](https://hub.docker.com/r/marvambass/versatile-postfix/).
Based on: https://serverfault.com/questions/660754/mail-sent-from-my-postfix-mail-server-goes-to-gmail-spam

Getting started
---------------

1. Generate SSL keys

```bash
openssl req -new -x509 -extensions v3_ca -keyout ./data/etc/postfix/ssl/cakey.pem -out ./data/etc/postfix/ssl/cacert.pem -days 3650
```

Adding external relay
---------------------

To add a relay just define a list of environment variables.
You can define as many relays as you want, but for each relay you need to fill all the information as on template below.

```bash
RELAY_xxx_ADDRESS=some.thing@gmail.com
RELAY_xxx_PASSWORD=yyy
RELAY_xxx_SMTP_DOMAIN=smtp.gmail.com
RELAY_xxx_SMTP_PORT=587
RELAY_xxx_EMAIL_DOMAIN=gmail.com
```

Example configuration
---------------------

```yaml
version: '2.3'
service:
    smtp:
        image: quay.io/riotkit/smtp:PUT-RELEASE-THERE
        expose:
            - "25"
        volumes:
            - ./data/etc/postfix/ssl/cakey.pem:/etc/postfix/ssl/cakey.pem
            - ./data/etc/postfix/ssl/cacert.pem:/etc/postfix/ssl/cacert.pem
        environment:
            BIFF: no
            APPEND_DOT_MYDOMAIN: no
            SMTPD_TLS_CERT_FILE: /etc/ssl/certs/ssl-cert-snakeoil.pem
            SMTPD_TLS_KEY_FILE: /etc/ssl/private/ssl-cert-snakeoil.key
            SMTPD_USE_TLS: yes
            MYHOSTNAME: localhost
            MYDESTINATION: localhost
            RELAY_HOST: 
            MAILBOX_SIZE_LIMIT: 0
            RECIPIENT_DELIMITER: +
            SASL_AUTH_ENABLE: yes
            TLS_SECURITY_LEVEL: may
            HEADER_SIZE_LIMIT: 4096000
            SMTPD_RECIPIENT_RESTRICTIONS: "permit_mynetworks permit_sasl_authenticated reject_unauth_destination"
            SMTPD_HELO_RESTRICTIONS: "permit_sasl_authenticated, permit_mynetworks, reject_invalid_hostname, reject_unauth_pipelining, reject_non_fqdn_hostname"
            SMTP_SASL_AUTH_ENABLE: yes
            SMTP_SASL_SECURITY_OPTIONS: noanonymous
            DELAY_WARNING_TIME: 4h
            SMTP_USE_TLS: yes
            SMTP_TLS_CA_FILE: /etc/postfix/ssl/cacert.pem
            

            # The relays are optional, they do not have to be defined
            # all mails could be sent just without any relay
            # redirect all recipient=*@gmail.com mails through gmail account
            - RELAY_GMAIL_ADDRESS=some.thing@gmail.com
            - RELAY_GMAIL_PASSWORD=yyy
            - RELAY_GMAIL_SMTP_DOMAIN=smtp.gmail.com
            - RELAY_GMAIL_SMTP_PORT=587
            - RELAY_GMAIL_EMAIL_DOMAIN=gmail.com

            # the same for outlook
            - RELAY_OUTLOOK_ADDRESS=some.thing@your-domain.org
            - RELAY_OUTLOOK_PASSWORD=yyy
            - RELAY_OUTLOOK_SMTP_DOMAIN=smtp.office365.com
            - RELAY_OUTLOOK_SMTP_PORT=587
            - RELAY_OUTLOOK_EMAIL_DOMAIN=your-domain.org
```

Configuration reference
-----------------------

List of all environment variables that could be used.

```yaml

- BIFF # (example value: no)
# With locally submitted mail, append the string ".$mydomain" to addresses that have no ".domain" information. With remotely submitted mail, append the string ".$remote_header_rewrite_domain" instead.
- APPEND_DOT_MYDOMAIN # (example value: no)
# Certificate
- SMTPD_TLS_CERT_FILE # (example value: /etc/ssl/certs/ssl-cert-snakeoil.pem)
# Certificate key
- SMTPD_TLS_KEY_FILE # (example value: /etc/ssl/private/ssl-cert-snakeoil.key)
# Should the SMTPD exposed internally for applications use TLS? Recommended to use.
- SMTPD_USE_TLS # (example value: yes)
# The default is to use the fully-qualified domain name (FQDN) from gethostname()
- MYHOSTNAME # (example value: localhost)
# The list of domains that are delivered via the $local_transport mail delivery transport (defaults to localhost)
- MYDESTINATION # (example value: localhost)
# The next-hop destination of non-local mail; overrides non-local domains in recipient addresses
- RELAY_HOST # (example value: )
# The maximal size of any local(8) individual mailbox or maildir file, or zero (no limit). In fact, this limits the size of any file that is written to upon local delivery, including files written by external commands that are executed by the local(8) delivery agent.
- MAILBOX_SIZE_LIMIT # (example value: 0)
# The set of characters that can separate a user name from its extension (example: user+foo), or a .forward file name from its extension (example: .forward+foo
- RECIPIENT_DELIMITER # (example value: +)
# Enable SASL authentication in the Postfix SMTP client. By default, the Postfix SMTP client uses no authentication (shell client)
- SASL_AUTH_ENABLE # (example value: yes)
# The default SMTP TLS security level for the Postfix SMTP client; when a non-empty value is specified
- TLS_SECURITY_LEVEL # (example value: may)
# The maximal amount of memory in bytes for storing a message header. If a header is larger, the excess is discarded.
- HEADER_SIZE_LIMIT # (example value: 4096000)
# Optional restrictions that the Postfix SMTP server applies in the context of a client RCPT TO command
- SMTPD_RECIPIENT_RESTRICTIONS # (example value: "permit_mynetworks permit_sasl_authenticated reject_unauth_destination")
# Optional restrictions that the Postfix SMTP server applies in the context of a client HELO command
- SMTPD_HELO_RESTRICTIONS # (example value: "permit_sasl_authenticated, permit_mynetworks, reject_invalid_hostname, reject_unauth_pipelining, reject_non_fqdn_hostname")
# Enable SASL authentication in the Postfix SMTP client
- SMTP_SASL_AUTH_ENABLE # (example value: yes)
# Postfix SMTP client SASL security options
- SMTP_SASL_SECURITY_OPTIONS # (example value: noanonymous)
# After sending a "your message is delayed" notification, inform the sender when the delay clears up
- DELAY_WARNING_TIME # (example value: 4h)
# Use TLS in Postfix Client
- SMTP_USE_TLS # (example value: yes)
# Outgoing mailer certificate
- SMTP_TLS_CA_FILE # (example value: /etc/postfix/ssl/cacert.pem)

```

Custom main.cf and master.cf
-----------------------------

If after mounting main.cf as volume you get a lot of fatal errors such as `postconf: fatal: close /etc/postfix/main.cf.tmp: Device or resource busy`
then you can put your eg. `main.cf` at `/templates/etc/postfix/main.cf.j2` - it's contents will be securely copied to the /etc/postfix/main.cf

The same rule apply for the `master.cf`.
