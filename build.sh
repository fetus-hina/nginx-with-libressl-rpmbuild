#!/bin/bash

set -eu

for i in 7 6; do
  rm -rf centos${i}.build
  docker pull centos:$i
  make centos${i}
  find centos${i}.build -type f -name '*.rpm' | xargs ./sign.exp

  rm -f centos${i}.build/RPMS/x86_64/nginx-debuginfo-*.rpm
  cp -f centos${i}.build/RPMS/x86_64/nginx-*.rpm /var/www/sites/fetus.jp/rpm.fetus.jp/public_html/nginx-openssl/el${i}/x86_64/
  createrepo /var/www/sites/fetus.jp/rpm.fetus.jp/public_html/nginx-openssl/el${i}/x86_64/
done

for i in 5; do
  rm -rf centos${i}.build
  docker pull centos:$i
  make centos${i}
  find centos${i}.build -type f -name '*.rpm' | xargs ./sign.sha1.exp

  rm -f centos${i}.build/RPMS/x86_64/nginx-debuginfo-*.rpm
  cp -f centos${i}.build/RPMS/x86_64/nginx-*.rpm /var/www/sites/fetus.jp/rpm.fetus.jp/public_html/nginx-openssl/el${i}/x86_64/
  createrepo -s sha /var/www/sites/fetus.jp/rpm.fetus.jp/public_html/nginx-openssl/el${i}/x86_64/
done
