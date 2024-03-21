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

if [ $DEMO_MESH != "linkerd" ]; then \
     echo "This script is for the Linkerd mesh only" >&2 ;\
     exit 1 ;\
fi

set +e

#@SHOW

# Linkerd doesn't include an ingress controller, so we'll install Envoy
# Gateway using Helm.

helm install envoy-gateway \
     -n envoy-gateway-system --create-namespace \
     oci://docker.io/envoyproxy/gateway-helm \
     --version v1.0.0

# After that, we'll wait for Envoy Gateway to be ready.
kubectl rollout status -n envoy-gateway-system deploy

# Since we're using Linkerd, we now need to annotate the envoy-gateway-system
# namespace for Linkerd injection. We can't do this earlier because Envoy
# Gateway's boot sequence includes a Job that has to run to completion, and
# the Linkerd sidecar gets in the way of that. KEP-753, supported in Linkerd
# edge-23.11.4, will make this better -- but KEP-753 isn't in Kubernetes by
# default until 1.28, and that's still a touch too new at the moment. Sigh.

kubectl annotate ns envoy-gateway-system linkerd.io/inject=enabled

# Once that's done, install the GatewayClass and Gateway that Envoy Gateway
# needs.

bat linkerd/gatewayclass-and-gateway.yaml
kubectl apply -f linkerd/gatewayclass-and-gateway.yaml

# Finally, wait for the Envoy Gateway proxy to be ready.
kubectl rollout status -n envoy-gateway-system deploy
