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

if [ "$DEMO_MESH" != "linkerd" ]; then \
	echo "This script is for the Linkerd mesh only" >&2 ;\
	exit 1 ;\
fi

#@SHOW

# Start by installing Linkerd and Linkerd Viz. We'll use the latest edge
# release for this, and we'll explicitly tell Linkerd _not_ to install
# Gateway API CRDs (that's the "--set enableHttpRoutes=false" flag).

#@HIDE
if [[ -z ${DEMO_HOOK_OFFLINE} || -n ${DEMO_HOOK_DOWNLOAD_LINKERD} ]]; then \
  #@SHOW ;\
curl --proto '=https' --tlsv1.2 -sSfL https://run.linkerd.io/install-edge | LINKERD2_VERSION=edge-24.10.4 sh ;\
  #@HIDE ;\
fi
#@SHOW

linkerd check --pre
linkerd install --crds --set enableHttpRoutes=false | kubectl apply -f -
linkerd install --set enableHttpRoutes=false | kubectl apply -f -
linkerd viz install | kubectl apply -f -
linkerd check

# And that's Linkerd ready to go!
