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

# First up, we require that the mesh install step already created namespaces
# for us, so check that.

#@immed
DEMOSH_QUIET_FAILURE=true

set -e

if ! kubectl get namespace faces >/dev/null 2>&1; then \
    echo "The faces namespace is missing" >&2 ;\
    exit 1 ;\
fi

set +e

#@SHOW

# Install the v1 Gateway API CRDs manually. This is a weird corner case at the
# moment: Envoy Gateway 0.6.0 doesn't do this for us, but it _does_ require it.
# Sigh.

kubectl apply -f https://github.com/kubernetes-sigs/gateway-api/releases/download/v1.0.0/standard-install.yaml

# OK, go ahead and install Envoy Gateway as our ingress controller. We'll use Helm
# for this.

helm install envoy-gateway \
     -n envoy-gateway-system --create-namespace \
     oci://docker.io/envoyproxy/gateway-helm \
     --version v0.6.0

# After that, we'll wait for Envoy Gateway to be ready.
kubectl rollout status -n envoy-gateway-system deploy

# If we're using Linkerd, we now need to annotate the envoy-gateway-system
# namespace for Linkerd injection. We can't do this earlier because Envoy
# Gateway's boot sequence includes a Job that has to run to completion, and
# the Linkerd sidecar gets in the way of that. KEP-753, supported in Linkerd
# edge-23.11.4, will make this better -- but KEP-753 isn't in Kubernetes by
# default until 1.28, and that's still a touch too new at the moment. Sigh.

#@immed
if [ "$DEMO_MESH" = "linkerd" ]; then \
    echo "Annotating envoy-gateway-system for Linkerd injection" ;\
    kubectl annotate ns envoy-gateway-system linkerd.io/inject=enabled ;\
fi

# Once that's done, install the GatewayClass and Gateway that Envoy Gateway
# needs.

kubectl apply -f envoy-gateway/gatewayclass-and-gateway.yaml

# Finally, wait for the Envoy Gateway proxy to be ready.
kubectl rollout status -n envoy-gateway-system deploy

# Once that's done, install Faces. We'll use Helm for this, too.

helm install faces \
     -n faces \
     oci://ghcr.io/buoyantio/faces-chart \
     --version 1.0.0-alpha.1

# Let's also set

# After that, wait for the Faces application to be ready...
kubectl rollout status -n faces deploy

# ...after which we can install the Faces HTTPRoutes.
kubectl apply -f k8s/01-base
