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

if [ $DEMO_MESH != "istio" ]; then \
	echo "This script is for the Istio mesh only" >&2 ;\
	exit 1 ;\
fi

set +e

#@SHOW

# Now, create a Kubernetes Gateway using the "istio" GatewayClass.

bat istio/gateway.yaml
kubectl apply -f istio/gateway.yaml

# Finally, wait for the ingress gateway to be ready.

kubectl wait --for=condition=Programmed gateway/ingress
