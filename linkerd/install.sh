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

if [ -z "$DEMO_HOOK_LINKERD" ]; then \
	echo "This script is for the Linkerd mesh only" >&2 ;\
	exit 1 ;\
fi

#@SHOW

# Start by installing Linkerd and Linkerd Viz. We'll use the latest edge
# release for this.

curl --proto '=https' --tlsv1.2 -sSfL https://run.linkerd.io/install-edge | sh

linkerd check --pre
linkerd install --crds | kubectl apply -f -
linkerd install | kubectl apply -f -
linkerd viz install | kubectl apply -f -
linkerd check

# Once that's done, we can set up the namespace for Faces, annotated for
# Linkerd injection. Sadly, we can't do the same for Envoy Gateway, since it
# relies on a Job that will get hung up by the Linkerd sidecar -- KEP-753
# makes this better, but it's not fully supported in Kubernetes prior to 1.28,
# which is still a touch too new at the moment. Sigh.

kubectl annotate namespace faces linkerd.io/inject="enabled"
