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

if [ -z "$DEMO_HOOK_ISTIO" ]; then \
	echo "This script is for the Istio mesh only" >&2 ;\
	exit 1 ;\
fi

#@SHOW

# Start by installing Istio. We'll use the latest stable version.

curl -L https://istio.io/downloadIstio | ISTIO_VERSION=1.20.3 sh -

export PATH=$PWD/istio-1.20.3/bin:$PATH
istioctl x precheck
istioctl install --set profile=minimal -y

# Once that's done, we can set up the namespace for Faces, annotated for
# Istio injection.

kubectl label namespace faces istio-injection=enabled

