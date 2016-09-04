# check-tls

A simple OpenSSL wrapper to check server-side TLS capabilities i.e. supported ciphers and 
SSL/TLS versions.

Originally I made the script to find out supported and unsupported TLS protocol 
versions by Apple's APNS servers (`gateway.sandbox.push.apple.com:2195` and
`gateway.push.apple.com:2195`). But the script could be useful to quickly identify TLS
protocol versions and supported ciphers on any other SSL/TLS servers that responds to 
`openssl s_client ...`.

For better results, make sure to use a recent version of `openssl`.

## Quick Usage

### Screencast

[![asciicast](https://asciinema.org/a/517ygqljolm0ef1jh1a6ibbdz.png)](https://asciinema.org/a/517ygqljolm0ef1jh1a6ibbdz)

### Test using /usr/local/bin/openssl

![Screenshot](https://raw.githubusercontent.com/gsbabil/check-tls/master/screenshots/screenshot-1.png)

### Test using /usr/bin/openssl

![Screenshot](https://raw.githubusercontent.com/gsbabil/check-tls/master/screenshots/screenshot-2.png)


## More Example Usage

```
$ check-tls.sh gateway.push.apple.com 2195

[+] using openssl binary at: /usr/bin/openssl
[+] openssl version: OpenSSL 0.9.8zg 14 July 2015
[+] openssl client supports: -ssl2 -ssl3 -tls1 -dtls1
[+] ignoring from check: dtls1

[+] trying '-ssl2' on 'gateway.push.apple.com:2195'
    - connection failed with -ssl2
    - session master-key:
[+] trying '-ssl3' on 'gateway.push.apple.com:2195'
    - connection failed with -ssl3
    - session master-key:
[+] trying '-tls1' on 'gateway.push.apple.com:2195'
    - connection failed with -tls1
    - session master-key:
```

The third argument to the location of OpenSSL binary is optional. But it is
useful to switch between OpenSSL versions available on the system.

For example, at the time of writing OS X's built in OpenSSL version is
`0.9.8zg` which apparently only speaks `SSLv2, SSLv3` and `TLSv1` protocols (no
support for `TLSv1.1` and `TLSv1.2`).

A quick usage is shown below:

```
$ check-tls.sh gateway.push.apple.com 2195 /usr/local/bin/openssl

[+] using openssl binary at: /usr/local/bin/openssl
[+] openssl version: OpenSSL 1.0.2e 3 Dec 2015
[+] openssl client supports: -ssl2 -ssl3 -tls1_2 -tls1_1 -tls1 -dtls1
[+] ignoring from check: dtls1

[+] trying '-ssl2' on 'gateway.push.apple.com:2195'
    - connection failed with -ssl2
    - session master-key:
[+] trying '-ssl3' on 'gateway.push.apple.com:2195'
    - connection failed with -ssl3
    - session master-key:
[+] trying '-tls1_2' on 'gateway.push.apple.com:2195'
    - connection failed with -tls1_2
    - session master-key:
[+] trying '-tls1_1' on 'gateway.push.apple.com:2195'
    - connection failed with -tls1_1
    - session master-key:
[+] trying '-tls1' on 'gateway.push.apple.com:2195'
    - connection succesful with -tls1
    - session master-key: 8F087AFF10895B368D5691127B6C40C65C066418CEB9CE07378FF799F0ED21BCCC6FB21654F917D28888175734EF805B
```
