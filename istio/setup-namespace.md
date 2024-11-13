# Configuring your service mesh with Gateway API

This file configures a namespace for the Faces demo application for the
Gateway API service mesh workshop at KubeCon NA 2024 in Salt Lake City,
Utah, USA.

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

For Istio, we need to annotate the `faces` namespace for sidecars to be
injected. (Ambient mode uses a similar mechanism to enroll a namespace into the
mesh.)

```bash
kubectl label namespace faces istio-injection=enabled
# kubectl label namespace faces istio.io/dataplane-mode=ambient
```
