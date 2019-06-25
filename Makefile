# "mainline" or blank
UPSTREAM_REPO := mainline

NGINX_VERSION := 1.17.1
LIBRESSL_VERSION := 2.9.2
RPM_RELEASE := 1

NGINX_SRPM := nginx-$(NGINX_VERSION)-1.el7.ngx.src.rpm
LIBRESSL_ARCHIVE := libressl-$(LIBRESSL_VERSION).tar.gz

NGINX_SRPM_URL := https://nginx.org/packages/$(UPSTREAM_REPO)/centos/7/SRPMS/$(NGINX_SRPM)
LIBRESSL_ARCHIVE_URL := http://ftp.openbsd.org/pub/OpenBSD/LibreSSL/$(LIBRESSL_ARCHIVE)

IMAGE_NAME := build-nginx
TARGZ_FILE := built.tar.gz

PATCH_NAME := nginx-$(NGINX_VERSION)-$(RPM_RELEASE)-with-$(LIBRESSL_VERSION).patch

centos7: IMAGE_NAME := $(IMAGE_NAME)-ce7
centos6: IMAGE_NAME := $(IMAGE_NAME)-ce6
centos5: IMAGE_NAME := $(IMAGE_NAME)-ce5

.PHONY: all clean dist-clean centos7 centos6 centos5

all: centos7 centos6 centos5
centos7: centos7.build
centos6: centos6.build
centos5: centos5.build

archives/$(NGINX_SRPM):
	curl -fsL $(NGINX_SRPM_URL) -o $@

archives/$(LIBRESSL_ARCHIVE):
	curl -fsL $(LIBRESSL_ARCHIVE_URL) -o $@

patches/$(PATCH_NAME): patches/nginx-spec.patch.in
	cat $< | \
		sed -e 's%<<LIBRESSL_PATH>>%/home/builder/libressl-$(LIBRESSL_VERSION)%' \
			-e 's%<<NGINX_VERSION>>%$(NGINX_VERSION)%' \
			-e 's%<<RPM_RELEASE>>%$(RPM_RELEASE)%' \
		> $@

%.build: archives/$(NGINX_SRPM) archives/$(LIBRESSL_ARCHIVE) patches/$(PATCH_NAME)
	[ -d $@.bak ] && rm -rf $@.bak || :
	[ -d $@ ] && mv $@ $@.bak || :
	docker build -t $(IMAGE_NAME) \
		--build-arg=NGINX_VERSION=$(NGINX_VERSION) \
		--build-arg=NGINX_SRPM=$(NGINX_SRPM) \
		--build-arg=LIBRESSL_VERSION=$(LIBRESSL_VERSION) \
		--build-arg=LIBRESSL_ARCHIVE=$(LIBRESSL_ARCHIVE) \
		--build-arg=PATCH_NAME=$(PATCH_NAME) \
		-f Dockerfile.$* \
		.
	docker run --name $(IMAGE_NAME)-tmp $(IMAGE_NAME)
	mkdir -p tmp
	docker wait $(IMAGE_NAME)-tmp
	docker cp $(IMAGE_NAME)-tmp:/tmp/$(TARGZ_FILE) tmp
	docker rm $(IMAGE_NAME)-tmp
	mkdir $@
	tar -xzf tmp/$(TARGZ_FILE) -C $@
	rm -rf tmp Dockerfile
	docker images | grep -q $(IMAGE_NAME) && docker rmi $(IMAGE_NAME) || true

clean:
	rm -rf *.build.bak *.build tmp patches/*.patch
	docker images | grep -q $(IMAGE_NAME)-ce7 && docker rmi $(IMAGE_NAME)-ce7 || true
	docker images | grep -q $(IMAGE_NAME)-ce6 && docker rmi $(IMAGE_NAME)-ce6 || true
	docker images | grep -q $(IMAGE_NAME)-ce5 && docker rmi $(IMAGE_NAME)-ce5 || true

dist-clean: clean
	rm -rf archives/*
