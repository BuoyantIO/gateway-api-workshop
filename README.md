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

We'll start by installing the service mesh and the Gateway API CRDs and do any
additional setup the ingress controller needs. Next we'll create the namespace
for our Faces demo app and set it up for mesh injection. Finally, we'll
install the Faces demo application and get going!

<!-- @wait -->

First, we'll confirm that we're using the Kubernetes cluster we expect.

```bash
kubectl cluster-info
```

<!-- @wait_clear -->

## Getting the Mesh Installed

OK, off we go! Start by installing the mesh!

```bash
#@immed
$SHELL ${DEMO_MESH}/install.sh
```

<!-- @wait_clear -->
Now create the namespace that we'll use for the Faces demo app and set
it up for mesh sidecar injection.

```sh
kubectl apply -f k8s/namespaces.yaml
#@immed
$SHELL ${DEMO_MESH}/setup-namespace.sh
```

<!-- @wait_clear -->
## Creating the Gateway

OK, the mesh is running now, so let's set up the Gateway API CRDs, then
install our GatewayClass and Gateway.

We install the Gateway API CRDs _after_ the mesh to make certain that the mesh
installation isn't accidentally using Gateway API CRD versions that we don't
want.

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

## Installing Faces

OK! Finally, it's time to install Faces. We'll use Helm for this, too.
Faces is usually installed so that it fails a lot, but since this workshop
is about Gateway API, we'll install it so that it doesn't fail at all --
that's what the two `errorFraction` flags are for.

By default, the Faces app installs a `face` workload, which calls the `smiley`
and `color` workloads. `smiley` returns a grinning face, and `color` returns
blue. We'll also enable the `smiley2` and `color2` workloads, which we'll use
later: `smiley2` returns a heart-eyed smiley, and `color2` returns green.

```bash
helm install faces \
     -n faces \
     oci://ghcr.io/buoyantio/faces-chart \
     --version 1.1.1 \
     --set face.errorFraction=0 \
     --set backend.errorFraction=0 \
     --set smiley2.enabled=true \
     --set smiley2.errorFraction=50 \
     --set color2.enabled=true
```

After that, wait for the Faces application to be ready...

```bash
kubectl rollout status -n faces deploy
```

...and then we should be able to go to Faces GUI in the web browser, at
http://localhost/gui/, and see good things!

<!-- @wait -->

## The Ingress Problem

OK, well, that didn't work. The reason is that we haven't actually told our
Gateway controller how to direct traffic to the GUI. We need to create an
HTTPRoute to do that -- specifically, anything with a path starting with
`/gui` should go to the `faces-gui` service. This gives your web browser a way
to download the GUI code itself.

```bash
bat k8s/01-base/gui-route.yaml
kubectl apply -f k8s/01-base/gui-route.yaml
```

If we try the web browser again, we should now get the GUI! But we'll see all
grimacing faces on purple backgrounds. This is because the GUI, for each cell,
tries to request the `/face/` path, which we haven't routed yet.

To tackle that, we'll route anything with a path starting with `/face` to the
`face` service.

```bash
bat k8s/01-base/face-route.yaml
kubectl apply -f k8s/01-base/face-route.yaml
```

And now, finally, our web browser should show us all grinning faces on blue
backgrounds!

<!-- @wait_clear -->

## Canaries

So far, so good! But what else can we do with Gateway API?

The simplest next step is a canary: randomly assign some traffic to a new
workload. This is the basis of progressive delivery, and it's a great way to
get started with Gateway API.

Let's start by sending 10% of the traffic for the `color` workload to the
`color2` workload instead.

```bash
bat k8s/02-canary/color-canary-10.yaml
```

`color` returns blue and `color2` returns green, so this should be easy to see
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
bat k8s/02-canary/color-replacement.yaml
kubectl apply -f k8s/02-canary/color-replacement.yaml
kubectl rollout status -n faces deploy
kubectl delete -n faces httproute color-canary
```

## Rollback

Note that nothing requires that you always take a canary to completion. If
something goes wrong, you can easily roll back to the previous state. For
example, let's canary `smiley` traffic between `smiley`, with its grinning
faces, and `smiley2` with its heart-eyed faces:

```bash
bat k8s/02-canary/smiley-canary-50.yaml
kubectl apply -f k8s/02-canary/smiley-canary-50.yaml
```

Whoa, that's not working! So let's roll back, the quick way:

```bash
kubectl delete -n faces httproute smiley-canary
```

Now we're right back to the way things were, and we can fix the problem
without it affecting production traffic.

(We'll "fix" this problem with our `smiley2` by setting its error-fraction
variable to zero, since we're going to want to use it shortly.)

```bash
kubectl set env -n faces deploy smiley2 ERROR_FRACTION-
```

## A/B Testing

Another common use case for Gateway API is A/B testing. This is like a canary
in that you're still sending just part of your traffic to a new version of the
workload, but instead of randomly selecting traffic, you're selecting based on
some attribute of the request. We'll do this using the `X-Faces-User` header:

```bash
bat k8s/03-abtest/smiley-ab.yaml
kubectl apply -f k8s/03-abtest/smiley-ab.yaml
```

We can see the effect by using two browsers for this, one that doesn't the
header, and the other which sets `X-Faces-User` to `testuser`. The `testuser`
browser should see heart-eyed smilies, but the other should not.

If we do this, and find that everyone really loves heart-eyed smilies, we can
make sure of that by unconditionally routing all the traffic to `smiley2`:

```bash
bat k8s/03-abtest/smiley2-unconditional.yaml
kubectl apply -f k8s/03-abtest/smiley2-unconditional.yaml
```

Normally, as noted before, you'd clean up the Deployments after this. For the
moment, though, we'll just delete the HTTPRoute (which will switch everyone
back to grinning smilies).

```bash
kubectl delete -n faces httproute smiley-a-b
```

## Timeouts

OK, we've done canaries and A/B testing. Now let's look at timeouts. Every
cell fading away is a request that's taking too long -- we'll add some
timeouts to improve that, starting from the bottom of the call graph.

Note that timeouts are not about protecting the service: they are about
**providing agency to the client** by giving the client a chance to decide
what to do when things take too long. They actually **increase** load on the
workload.

<!-- @wait -->

Unfortunately, timeouts are also the first thing we'll show that, for now, we
have to do slightly differently in the different meshes. This is because
Linkerd hasn't actually incorporated Gateway API 1.0 yet, so where Istio can
use the official Gateway API HTTPRoute with timeouts, Linkerd needs to use its
own policy.linkerd.io HTTPRoute. This will be changing soon!

<!-- @wait -->

We'll start by adding a timeout to the color service. This timeout will give
agency to the face service, as the client of the color service: when a call to
the color service takes too long, the face service will show a pink background
for that cell.

```bash
bat k8s/04-timeouts/color-timeout-${DEMO_MESH}.yaml
kubectl apply -f k8s/04-timeouts/color-timeout-${DEMO_MESH}.yaml
```

We should start seeing some pink cells appearing!

<!-- @wait -->

Let's continue by adding a timeout to the smiley service. The face service
will show a smiley-service timeout as a sleeping face.

```bash
bat k8s/04-timeouts/smiley-timeout-${DEMO_MESH}.yaml
kubectl apply -f k8s/04-timeouts/smiley-timeout-${DEMO_MESH}.yaml
```

<!-- @wait_clear -->

Finally, we'll add a timeout that lets the GUI decide what to do if the face
service itself takes too long. When the GUI sees a timeout talking to the face
service, it will just keep showing the user the old data for awhile. There are
a lot of applications where this makes an enormous amount of sense: if you
can't get updated data, the most recent data may still be valuable for some
time! Eventually, though, the app should really show the user that something
is wrong: in our GUI, repeated timeouts eventually lead to a faded
sleeping-face cell with a pink background.

For the moment, too, the GUI will show a counter of timed-out attempts, to
make it a little more clear what's going on.

<!-- @wait -->

We'll use the Gateway controller to implement this timeout, rather than the
mesh, illustrating that there can be a lot of overlap between these two
components. Also note that since we already have an HTTPRoute for the
`/face/` path, we'll need to add the timeout to that route, rather than
creating a new one.

```bash
diff -u99 --color k8s/{01-base,04-timeouts}/face-route.yaml
kubectl apply -f k8s/04-timeouts/face-route.yaml
```

We should now start seeing counters appear -- and after long enough, we should
see faded cells.

<!-- @wait_clear -->

## Wrapping Up

So that's the Gateway API, with canaries, A/B testing, and timeouts, managing
a Gateway controller and a service mesh!

If you have any questions or feedback, please feel free to reach out to us on
the CNCF Slack, or via email to flynn@buoyant.io or mike.morris@microsoft.com.
Gateway API is evolving, too, so keep an eye out for an updated version of
this workshop in Salt Lake City!
