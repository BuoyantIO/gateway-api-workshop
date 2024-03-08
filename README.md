# Configuring your service mesh with Gateway API

This is the documentation - and executable code! - for the Gateway API
service mesh workshop at KubeCon EU 2024 in Paris, France.

<!--
Things in Markdown comments are safe to ignore when reading this later. When
executing this with [demosh], things after the horizontal rule below (which
is just before a commented `@SHOW` directive) will get displayed.
-->

<!-- set -e >
<!-- @import demosh/check-requirements.sh -->

```bash
BAT_STYLE="grid,numbers"
```
<!-- @SKIP -->
The easiest way to walk through this workshop is to install [demosh] and
execute this file with an environment variable set to select the service
mesh you wish to use. Start this workshop with either Linkerd or Istio by
running one of the following commands:

[demosh]: https://github.com/BuoyantIO/demosh

```sh
DEMO_HOOK_LINKERD=1 demosh README.md
```

OR

```sh
DEMO_HOOK_ISTIO=1 demosh README.md
```

---
<!-- @SHOW -->
For this workshop, you'll need a running, empty, Kubernetes cluster.

If you don't already have a cluster prepared, ensure you have the
[Docker daemon] or compatible alternative running, [k3d] and [`kubectl`]
installed, then run `./create-cluster.sh` in a new terminal to create a
local k3d cluster.

<!-- @HIDE -->
[Docker daemon]: https://docs.docker.com/config/daemon/start/
[`kubectl`]: https://kubernetes.io/docs/tasks/tools/#kubectl
[k3d]: https://k3d.io/

<!-- @clear -->
<!-- @SHOW -->

Create your cluster if needed, then confirm we have a Kubernetes cluster
ready:

```sh
kubectl cluster-info
```

Now, create the namespace for the Faces demo app.

```sh
kubectl apply -f k8s/namespaces.yaml
```

OK -- let's get the mesh installed!

```bash
#@immed
if [[ -n ${DEMO_HOOK_LINKERD} ]]; then \
    $SHELL setup-linkerd.sh ;\
elif [[ -n ${DEMO_HOOK_ISTIO} ]]; then \
    $SHELL istio/install.sh ;\
fi
```

<!-- @wait_clear -->

OK, the mesh is running now, so let's install the Gateway API CRDs. We do this
_after_ the mesh to make certain that the mesh installation isn't accidentally
using Gateway API CRDs that we don't want.

```bash
kubectl apply -f https://github.com/kubernetes-sigs/gateway-api/releases/download/v1.0.0/experimental-install.yaml
```

<!-- @HIDE -->
Linkerd needs to setup Envoy Gateway here, so if we're using Linkerd, off we go.

```bash
#@immed
if [[ -n ${DEMO_HOOK_LINKERD} ]]; then \
    $SHELL setup-envoy-gateway.sh ;\
elif [[ -n ${DEMO_HOOK_ISTIO} ]]; then \
    $SHELL istio/create-gateway.sh ;\
fi
```
<!-- @SHOW -->

<!-- @wait_clear -->

OK! Finally, it's time to install Faces. We'll use Helm for this, too.
Faces is usually installed so that it fails a lot, but since this workshop
is about Gateway API, we'll install it so that it doesn't fail at all --
that's what the two `--set` flags are for.

```bash
helm install faces \
     -n faces \
     oci://ghcr.io/buoyantio/faces-chart \
     --version 1.0.0 \
     --set face.errorFraction=0 \
     --set backend.errorFraction=0
```

After that, wait for the Faces application to be ready...

```bash
kubectl rollout status -n faces deploy
```

...after which we can install the Faces HTTPRoutes.

```bash
bat k8s/01-base/gui-route.yaml
kubectl apply -f k8s/01-base/gui-route.yaml
bat k8s/01-base/face-route.yaml
kubectl apply -f k8s/01-base/face-route.yaml
```

OK, we're ready to go! If we open a web browser to http://localhost/faces/, we
should see the Faces GUI, showing all grinning faces on green backgrounds.

<!-- @wait_clear -->
