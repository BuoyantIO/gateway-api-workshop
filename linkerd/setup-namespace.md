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

For Linkerd, we need to annotate the `faces` namespace to get it to be
injected.

```bash
kubectl annotate namespace faces linkerd.io/inject=enabled
```
