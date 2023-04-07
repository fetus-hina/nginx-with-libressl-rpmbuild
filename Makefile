# "mainline" or blank
UPSTREAM_REPO :=

NGINX_VERSION := 1.22.1
LIBRESSL_VERSION := 3.6.2
RPM_RELEASE := 1

NGINX_SRPM := nginx-$(NGINX_VERSION)-1.el7.ngx.src.rpm
NGINX_TGZ := nginx-$(NGINX_VERSION).tar.gz
LIBRESSL_ARCHIVE := libressl-$(LIBRESSL_VERSION).tar.gz

NGINX_SRPM_URL := https://nginx.org/packages/$(UPSTREAM_REPO)/centos/7/SRPMS/$(NGINX_SRPM)
NGINX_TGZ_URL := http://nginx.org/download/$(NGINX_TGZ)
LIBRESSL_ARCHIVE_URL := http://ftp.openbsd.org/pub/OpenBSD/LibreSSL/$(LIBRESSL_ARCHIVE)

IMAGE_NAME := build-nginx
TARGZ_FILE := built.tar.gz

PATCH_NAME := nginx-$(NGINX_VERSION)-$(RPM_RELEASE)-with-$(LIBRESSL_VERSION).patch
SPEC_NAME := nginx-$(NGINX_VERSION)-$(RPM_RELEASE)-with-$(LIBRESSL_VERSION).spec

centos9: IMAGE_NAME := $(IMAGE_NAME)-el9
centos8: IMAGE_NAME := $(IMAGE_NAME)-el8
centos7: IMAGE_NAME := $(IMAGE_NAME)-el7
centos6: IMAGE_NAME := $(IMAGE_NAME)-el6
centos5: IMAGE_NAME := $(IMAGE_NAME)-el5

.PHONY: all clean dist-clean centos7 centos6 centos5

all: centos9 centos8 centos7 centos6 centos5
centos9: centos9.build
centos8: centos8.build
centos7: centos7.build
centos6: centos6.build-old
centos5: centos5.build-old

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

oldsys/SOURCES/$(NGINX_TGZ):
	curl -fsL $(NGINX_TGZ_URL) -o $@

oldsys/SPECS/$(SPEC_NAME): oldsys/SPECS/nginx.spec.in
	cat $< | \
		sed -e 's%<<LIBRESSL_PATH>>%/home/builder/libressl-$(LIBRESSL_VERSION)%' \
			-e 's%<<NGINX_VERSION>>%$(NGINX_VERSION)%' \
			-e 's%<<RPM_RELEASE>>%$(RPM_RELEASE)%' \
		> $@

%.build-old: oldsys/SOURCES/$(NGINX_TGZ) archives/$(LIBRESSL_ARCHIVE) oldsys/SPECS/$(SPEC_NAME)
	[ -d $@.bak ] && rm -rf $@.bak || :
	[ -d $@ ] && mv $@ $@.bak || :
	docker build -t $(IMAGE_NAME) \
		--build-arg=NGINX_VERSION=$(NGINX_VERSION) \
		--build-arg=LIBRESSL_VERSION=$(LIBRESSL_VERSION) \
		--build-arg=LIBRESSL_ARCHIVE=$(LIBRESSL_ARCHIVE) \
		--build-arg=SPEC_NAME=$(SPEC_NAME) \
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
	rm -rf *.build.bak *.build *.build-old tmp patches/*.patch
	docker images | grep -q $(IMAGE_NAME)-el9 && docker rmi $(IMAGE_NAME)-el9 || true
	docker images | grep -q $(IMAGE_NAME)-el8 && docker rmi $(IMAGE_NAME)-el8 || true
	docker images | grep -q $(IMAGE_NAME)-el7 && docker rmi $(IMAGE_NAME)-el7 || true
	docker images | grep -q $(IMAGE_NAME)-el6 && docker rmi $(IMAGE_NAME)-el6 || true
	docker images | grep -q $(IMAGE_NAME)-el5 && docker rmi $(IMAGE_NAME)-el5 || true

dist-clean: clean
	rm -rf archives/*
