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
DEMOSH_NO_BLURB=true
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

OK, so far so good!

<!-- @wait_clear -->

## Installing the Gateway API CRDs

Gateway API is a CRD API: we need the CRDs to be present to use Gateway API.
Additionally, we need to choose between the experimental channel and the
standard channel: for this workshop, we'll use Gateway API v1.1.0
Experimental. (At the moment, Linkerd can't use the v1.2.0 experimental
channel, because it doesn't have GRPCRoute `v1alpha2` any more.)

So let's get v1.1.0 experimental installed first. This repo contains the
YAML for that already, pre-downloaded from

```
https://github.com/kubernetes-sigs/gateway-api/releases/
    download/v1.1.0/experimental-install.yaml
```

so we can just apply it:

```bash
kubectl apply -f gateway-api/experimental-install.yaml
```

Unfortunately, Gateway API v1.1.0 also contains a bug: the `status` stanza of
GRPCRoute `v1alpha2` isn't correctly marked as a subresource. We'll fix that
by applying the GRPCRoute YAML from Gateway API's PR#3412:

```bash
kubectl apply -f gateway-api/gateway.networking.k8s.io_grpcroutes.yaml
```

<!-- @wait_clear -->

## Getting the Mesh Installed

Once we have the CRDs, let's get our service mesh installed!

```bash
#@immed
$SHELL ${DEMO_MESH}/install.sh
```

<!-- @SHOW -->

<!-- @wait_clear -->
## Creating the Gateway

OK, the mesh is running now, so let's install our GatewayClass and Gateway.

```bash
#@immed
$SHELL ${DEMO_MESH}/create-gateway.sh
#@immed
INGRESS_IP=$(bash ${DEMO_MESH}/get-ingress-ip.sh)
#@immed
echo "Ingress is running at $INGRESS_IP"
```

<!-- @wait_clear -->

## Installing Faces

OK! Finally, it's time to install Faces. We'll start by setting up the
namespace that Faces will use: first we create it...

```bash
kubectl create namespace faces
```

...and then we'll set it up for mesh injection.

```bash
#@immed
$SHELL ${DEMO_MESH}/setup-namespace.sh
```

Next up, we use Helm to install the Faces application. The Faces application
works by installing a `face` workload which calls the `smiley` and `color`
workloads. `smiley` returns a grinning face; `color` returns the color blue;
`face` combines these and returns the combination to the GUI.

Faces is usually set up so that it fails a lot, but since this workshop is
about Gateway API, we'll turn that off (mostly), and we'll also install three
versions each of `smiley` and `color` so we can route between them later on.
All of that is in our `faces/values.yaml` file; it's not very interesting to
look at so we won't show it here.

```bash
helm install faces \
     -n faces \
     oci://ghcr.io/buoyantio/faces-chart \
     --version 2.0.0-rc.0 \
     --values faces/values.yaml
```

After that, wait for the Faces application to be ready...

```bash
kubectl rollout status -n faces deploy
```

...and then we should be able to go to Faces GUI in the web browser, at
http://${INGRESS_IP}/gui/, and see good things!

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

Let's start by sending 10% of the traffic for the `smiley` workload to the
`smiley2` workload instead.

```bash
bat k8s/02-canary/smiley-canary-10.yaml
```

`smiley` returns a grinning smiley and `smiley2` returns a heart-eyed smiley,
so this should be easy to see from the moment we apply the resource.

```bash
kubectl apply -f k8s/02-canary/smiley-canary-10.yaml
```

We can change the fraction of traffic being diverted in realtime, simply by
changing the weights in the HTTPRoute:

```bash
diff -u99 --color k8s/02-canary/smiley-canary-{10,50}.yaml
kubectl apply -f k8s/02-canary/smiley-canary-50.yaml
```

We can even use weights to divert all the traffic to the new workload, once
we're happy that things are working, and delete the old workload entirely.

```bash
diff -u99 --color k8s/02-canary/smiley-canary-{50,100}.yaml
kubectl apply -f k8s/02-canary/smiley-canary-100.yaml
kubectl delete -n faces deploy/smiley
```

Operationally, of course, this isn't a great state to leave things in. It's
smarter to go ahead and deploy our new workload as `smiley` and then remove the
nonintuitive routing, so that people don't get confused when they look a week
later after forgetting what was done.

```bash
bat k8s/02-canary/smiley-replacement.yaml
kubectl apply -f k8s/02-canary/smiley-replacement.yaml
kubectl rollout status -n faces deploy
kubectl delete -n faces httproute smiley-canary
```

<!-- @wait_clear -->

## Canaries with gRPC

We can canary gRPC services, too! The Faces demo uses gRPC for the `color`
workload, and we can canary between `color` (blue) and `color2` (green) just
as easily as we did for our smilies:

```bash
bat k8s/02-canary/color-canary-50.yaml
kubectl apply -f k8s/02-canary/color-canary-50.yaml
```

## Dynamic Routing

Gateway API also allows us to make routing decisions based on various
information in the request itself, like the path, headers, or query
parameters. In our previous example, we did a canary based on the Service to
which the request was sent, but Faces also provides a different Path depending
on whether it's making a request for an edge cell or a center cell.

Let's send all the edge cells to `smiley2` instead of `smiley`. First, though,
let's switch our `smiley2` workload back to returning a grinning smiley, so we
can tell the difference.

```bash
kubectl set env -n faces deploy smiley2 SMILEY-
kubectl rollout status -n faces deploy
```

So far, nothing has changed, but now we can set up the new routing:

```bash
bat k8s/02-canary/smiley-edge.yaml
kubectl apply -f k8s/02-canary/smiley-edge.yaml
```

and we'll see that all the edge cells are now grinning smilies, while the
center cells are still heart-eyed smilies.

<!-- @wait_clear -->

## Dynamic Canarying

We can combine this with a canary, of course. Here we'll send 50% of the edge
traffic to `smiley2`, and the other half to `smiley3`, which returns a face
with rolling eyes.

```bash
bat k8s/02-canary/smiley-edge-canary-50.yaml
kubectl apply -f k8s/02-canary/smiley-edge-canary-50.yaml
```

<!-- @wait_clear -->

## Rollback

`smiley3` seems to have a problem -- half the time it's not returning a face
with rolling eyes at all! Instead, it's returning the cursing face, which is
not what it should do. So let's roll back to the previous state -- nothing
requires that you always take a canary to completion.

To roll back, we'll just reapply the previous HTTPRoute, so that we still get
grinning-face smileys for the edge cells.

```bash
bat k8s/02-canary/smiley-edge.yaml
kubectl apply -f k8s/02-canary/smiley-edge.yaml
```

Of course, we could be even more drastic and just delete the HTTPRoute in this
case, which will return the world back to all heart-eyed smilies.

```bash
kubectl delete -n faces httproute smiley-edge
```

Now we're right back to the way things were, and we can fix the problem
without it affecting production traffic.

<!-- @wait_clear -->

## Dynamic Routing with gRPC

We can also do dynamic routing with gRPC services. In the Faces demo, the
`color` workload actually provides two separate gRPC methods: the `Center`
method and the `Edge` method. We can route these to different workloads, just
as we did with the `smiley` service:

```bash
bat k8s/02-canary/color-edge.yaml
kubectl apply -f k8s/02-canary/color-edge.yaml
```

But wait -- we're still seeing green in the center cells. Any guesses as to
why?

<!-- @wait_clear -->

## Conflict Resolution

The reason is that we still have the `color-canary` GRPCRoute in place. In
Gateway API in general, **more** specific routes win over **less** specific
routes, so while the `color-edge` GRPCRoute wins whenever the `Edge` method is
in play, when it's _not_ in play the `color-canary` GRPCRoute still applies!

If we delete `color-canary`, we'll see all blue in the center and all green at
the edge.

```bash
kubectl delete -n faces grpcroute color-canary
```

## Immediate Effect

Note that, in every case, changing the Gateway API resources has an
_immediate_ effect on what's going on in the application: we don't have to
restart things, or wait for a new pod to come up, or anything like that. This
kind of control is one of the huge advantages of this kind of self-service
model.

<!-- @wait -->

Additionally, everything we've been doing with HTTPRoutes and GRPCRoutes is
the kind of thing that should be accessible to the application developer,
without needing to know anything about the underlying infrastructure. This is
the win of persona-based API design: if you do it correctly, the things that
each persona needs to do are easily accessible to them.

<!-- @wait_clear -->



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
