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

Linkerd doesn't include an ingress controller, so we'll install Envoy
Gateway using Helm.

We'll start by creating the envoy-gateway-system namespace, then annotating
it for Linkerd injection using KEP-753 native sidecars. We need to use
native sidecars because the Envoy Gateway boot sequence includes a Job that
has to run to completion, and the Linkerd sidecar gets in the way of that if
we don't use native sidecars.

(Native sidecars require Kubernetes 1.29 or higher; we're using 1.30 for
this workshop.)

```bash
kubectl create ns envoy-gateway-system
kubectl annotate ns envoy-gateway-system \
    linkerd.io/inject=enabled \
    config.alpha.linkerd.io/proxy-enable-native-sidecar=true
```

Once that's done, we can install Envoy Gateway using Helm!

```bash
helm install envoy-gateway \
     -n envoy-gateway-system \
     oci://docker.io/envoyproxy/gateway-helm \
     --version v1.1.2
```

After that, we'll wait for Envoy Gateway to be ready.

```bash
kubectl rollout status -n envoy-gateway-system deploy
```

OK, Envoy Gateway is running. Install the GatewayClass and Gateway that Envoy
Gateway needs.

```bash
bat linkerd/gatewayclass-and-gateway.yaml
kubectl apply -f linkerd/gatewayclass-and-gateway.yaml
```

Finally, wait for the Envoy Gateway proxy to be ready.

```bash
kubectl rollout status -n envoy-gateway-system deploy
```
