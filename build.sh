#!/bin/bash

set -eu

SCRIPT_DIR=$(cd $(dirname $0); pwd)
pushd $SCRIPT_DIR
  for i in 9 8; do
    rm -rf centos${i}.build
    docker pull rockylinux:$i
    make centos${i}
    find centos${i}.build -type f -name '*.rpm' | xargs rpmsign --resign --key-id=C9F367D2
  
    mkdir -p /var/www/sites/fetus.jp/rpm.fetus.jp/public_html/nginx-openssl/el${i}/x86_64/
    rm -f centos${i}.build/RPMS/x86_64/nginx-debuginfo-*.rpm
    cp -f centos${i}.build/RPMS/x86_64/nginx-*.rpm /var/www/sites/fetus.jp/rpm.fetus.jp/public_html/nginx-openssl/el${i}/x86_64/
    createrepo /var/www/sites/fetus.jp/rpm.fetus.jp/public_html/nginx-openssl/el${i}/x86_64/
  
    rm -f /var/www/sites/fetus.jp/rpm.fetus.jp/public_html/nginx-openssl/el${i}/x86_64/repodata/repomd.xml.asc
    gpg --armor --detach-sign --default-key "C9F367D2" \
      /var/www/sites/fetus.jp/rpm.fetus.jp/public_html/nginx-openssl/el${i}/x86_64/repodata/repomd.xml
  done
  
  for i in 7; do
    rm -rf centos${i}.build
    docker pull centos:$i
    make centos${i}
    find centos${i}.build -type f -name '*.rpm' | xargs rpmsign --resign --key-id=C9F367D2
  
    mkdir -p /var/www/sites/fetus.jp/rpm.fetus.jp/public_html/nginx-openssl/el${i}/x86_64/
    rm -f centos${i}.build/RPMS/x86_64/nginx-debuginfo-*.rpm
    cp -f centos${i}.build/RPMS/x86_64/nginx-*.rpm /var/www/sites/fetus.jp/rpm.fetus.jp/public_html/nginx-openssl/el${i}/x86_64/
    createrepo /var/www/sites/fetus.jp/rpm.fetus.jp/public_html/nginx-openssl/el${i}/x86_64/
  
    rm -f /var/www/sites/fetus.jp/rpm.fetus.jp/public_html/nginx-openssl/el${i}/x86_64/repodata/repomd.xml.asc
    gpg --armor --detach-sign --default-key "C9F367D2" \
      /var/www/sites/fetus.jp/rpm.fetus.jp/public_html/nginx-openssl/el${i}/x86_64/repodata/repomd.xml
  done
popd
