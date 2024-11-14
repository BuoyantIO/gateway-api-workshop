# Configuring your service mesh with Gateway API

This file installs Linkerd and Linkerd Viz for the Gateway API service mesh
workshop at KubeCon NA 2024 in Salt Lake City, Utah, USA.

<!--
SPDX-FileCopyrightText: 2022-2024 Buoyant Inc.
SPDX-License-Identifier: Apache-2.0

Things in Markdown comments are safe to ignore when reading this later. When
executing this with [demosh], things after the horizontal rule below (which
is just before a commented `@SHOW` directive) will get displayed.
-->

```bash
if [ "$DEMO_MESH" != "linkerd" ]; then \
	echo "This script is for the Linkerd mesh only" >&2 ;\
	exit 1 ;\
fi
```

<!-- @SHOW -->

Start by installing Linkerd and Linkerd Viz. We'll use the latest edge
release for this, and we'll explicitly tell Linkerd _not_ to install
Gateway API CRDs (that's those "--set ...=false" flags).

```bash
#@HIDE
if [[ -z ${DEMO_HOOK_OFFLINE} || -n ${DEMO_HOOK_DOWNLOAD_LINKERD} ]]; then \
  #@SHOW ;\
curl --proto '=https' --tlsv1.2 -sSfL https://run.linkerd.io/install-edge | LINKERD2_VERSION=edge-24.10.4 sh ;\
  #@HIDE ;\
fi
#@SHOW

linkerd check --pre
linkerd install --crds \
    --set enableHttpRoutes=false \
    --set enableTcpRoutes=false \
    --set enableTlsRoutes=false \
  | kubectl apply -f -
linkerd install \
    --set enableHttpRoutes=false \
    --set enableTcpRoutes=false \
    --set enableTlsRoutes=false \
  | kubectl apply -f -
# linkerd viz install | kubectl apply -f -
linkerd check
```

And that's Linkerd ready to go!
