#!/usr/bin/bash
# -*- mode: shell-script; fill-column: 80; -*-
#
# This Source Code Form is subject to the terms of the Mozilla Public
# License, v. 2.0. If a copy of the MPL was not distributed with this
# file, You can obtain one at http://mozilla.org/MPL/2.0/.
#

#
# Copyright (c) 2015, Joyent, Inc.
# Copyright 2022 MNX Cloud, Inc.
#

export PS4='[\D{%FT%TZ}] ${BASH_SOURCE}:${LINENO}: ${FUNCNAME[0]:+${FUNCNAME[0]}(): }'
set -o xtrace
set -o errexit

PATH=/opt/local/bin:/opt/local/sbin:/usr/bin:/usr/sbin
role=portolan

# Include common utility functions (then run the boilerplate)
source /opt/smartdc/boot/lib/util.sh
CONFIG_AGENT_LOCAL_MANIFESTS_DIRS=/opt/smartdc/$role
sdc_common_setup

/usr/sbin/svccfg import /opt/smartdc/$role/smf/manifests/portolan.xml

# Add build/node/bin and node_modules/.bin to PATH
echo "" >>/root/.profile
echo "export PATH=\$PATH:/opt/smartdc/$role/build/node/bin:/opt/smartdc/$role/node_modules/.bin:/opt/smartdc/$role/bin" >>/root/.profile

# Log rotation.
sdc_log_rotation_add amon-agent /var/svc/log/*amon-agent*.log 1g
sdc_log_rotation_add config-agent /var/svc/log/*config-agent*.log 1g
sdc_log_rotation_add registrar /var/svc/log/*registrar*.log 1g
sdc_log_rotation_add $role /var/svc/log/*$role*.log 1g
sdc_log_rotation_setup_end

# All done, run boilerplate end-of-setup
sdc_setup_complete

exit 0
