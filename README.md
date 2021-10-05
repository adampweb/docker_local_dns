# BIND9 Private DNS Server with Webmin UI

This container provides DNS service for my Docker based intranet.

Subnet IP-range is **172.18.0.0/16**

# Usage
This server user interface available at **172.18.0.0:10000** address. The main domain is **dev.home**
the future projects can be access by subdomains (e.g.: test1.dev.home).

# OpenSSL
For SSL certificates created private root and intermediate CA these are not same as the Webmin 
built-in SSL CA.