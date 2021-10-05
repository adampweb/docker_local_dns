#!/bin/bash

function open_directory() {
  DIRECTORY_NAME=$1

  cd "${DIRECTORY_NAME}" || { echo "${DIRECTORY_NAME} directory not exist"; exit 1; }
}

DOMAIN="dev.home"
SITENAME="Dev Home"

function create_ssl_directories() {
  CA_TYPE=$1

  echo -e "\e[93mPrepare the directory...\e[39m"

  case $CA_TYPE in

    root)
      open_directory "/root/ca"

      mkdir certs crl newcerts private
      ;;

    intermediate)
      open_directory "/root/ca/intermediate"

      mkdir certs crl csr newcerts private

      echo 1000 > /root/ca/intermediate/crlnumber
      ;;
  esac

  chmod 700 private

  touch index.txt

  echo 1000 > serial

}

function create_root_ca() {
  echo -e "\e[93mCreate the root pair...\e[39m"

  create_ssl_directories "root"
  # *****************************************************************************

  echo -e "\e[93mCreate the root key\e[39m"

  open_directory "/root/ca"

  openssl genrsa -aes256 -passout pass:"${SSL_PASSWORD}" -out private/ca.key.pem 4096

  chmod 400 private/ca.key.pem
  # *****************************************************************************

  echo -e "\e[93mCreate the root certificate\e[39m"

  open_directory "/root/ca"

  openssl req -config openssl.cnf \
        -key private/ca.key.pem \
        -passin pass:"${SSL_PASSWORD}" \
        -new -x509 -days 7300 -sha256 -extensions v3_ca \
        -subj "/C=HU/ST=Hungary/O=${SSL_ORGANIZATION_NAME}/OU=Root CA/CN=${SSL_ORGANIZATION_NAME} Root CA" \
        -out certs/ca.cert.pem \
        -batch

  chmod 444 certs/ca.cert.pem

  openssl x509 -noout -text -in certs/ca.cert.pem
  # *****************************************************************************
}

function create_intermediate_ca() {
  echo -e "\e[93mCreate the intermediate pair...\e[39m"

  create_ssl_directories "intermediate"
  # *****************************************************************************

  echo -e "\e[93mCreate the intermediate key\e[39m"

  open_directory "/root/ca"

  openssl genrsa -aes256 -passout pass:"${SSL_PASSWORD}" -out intermediate/private/intermediate.key.pem 4096

  chmod 400 intermediate/private/intermediate.key.pem
  # *****************************************************************************

  open_directory "/root/ca"

  echo -e "\e[93mCreate the intermediate Certificate Signing Request (CSR)\e[39m"

  openssl req -config intermediate/openssl.cnf -new -sha256 \
        -key intermediate/private/intermediate.key.pem \
        -passin pass:"${SSL_PASSWORD}" \
        -subj "/C=HU/ST=Hungary/O=${SSL_ORGANIZATION_NAME}/OU=Intermediate CA/CN=${SSL_ORGANIZATION_NAME} Intermediate CA" \
        -out intermediate/csr/intermediate.csr.pem \
        -batch
  # *****************************************************************************

  open_directory "/root/ca"

  echo -e "\e[93mCreate the intermediate certificate\e[39m"

  openssl ca -config openssl.cnf -extensions v3_intermediate_ca \
        -days 3650 -notext -md sha256 \
        -in intermediate/csr/intermediate.csr.pem \
        -passin pass:"${SSL_PASSWORD}" \
        -out intermediate/certs/intermediate.cert.pem \
        -batch

  chmod 444 intermediate/certs/intermediate.cert.pem
  # *****************************************************************************

  echo -e "\e[93mVerify the intermediate certificate\e[39m"

  openssl x509 -noout -text \
        -in intermediate/certs/intermediate.cert.pem

  openssl verify -CAfile certs/ca.cert.pem \
        intermediate/certs/intermediate.cert.pem
  # *****************************************************************************

  echo -e "\e[93mCreate the certificate chain file\e[39m"

  cat intermediate/certs/intermediate.cert.pem certs/ca.cert.pem > intermediate/certs/ca-chain.cert.pem

  chmod 444 intermediate/certs/ca-chain.cert.pem
}

function create_client() {
  echo -e "\e[93mSign server and client certificates\e[39m"

  echo -e "\e[93mCreate a key\e[39m"

  open_directory "/root/ca"

  openssl genrsa -aes256 -passout pass:"${SSL_PASSWORD}" -out intermediate/private/"${DOMAIN}".key.pem 2048

  chmod 400 intermediate/private/"${DOMAIN}".key.pem
  # *****************************************************************************

  sed -i "s+alt_names ]+alt_names ]\nDNS.1 = www.${DOMAIN}\nDNS.2 = ${DOMAIN}\nDNS.3 = *.${DOMAIN}\n+" /root/ca/intermediate/site-openssl.cnf

  echo -e "\e[93mCreate the client Certificate Signing Request (CSR)\e[39m"

  open_directory "/root/ca"

  openssl req -batch -config intermediate/site-openssl.cnf \
        -extensions v3_req -key intermediate/private/"${DOMAIN}".key.pem \
        -passin pass:"${SSL_PASSWORD}" \
        -subj "/C=HU/ST=Hungary/O=${SSL_ORGANIZATION_NAME} ${SITENAME}/OU=${SITENAME}/CN=${DOMAIN}" \
        -new -sha256 -out intermediate/csr/"${DOMAIN}".csr.pem
  # *****************************************************************************

  echo -e "\e[93mVerify CSR file\e[39m"

  openssl req -text -noout -verify -in intermediate/csr/"${DOMAIN}".csr.pem
  # *****************************************************************************

  echo -e "\e[93mCreate a certificate\e[39m"

  open_directory "/root/ca"

  openssl ca -config intermediate/site-openssl.cnf \
        -extensions server_cert -days 9999 -notext -md sha256 \
        -in intermediate/csr/"${DOMAIN}".csr.pem \
        -passin pass:"${SSL_PASSWORD}" \
        -out intermediate/certs/"${DOMAIN}".cert.pem \
        -batch

  chmod 444 intermediate/certs/"${DOMAIN}".cert.pem

  openssl x509 -noout -text \
        -in intermediate/certs/"${DOMAIN}".cert.pem

  openssl verify -CAfile intermediate/certs/ca-chain.cert.pem \
        intermediate/certs/"${DOMAIN}".cert.pem
  # *****************************************************************************

  echo -e "\e[93mDeploy the certificate\e[39m"

  open_directory "/root/ca"

  echo -e "\e[93mRemove passphrase from key\e[39m"
  openssl rsa \
  -in intermediate/private/"${DOMAIN}".key.pem \
  -passin pass:"${SSL_PASSWORD}" \
  -out intermediate/private/"${DOMAIN}".key.pem
  # *****************************************************************************

  echo -e "\e[93mCreate directory for the client certificates and keys...\e[39m"
  mkdir /openssl-certs/"${DOMAIN}"

  chmod 777 /openssl-certs/"${DOMAIN}"

  cat intermediate/certs/"${DOMAIN}".cert.pem intermediate/certs/ca-chain.cert.pem > /openssl-certs/"${DOMAIN}"/ssl-bundle.cert.pem

  cp intermediate/private/"${DOMAIN}".key.pem /openssl-certs/"${DOMAIN}"/"${DOMAIN}".key.pem

  cp certs/ca.cert.pem /openssl-certs/"${DOMAIN}"/ca.cert.pem

  rm -rf /root/ca/intermediate/site-openssl.cnf

  cp /root/ca/intermediate/site-openssl-original.cnf /root/ca/intermediate/site-openssl.cnf
  # *****************************************************************************
}

if [ ! -f /root/ca/certs/ca.cert.pem ] && [ ! -f /root/ca/private/ca.key.pem ] ; then
    create_root_ca
fi

if [ ! -f /root/ca/intermediate/certs/intermediate.cert.pem ] && [ ! -f /root/ca/intermediate/private/intermediate.key.pem ]; then
    create_intermediate_ca
fi

create_client


echo -e "\e[93mSSL functions finished\e[39m"

