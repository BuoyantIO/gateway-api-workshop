# Configuring your service mesh with Gateway API

This file installs Istio for the Gateway API service mesh
workshop at KubeCon NA 2024 in Salt Lake City, Utah, USA.

<!--
SPDX-FileCopyrightText: 2022-2024 Buoyant Inc.
SPDX-License-Identifier: Apache-2.0

Things in Markdown comments are safe to ignore when reading this later. When
executing this with [demosh], things after the horizontal rule below (which
is just before a commented `@SHOW` directive) will get displayed.
-->

```bash
if [ "$DEMO_MESH" != "istio" ]; then \
  echo "This script is for the Istio mesh only" >&2 ;\
  exit 1 ;\
fi
```

<!-- @SHOW -->

Start by installing Istio. We'll use the latest stable version.

```bash
#@HIDE
if [[ -z ${DEMO_HOOK_OFFLINE} || -n ${DEMO_HOOK_DOWNLOAD_ISTIO} ]]; then \
  #@SHOW ;\
  curl -L https://istio.io/downloadIstio | ISTIO_VERSION=1.23.3 sh - ;\
  #@HIDE ;\
fi

export PATH=$PWD/istio-1.23.3/bin:$PATH

#@SHOW

which istioctl

istioctl version

istioctl x precheck
```

We'll use the minimal profile to skip installing the default ingress gateway so
we can create our own gateway.

```bash
istioctl install --set profile=minimal -y
```

And that's Istio ready to go!
