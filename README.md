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
DEMO_MESH=linkerd demosh README.md
```

OR

```sh
DEMO_MESH=istio demosh README.md
```

---

For this workshop, you'll need a running, empty, Kubernetes cluster.

If you don't already have a cluster prepared, ensure you have the
[Docker daemon] or compatible alternative running, [k3d] and [`kubectl`]
installed, then run `./create-cluster.sh` in a new terminal to create a
local k3d cluster.

[Docker daemon]: https://docs.docker.com/config/daemon/start/
[`kubectl`]: https://kubernetes.io/docs/tasks/tools/#kubectl
[k3d]: https://k3d.io/

<!-- @SHOW -->
<!-- @clear -->

# Configuring your service mesh with Gateway API

In this workshop, we'll be running the Faces demo application in a Kubernetes
cluster, using a service mesh and an ingress controller that we'll configure
using the Gateway API. Our choices here are

- Linkerd with Envoy Gateway, or
- Istio (with Istio Gateway).

We'll start by creating the namespace for Faces, to allow service-mesh setup
to use it. Then we'll install the service mesh and the Gateway API CRDs, do
any additional setup the ingress controller needs, and finally install the
Faces application itself.

<!-- @wait -->

First, we'll confirm that we're using the Kuberetes cluster we expect.

```bash
kubectl cluster-info
```

<!-- @wait -->

OK, off we go! Start by creating the namespace that we'll use for Faces.

```sh
kubectl apply -f k8s/namespaces.yaml
```

After that, it's time to install the mesh!

```bash
#@immed
$SHELL ${DEMO_MESH}/install.sh
```

<!-- @wait_clear -->

OK, the mesh is running now, so let's install the Gateway API CRDs. We do this
_after_ the mesh to make certain that the mesh installation isn't accidentally
using Gateway API CRDs that we don't want.

```bash
#@HIDE
if [[ -z ${DEMO_HOOK_OFFLINE} || -n ${DEMO_HOOK_DOWNLOAD_GATEWAY_API} ]]; then \
  #@SHOW ;\
  curl -LO https://github.com/kubernetes-sigs/gateway-api/releases/download/v1.0.0/experimental-install.yaml ;\
  #@HIDE ;\
fi
#@SHOW

kubectl apply -f experimental-install.yaml
```

```bash
#@immed
$SHELL ${DEMO_MESH}/create-gateway.sh
```

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

We'll also install our `smiley2` and `color2` workloads. `smiley` returns a
grinning face, while `smiley2` returns a heart-eyed smiley. `color` returns
green, while `color2` returns blue. Neither `smiley2` nor `color2` will be
receiving any traffic... yet.

```bash
kubectl apply -f smiley2.yaml
kubectl apply -f color2.yaml
```

After that, wait for the Faces application to be ready...

```bash
kubectl rollout status -n faces deploy
```

...after which we can install the Faces HTTPRoutes. First up: anything with a
path starting with `/gui` should go to the `faces-gui` service. This gives
your web browser a way to download the GUI code itself.

```bash
bat k8s/01-base/gui-route.yaml
kubectl apply -f k8s/01-base/gui-route.yaml
```

We also route anything with a path starting with `/face` to the `face`
service. This is the path that the GUI uses to make requests for each cell.

```bash
bat k8s/01-base/face-route.yaml
kubectl apply -f k8s/01-base/face-route.yaml
```

OK, we're ready to go! If we open a web browser to http://localhost/gui/, we
should see the Faces GUI, showing all grinning faces on green backgrounds.

<!-- @wait_clear -->

# Canaries

So far, so good! But what else can we do with Gateway API?

The simplest next step is a canary: randomly assign some traffic to a new
workload. This is the basis of progressive delivery, and it's a great way to
get started with Gateway API.

Let's start by sending 10% of the traffic for the `color` workload to the
`color2` workload instead.

```bash
bat k8s/02-canary/color-canary-10.yaml
```

`color` returns green and `color2` returns blue, so this should be easy to see
from the moment we apply the resource.

```bash
kubectl apply -f k8s/02-canary/color-canary-10.yaml
```

We can change the fraction of traffic being diverted in realtime, simply by
changing the weights in the HTTPRoute:

```bash
diff -u99 --color k8s/02-canary/color-canary-{10,50}.yaml
kubectl apply -f k8s/02-canary/color-canary-50.yaml
```

We can even use weights to divert all the traffic to the new workload, once
we're happy that things are working, and delete the old workload entirely.

```bash
diff -u99 --color k8s/02-canary/color-canary-{50,100}.yaml
kubectl apply -f k8s/02-canary/color-canary-100.yaml
kubectl delete -n faces deploy/color
```

Operationally, of course, this isn't a great state to leave things in. It's
smarter to go ahead and deploy our new workload as `color` and then remove the
nonintuitive routing, so that people don't get confused when they look a week
later after forgetting what was done.

```bash
bat color.yaml
kubectl apply -f color.yaml
kubectl rollout status -n faces deploy
kubectl delete -n faces httproute color-canary
```
