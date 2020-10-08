#!/bin/bash

set -o nounset \
    -o errexit \
    -o verbose \
    -o xtrace

# Generate CA key
openssl req -new -x509 -keyout mstojanovic-ca-1.key -out mstojanovic-ca-1.crt -days 365 -subj '/CN=ca1.yourdomain.com/OU=Dev/O=Company/L=Belgrade/ST=BG/C=SR' -passin pass:"${KAFKA_SSL_PASSWORD}" -passout pass:"${KAFKA_SSL_PASSWORD}"

for i in broker-1 broker-2 broker-3 producer consumer
do
	echo $i
	mkdir ./$i
	# Create keystores
	keytool -genkey -noprompt \
				 -alias $i \
				 -dname "CN=kafka-$i.yourdomain.com OU=Dev, O=Company, L=Belgrade, ST=BG, C=SR" \
				 -keystore ./$i/kafka.$i.keystore.jks \
				 -keyalg RSA \
				 -storepass {{ kafka_ssl_password }} \
				 -keypass {{ kafka_ssl_password }}

	# Create CSR, sign the key and import back into keystore
	keytool -keystore ./$i/kafka.$i.keystore.jks -alias $i -certreq -file $i.csr -storepass "${KAFKA_SSL_PASSWORD}" -keypass "${KAFKA_SSL_PASSWORD}"

	openssl x509 -req -CA mstojanovic-ca-1.crt -CAkey mstojanovic-ca-1.key -in $i.csr -out $i-ca1-signed.crt -days 9999 -CAcreateserial -passin pass:"${KAFKA_SSL_PASSWORD}"

	keytool -keystore ./$i/kafka.$i.keystore.jks -alias CARoot -import -file mstojanovic-ca-1.crt -storepass "${KAFKA_SSL_PASSWORD}" -keypass "${KAFKA_SSL_PASSWORD}"

	keytool -keystore ./$i/kafka.$i.keystore.jks -alias $i -import -file $i-ca1-signed.crt -storepass "${KAFKA_SSL_PASSWORD}" -keypass "${KAFKA_SSL_PASSWORD}"

	# Create truststore and import the CA cert.
	keytool -keystore ./$i/kafka.$i.truststore.jks -alias CARoot -import -file mstojanovic-ca-1.crt -storepass "${KAFKA_SSL_PASSWORD}" -keypass "${KAFKA_SSL_PASSWORD}"

  echo "${KAFKA_SSL_PASSWORD}" > ./$i/${i}_sslkey_creds
  echo "${KAFKA_SSL_PASSWORD}" > ./$i/${i}_keystore_creds
  echo "${KAFKA_SSL_PASSWORD}" > ./$i/${i}_truststore_creds
done
