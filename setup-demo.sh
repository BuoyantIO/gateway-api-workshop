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

# Once that's done, install Faces. We'll use Helm for this, too.

helm install faces \
     -n faces \
     oci://ghcr.io/buoyantio/faces-chart \
     --version 1.0.0 \
     --set face.errorFraction=0 \
     --set backend.errorFraction=0

# Let's also set

# After that, wait for the Faces application to be ready...
kubectl rollout status -n faces deploy

# In the demo, at least talk about the GatewayClass and Gateway ...maybe show
# installing these as well? probably makes sense to just talk about it though

# ...after which we can install the Faces HTTPRoutes.
# No -- show this in the demo
# kubectl apply -f k8s/01-base
