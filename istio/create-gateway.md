# Configuring your service mesh with Gateway API

This file creates an Istio ingress gateway for the Gateway API service mesh
workshop at KubeCon NA 2024 in Salt Lake City, Utah, USA.

<!--
SPDX-FileCopyrightText: 2022-2024 Buoyant Inc.
SPDX-License-Identifier: Apache-2.0

Things in Markdown comments are safe to ignore when reading this later. When
executing this with [demosh], things after the horizontal rule below (which
is just before a commented `@SHOW` directive) will get displayed.
-->

```bash
if [ $DEMO_MESH != "istio" ]; then \
 echo "This script is for the Istio mesh only" >&2 ;\
 exit 1 ;\
fi
```

<!-- @SHOW -->

We'll create a Kubernetes Gateway using the "istio" GatewayClass.

```bash
bat istio/gateway.yaml
kubectl apply -f istio/gateway.yaml
```

Finally, wait for the ingress gateway to be ready.

```bash
kubectl wait --for=condition=Programmed gateway/ingress
```
