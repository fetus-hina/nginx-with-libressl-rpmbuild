NGINX_VERSION := 1.11.6
LIBRESSL_VERSION := 2.5.0
RPM_RELEASE := 2

NGINX_SRPM := nginx-$(NGINX_VERSION)-1.el7.ngx.src.rpm
LIBRESSL_ARCHIVE := libressl-$(LIBRESSL_VERSION).tar.gz

NGINX_SRPM_URL := https://nginx.org/packages/mainline/centos/7/SRPMS/$(NGINX_SRPM)
LIBRESSL_ARCHIVE_URL := http://ftp.openbsd.org/pub/OpenBSD/LibreSSL/$(LIBRESSL_ARCHIVE)

IMAGE_NAME := build-nginx
TARGZ_FILE := built.tar.gz

centos7: IMAGE_NAME := $(IMAGE_NAME)-ce7

.PHONY: all clean dist-clean centos7

all: centos7
centos7: centos7.build

archives/$(NGINX_SRPM):
	curl -sL $(NGINX_SRPM_URL) -o $@

archives/$(LIBRESSL_ARCHIVE):
	curl -sL $(LIBRESSL_ARCHIVE_URL) -o $@

patches/nginx-spec.patch: patches/nginx-spec.patch.in
	cat $< | \
		sed 's%<<LIBRESSL_PATH>>%/home/builder/libressl-$(LIBRESSL_VERSION)%' | \
		sed 's%<<RPM_RELEASE>>%$(RPM_RELEASE)%' > $@

%.build: archives/$(NGINX_SRPM) archives/$(LIBRESSL_ARCHIVE) patches/nginx-spec.patch
	[ -d $@.bak ] && rm -rf $@.bak || :
	[ -d $@ ] && mv $@ $@.bak || :
	docker build -t $(IMAGE_NAME) \
		--build-arg=NGINX_VERSION=$(NGINX_VERSION) \
		--build-arg=NGINX_SRPM=$(NGINX_SRPM) \
		--build-arg=LIBRESSL_VERSION=$(LIBRESSL_VERSION) \
		--build-arg=LIBRESSL_ARCHIVE=$(LIBRESSL_ARCHIVE) \
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
	rm -rf *.build.bak *.build tmp
	docker images | grep -q $(IMAGE_NAME)-ce7 && docker rmi $(IMAGE_NAME)-ce7 || true

dist-clean: clean
	rm -rf archives/*
