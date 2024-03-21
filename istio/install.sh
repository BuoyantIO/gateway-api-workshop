#!/usr/bin/env bash
#
# SPDX-FileCopyrightText: 2022 Buoyant Inc.
# SPDX-License-Identifier: Apache-2.0
#
# Copyright 2022 Buoyant Inc.
#
# Licensed under the Apache License, Version 2.0 (the "License"); you may
# not use this file except in compliance with the License.  You may obtain
# a copy of the License at
#
#     http:#www.apache.org/licenses/LICENSE-2.0
#
# Unless required by applicable law or agreed to in writing, software
# distributed under the License is distributed on an "AS IS" BASIS,
# WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
# See the License for the specific language governing permissions and
# limitations under the License.

set -e

if [ "$DEMO_MESH" != "istio" ]; then \
	echo "This script is for the Istio mesh only" >&2 ;\
	exit 1 ;\
fi

#@SHOW

# Start by installing Istio. We'll use the latest stable version.

#@HIDE
if [[ -z ${DEMO_HOOK_OFFLINE} || -n ${DEMO_HOOK_DOWNLOAD_ISTIO} ]]; then \
  #@SHOW ;\
  curl -L https://istio.io/downloadIstio | ISTIO_VERSION=1.20.3 sh - ;\
  #@HIDE ;\
fi

export PATH=$PWD/istio-1.20.3/bin:$PATH

#@SHOW
which istioctl

istioctl version

istioctl x precheck

istioctl install --set profile=minimal -y

# And that's Istio installed!
