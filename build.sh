#!/bin/bash

set -eu

for i in 8 7 6; do
  rm -rf centos${i}.build
  docker pull centos:$i
  make centos${i}
  find centos${i}.build -type f -name '*.rpm' | xargs ./sign.exp

  mkdir -p /var/www/sites/fetus.jp/rpm.fetus.jp/public_html/nginx-openssl/el${i}/x86_64/
  rm -f centos${i}.build/RPMS/x86_64/nginx-debuginfo-*.rpm
  cp -f centos${i}.build/RPMS/x86_64/nginx-*.rpm /var/www/sites/fetus.jp/rpm.fetus.jp/public_html/nginx-openssl/el${i}/x86_64/
  createrepo /var/www/sites/fetus.jp/rpm.fetus.jp/public_html/nginx-openssl/el${i}/x86_64/
done
