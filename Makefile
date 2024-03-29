#
# This Source Code Form is subject to the terms of the Mozilla Public
# License, v. 2.0. If a copy of the MPL was not distributed with this
# file, You can obtain one at http://mozilla.org/MPL/2.0/.
#

#
# Copyright 2022 Joyent, Inc.
# Copyright 2022 MNX Cloud, Inc.
#

NAME:=portolan


DOC_FILES	 = index.md
EXTRA_DOC_DEPS += deps/restdown-brand-remora/.git
RESTDOWN_FLAGS   = --brand-dir=deps/restdown-brand-remora

JS_FILES	:= $(shell find lib test -name '*.js' | grep -v '/tmp/') \
	bin/portolan
ESLINT_FILES   = $(JS_FILES)
JSSTYLE_FILES	 = $(JS_FILES)
JSSTYLE_FLAGS	 = -f tools/jsstyle.conf
ESLINT_FILES	 = $(JS_FILES)
SMF_MANIFESTS_IN = smf/manifests/portolan.xml.in
CLEAN_FILES += ./node_modules

CTFCONVERT=ctfconvert
CTF2JSON=ctf2json
CTF_TYPES=-t svp_req_t \
	-t svp_vl2_req_t \
	-t svp_vl2_ack_t \
	-t svp_vl3_req_t \
	-t svp_vl3_ack_t \
	-t svp_bulk_req_t \
	-t svp_bulk_ack_t \
	-t svp_log_req_t \
	-t svp_log_vl2_t \
	-t svp_log_vl3_t \
	-t svp_log_ack_t \
	-t svp_lrm_req_t \
	-t svp_lrm_ack_t \
	-t svp_shootdown_t
TAPE=node_modules/.bin/tape

ifeq ($(shell uname -s),SunOS)
	NODE_PREBUILT_VERSION=v6.17.1
	NODE_PREBUILT_TAG=zone64
	NODE_PREBUILT_IMAGE=a7199134-7e94-11ec-be67-db6f482136c2
endif

ENGBLD_USE_BUILDIMAGE	= true
ENGBLD_REQUIRE		:= $(shell git submodule update --init deps/eng)
include ./deps/eng/tools/mk/Makefile.defs
TOP ?= $(error Unable to access eng.git submodule Makefiles.)

BUILD_PLATFORM  = 20210826T002459Z

ifeq ($(shell uname -s),SunOS)
	include ./deps/eng/tools/mk/Makefile.node_prebuilt.defs
	include ./deps/eng/tools/mk/Makefile.agent_prebuilt.defs
else
	NODE := node
	NPM := $(shell which npm)
	NPM_EXEC=$(NPM)
endif
include ./deps/eng/tools/mk/Makefile.smf.defs


VERSION=$(shell json -f $(TOP)/package.json version)
COMMIT=$(shell git describe --all --long  | awk -F'-g' '{print $$NF}')

RELEASE_TARBALL:=$(NAME)-pkg-$(STAMP).tar.gz
RELSTAGEDIR:=/tmp/$(NAME)-$(STAMP)

# our base image is triton-origin-x86_64-21.4.0
BASE_IMAGE_UUID = 502eeef2-8267-489f-b19c-a206906f57ef
BUILDIMAGE_NAME = $(NAME)
BUILDIMAGE_DESC	= Triton Portolan Service
AGENTS		= amon config registrar

#
# Targets
#
.PHONY: all
all: $(SMF_MANIFESTS) build/build.json | $(NPM_EXEC) sdc-scripts
	$(NPM) install --production

build/build.json:
	mkdir -p build
	echo "{\"version\": \"$(VERSION)\", \"commit\": \"$(COMMIT)\", \"stamp\": \"$(STAMP)\"}" | json >$@

sdc-scripts: deps/sdc-scripts/.git

.PHONY: release
release: all
	@echo "Building $(RELEASE_TARBALL)"
	# boot
	mkdir -p $(RELSTAGEDIR)/root/opt/smartdc/boot
	cp -R $(TOP)/deps/sdc-scripts/* $(RELSTAGEDIR)/root/opt/smartdc/boot/
	cp -R $(TOP)/boot/* $(RELSTAGEDIR)/root/opt/smartdc/boot/
	# portolan
	mkdir -p $(RELSTAGEDIR)/root/opt/smartdc/$(NAME)/build
	cp -r \
		$(TOP)/package.json \
		$(TOP)/bin \
		$(TOP)/etc \
		$(TOP)/lib \
		$(TOP)/node_modules \
		$(TOP)/server.js \
		$(TOP)/smf \
		$(TOP)/test \
		$(TOP)/sapi_manifests \
		$(RELSTAGEDIR)/root/opt/smartdc/$(NAME)
	cp build/build.json $(RELSTAGEDIR)/root/opt/smartdc/$(NAME)/etc/
	cp -r \
		$(TOP)/build/node \
		$(RELSTAGEDIR)/root/opt/smartdc/$(NAME)/build
	# Remove the sample config.json so we never pick it up in prod
	rm $(RELSTAGEDIR)/root/opt/smartdc/$(NAME)/etc/config.json
	# Trim node
	rm -rf \
		$(RELSTAGEDIR)/root/opt/smartdc/$(NAME)/build/node/bin/npm \
		$(RELSTAGEDIR)/root/opt/smartdc/$(NAME)/build/node/lib/node_modules \
		$(RELSTAGEDIR)/root/opt/smartdc/$(NAME)/build/node/include \
		$(RELSTAGEDIR)/root/opt/smartdc/$(NAME)/build/node/share
	# Trim node_modules to what's required for production, not dev
	# (this is death of a 1000 cuts, try for some easy wins). e.g.,
	# find $(RELSTAGEDIR)/root/opt/smartdc/$(NAME)/node_modules -name test | xargs -n1 rm -rf
	# find $(RELSTAGEDIR)/root/opt/smartdc/$(NAME)/node_modules -name tests | xargs -n1 rm -rf
	# Tar
	(cd $(RELSTAGEDIR) && $(TAR) -I pigz -cf $(TOP)/$(RELEASE_TARBALL) root)
	@rm -rf $(RELSTAGEDIR)

.PHONY: publish
publish: release
	mkdir -p $(ENGBLD_BITS_DIR)/$(NAME)
	cp $(TOP)/$(RELEASE_TARBALL) $(ENGBLD_BITS_DIR)/$(NAME)/$(RELEASE_TARBALL)

src/types: src/types.c src/libvarpd_svp_prot.h
	$(CC) -g src/types.c -o src/types
	$(CTFCONVERT) -l svp src/types

etc/svp-types.json: src/types
	$(CTF2JSON) -f src/types $(CTF_TYPES) > $@

.PHONY: test
test: $(TAPE)
	@(for F in test/unit/*.test.js; do \
		echo "# $$F" ;\
		$(TAPE) $$F ;\
		[[ $$? == "0" ]] || exit 1; \
	done)

$(TAPE): | $(NPM_EXEC)
	$(NPM) install


include ./deps/eng/tools/mk/Makefile.deps
ifeq ($(shell uname -s),SunOS)
	include ./deps/eng/tools/mk/Makefile.node_prebuilt.targ
	include ./deps/eng/tools/mk/Makefile.agent_prebuilt.targ
endif
include ./deps/eng/tools/mk/Makefile.smf.targ
include ./deps/eng/tools/mk/Makefile.targ
