# "mainline" or blank
UPSTREAM_REPO :=

NGINX_VERSION := 1.20.1
OPENSSL_VERSION := 1.1.1k
RPM_RELEASE := 1

NGINX_SRPM := nginx-$(NGINX_VERSION)-1.el7.ngx.src.rpm
OPENSSL_ARCHIVE := openssl-$(OPENSSL_VERSION).tar.gz

NGINX_SRPM_URL := https://nginx.org/packages/$(UPSTREAM_REPO)/centos/7/SRPMS/$(NGINX_SRPM)
OPENSSL_ARCHIVE_URL := https://www.openssl.org/source/$(OPENSSL_ARCHIVE)

IMAGE_NAME := build-nginx
TARGZ_FILE := built.tar.gz

PATCH_NAME := nginx-$(NGINX_VERSION)-$(RPM_RELEASE)-with-$(OPENSSL_VERSION).patch

centos8: IMAGE_NAME := $(IMAGE_NAME)-ce8
centos7: IMAGE_NAME := $(IMAGE_NAME)-ce7
centos6: IMAGE_NAME := $(IMAGE_NAME)-ce6

.PHONY: all clean dist-clean centos8 centos7 centos6

all: centos8 centos7 centos6
centos8: centos8.build
centos7: centos7.build
centos6: centos6.build

archives/$(NGINX_SRPM):
	curl -fsL $(NGINX_SRPM_URL) -o $@

archives/$(OPENSSL_ARCHIVE):
	curl -fsL $(OPENSSL_ARCHIVE_URL) -o $@

patches/$(PATCH_NAME): patches/nginx-spec.patch.in
	cat $< | \
		sed -e 's%<<OPENSSL_PATH>>%/home/builder/openssl-$(OPENSSL_VERSION)%' \
			-e 's%<<NGINX_VERSION>>%$(NGINX_VERSION)%' \
			-e 's%<<RPM_RELEASE>>%$(RPM_RELEASE)%' \
		> $@

%.build: archives/$(NGINX_SRPM) archives/$(OPENSSL_ARCHIVE) patches/$(PATCH_NAME)
	[ -d $@.bak ] && rm -rf $@.bak || :
	[ -d $@ ] && mv $@ $@.bak || :
	docker build -t $(IMAGE_NAME) \
		--build-arg=NGINX_VERSION=$(NGINX_VERSION) \
		--build-arg=NGINX_SRPM=$(NGINX_SRPM) \
		--build-arg=OPENSSL_VERSION=$(OPENSSL_VERSION) \
		--build-arg=OPENSSL_ARCHIVE=$(OPENSSL_ARCHIVE) \
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
	docker images | grep -q $(IMAGE_NAME)-ce8 && docker rmi $(IMAGE_NAME)-ce8 || true
	docker images | grep -q $(IMAGE_NAME)-ce7 && docker rmi $(IMAGE_NAME)-ce7 || true
	docker images | grep -q $(IMAGE_NAME)-ce6 && docker rmi $(IMAGE_NAME)-ce6 || true
	docker images | grep -q $(IMAGE_NAME)-ce5 && docker rmi $(IMAGE_NAME)-ce5 || true

dist-clean: clean
	rm -rf archives/*
