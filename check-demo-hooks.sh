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

if [[ -n ${DEMO_HOOK_LINKERD} && -n ${DEMO_HOOK_ISTIO} ]]; then
	echo "Please set only DEMO_HOOK_LINKERD or DEMO_HOOK_ISTIO, not both."
	exit 1
elif [[ -z ${DEMO_HOOK_LINKERD} && -z ${DEMO_HOOK_ISTIO} ]]; then
	echo "Please rerun with DEMO_HOOK_LINKERD=1 or DEMO_HOOK_ISTIO=1"
	exit 1
fi

set +e
