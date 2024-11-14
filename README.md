# Live with Gateway API

This is the documentation - and executable code! - for the Gateway API
service mesh workshop at KubeCon NA 2024 in Salt Lake City, Utah.

<!--
SPDX-FileCopyrightText: 2022-2024 Buoyant Inc.
SPDX-License-Identifier: Apache-2.0

Things in Markdown comments are safe to ignore when reading this later. When
executing this with [demosh], things after the horizontal rule below (which
is just before a commented `@SHOW` directive) will get displayed.
-->

<!-- @SHOW -->
<!-- @HIDE -->
<!-- set -e >
<!-- @import demosh/check-requirements.sh -->
<!--
```bash
BAT_STYLE="grid,numbers"
DEMOSH_NO_BLURB=true
```
-->

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

---
<!-- @SHOW -->
<!-- @clear -->

# Configuring your service mesh with Gateway API

In this workshop, we'll be running the Faces demo application in a Kubernetes
cluster, using a service mesh and an ingress controller that we'll configure
using the Gateway API. Our choices here are

- Linkerd with Envoy Gateway, or
- Istio (with Istio ingress gateway)

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
standard channel: for this workshop, we'll use the experimental channel of
Gateway API v1.1.1. (At the moment, Linkerd can't use the v1.2.0 experimental
channel, because it doesn't have GRPCRoute `v1alpha2` any more.)

So let's get v1.1.1 experimental installed first. This repo contains the
YAML for that already, pre-downloaded from

```text
https://github.com/kubernetes-sigs/gateway-api/releases/\
    download/v1.1.1/experimental-install.yaml
```

so we can just apply it:

```bash
kubectl apply -f gateway-api/experimental-install.yaml
```

<!-- @wait_clear -->

## Getting the Mesh Installed

Once we have the CRDs, let's get our service mesh installed!

```bash
#@immed
$SHELL ${DEMO_MESH}/install.md
```

<!-- @SHOW -->

<!-- @wait_clear -->
## Creating the Gateway

OK, the mesh is running now, so let's install our GatewayClass and Gateway.

```bash
#@immed
$SHELL ${DEMO_MESH}/create-gateway.md
#@immed
INGRESS_IP=$(bash ${DEMO_MESH}/get-ingress-ip.sh)
#@immed
echo "Ingress is running at $INGRESS_IP"
```

<!-- @wait_clear -->

## Installing Faces

OK! It's time to install the Faces demo application. We'll start by setting up
the namespace that Faces will use: first we create it...

```bash
kubectl create namespace faces
```

...and then we'll set it up for mesh enrollment.

```bash
#@immed
$SHELL ${DEMO_MESH}/setup-namespace.md
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
     --version 2.0.0-rc.1 \
     --values faces/values.yaml
```

After that, wait for the Faces application to be ready...

```bash
kubectl rollout status -n faces deploy
```

...and then we should be able to go to Faces GUI in the web browser, at
<http://${INGRESS_IP}/gui/> (or <http://localhost/gui/> for some local cluster setups), and see good things (hopefully)!

<!-- @wait_clear -->

## The Ingress Problem

OK, well, that didn't work. The reason is that we haven't actually told our
Gateway controller how to direct traffic to the GUI. We need to create an
HTTPRoute to do that - specifically, any HTTP request with a path starting with
`/gui` should go to the `faces-gui` service. This gives your web browser a way
to download the GUI code itself.

```bash
bat k8s/01-base/gui-route.yaml
kubectl apply -f k8s/01-base/gui-route.yaml
```

If we try the web browser again, we should now get the GUI! But we'll see all
grimacing faces on purple backgrounds. This is because the GUI, for each cell,
tries to request the `/face/` path, which we haven't added a route for yet.

To tackle that, we'll create another HTTPRoute to direct any request with a
path starting with `/face` to the `face` service.

```bash
bat k8s/01-base/face-route.yaml
kubectl apply -f k8s/01-base/face-route.yaml
```

And now, finally, our web browser should show us all grinning faces on blue
backgrounds, because we've used Gateway API to tell our Gateway controller how
to route traffic from outside the mesh to the Faces application!

<!-- @wait_clear -->

## Mesh Routing with HTTP

Next up: what can Gateway API do in the mesh?

The simplest next step is the moral equivalent of the HTTPRoutes we just
installed to allow ingress: unconditionally route traffic within the mesh.

With ingress traffic, we used a `parentRef` to attach our HTTPRoute to the
Gateway we created. For mesh traffic, we'll use a `parentRef` that points to a
Service to intercept traffic to that Service. For example, here's the simplest
HTTPRoute we can create for traffic to the `smiley` service:

```bash
bat k8s/02-unconditional/smiley-simplest.yaml
```

<!-- @wait -->

We're not going to bother applying this route because it doesn't _do_
anything: since it has no `backendRefs`, it'll just route traffic directed to
the `smiley` service to... the `smiley` service. But if we add a `backendRef`,
we can send the traffic somewhere else. For example, we could send all traffic
meant for the `smiley` Service to `smiley2` instead:

```bash
bat k8s/02-unconditional/smiley-route.yaml
```

The `smiley2` workload returns a heart-eyed smiley instead of a grinning
smiley, so when we apply that route, we'll immediately see all the cells
change to heart-eyed smilies.

```bash
kubectl apply -f k8s/02-unconditional/smiley-route.yaml
```

<!-- @wait_clear -->

## Mesh Routing with gRPC

We can do exactly the same for gRPC, too. In the Faces demo, the `face`
workload uses HTTP to call `smiley`, but gRPC to call `color`. We can route
all the `color` traffic over to `color2` using a simple GRPCRoute:

```bash
bat k8s/02-unconditional/color-route.yaml
```

`color` returns blue, but `color2` returns green, so when we apply this route,
we'll see all the cells change to green.

```bash
kubectl apply -f k8s/02-unconditional/color-route.yaml
```

<!-- @wait_clear -->

## Operational Concerns

In practice, this kind of unconditional routing is usually not a great idea.
For one thing, its all-at-once nature is dangerous: suppose we sent all the
`smiley` traffic over to `smiley2` only to find that `smiley2` was broken? The
only good thing about that situation is that we'd be able to shift back to
`smiley` just as quickly.

<!-- @wait -->

(That's assuming that we noticed that `smiley2` was broken right away, of
course. If we didn't, we'd have a lot of unhappy users before we figured out
what was going on. Worst case, we would already have shut down `smiley`, and
recovery would be that much harder.)

<!-- @wait_clear -->

## Canaries

In the real world, a much smarter move is to randomly assign only a little bit
of incoming traffic to a new workload. If things go well, we can gradually do
more and more traffic until it's all shifted over. This is the _canary
deployment_, which is the basis of _progressive delivery_.

To demonstrate this with Gateway API, we'll first reset Faces by deleting our
unconditional routes:

```bash
kubectl delete -n faces httproute smiley-route
kubectl delete -n faces grpcroute color-route
```

We'll see all the cells go back to grinning smilies and blue backgrounds, and
we can then start our canary demonstration by sending just 10% of the traffic
meant for `smiley` to `smiley2`:

```bash
bat k8s/03-canary/smiley-canary-10.yaml
```

When we apply this, we'll start to see just a few heart-eyed smilies.

```bash
kubectl apply -f k8s/03-canary/smiley-canary-10.yaml
```

We can change the fraction of traffic being diverted in realtime, simply by
changing the weights in the HTTPRoute:

```bash
diff -u99 --color=always k8s/03-canary/smiley-canary-{10,50}.yaml
kubectl apply -f k8s/03-canary/smiley-canary-50.yaml
```

Once we're happy that all is well, that's when we switch _all_ the traffic
over to `smiley2`:

```bash
diff -u99 --color=always k8s/03-canary/smiley-canary-{50,100}.yaml
kubectl apply -f k8s/03-canary/smiley-canary-100.yaml
```

To prove that the `smiley` workload isn't doing anything, we can scale it down
to zero with no effect on what we see.

```bash
kubectl scale -n faces deploy/smiley --replicas=0
```

<!-- @wait_clear -->

## Operational Concerns

It's worth calling out that we're now in a state that is _not_ a good idea,
operationally speaking. To see why, imagine that it's six weeks later,
something is going wrong with smilies, and the on-call engineer is someone who
wasn't at this workshop.

They've been told that the first place to start is the `face` workload's logs,
so they go there:

```bash
kubectl logs -n faces deploy/face -c face | head
```

"Great!" they think. "`face` must be getting smilies from `http://smiley`, so
I can go look at the `smiley` workload to see what's up!"

<!-- @wait -->

This is where things start to go wrong. We who were at this workshop know that
there's an HTTPRoute redirecting all the `smiley` traffic to `smiley2`, but
our on-call engineer doesn't know that. They'll get _very_ confused when they
realize that there aren't even any `smiley` pods to look at.

<!-- @wait -->

Hopefully they'll have been trained about Gateway API, of course! so hopefully
they'll know to look for routes. But the right way to deal with this,
operationally, is to deploy a `smiley` workload that returns heart-eyed
smilies, then remove the nonintuitive routing. That way, anyone looking to see
what's going on won't need to find the HTTPRoute in order to make sense of
everything.

<!-- @wait_clear -->

## Operational Concerns

For this workshop, though, we're not going to do that -- we'll just reset the
world again by scaling `smiley` back up with grinning smilies and deleting our
HTTPRoute:

```bash
kubectl scale -n faces deploy/smiley --replicas=1
kubectl rollout status -n faces deploy
kubectl delete -n faces httproute smiley-canary
```

At this point, we're back to grinning smilies, and we're getting them from the
`smiley` workload as we'd expect.

<!-- @wait_clear -->

## Canaries with gRPC

We can canary gRPC services, too! The Faces demo uses gRPC for the `color`
workload, and we can canary between `color` (blue) and `color2` (green) just
as easily as we did for our smilies:

```bash
bat k8s/03-canary/color-canary-25.yaml
kubectl apply -f k8s/03-canary/color-canary-25.yaml
```

We'll now see some green cells in the GUI, but still mostly blue. Of course,
we can adjust the weights on the fly just like we did with the HTTPRoute:

```bash
diff -u99 --color=always k8s/03-canary/color-canary-{25,50}.yaml
kubectl apply -f k8s/03-canary/color-canary-50.yaml
```

At this point we'll have a 50/50 split between blue and green cells. Let's
leave it there for the moment while we see what else we can do.

<!-- @wait_clear -->

## Dynamic Routing

Gateway API also allows us to make routing decisions based on various
information in the request itself, like the path, headers, or query
parameters. In our previous example, we did a canary based on the Service to
which the request was sent, but Faces also provides a different Path depending
on whether it's making a request for an edge cell or a center cell.

Let's send all the edge cells to `smiley2`, with its heart-eyed smilies. This
should leave the center cells still calling `smiley`, so they should still
show us grinning smilies.

```bash
bat k8s/03-canary/smiley-edge.yaml
kubectl apply -f k8s/03-canary/smiley-edge.yaml
```

There we go: all the edge cells are showing us heart-eyed smilies, while the
center cells are still grinning smilies.

<!-- @wait_clear -->

## Dynamic Canarying

We can combine this with a canary, of course. Here we'll send 50% of the edge
traffic to `smiley3`, which returns rolling-eyes smilies, leaving the other
half going to `smiley2` (heart-eyed smilies).

```bash
bat k8s/03-canary/smiley-edge-canary-50.yaml
kubectl apply -f k8s/03-canary/smiley-edge-canary-50.yaml
```

<!-- @wait_clear -->

## Rollback

`smiley3` seems to have a problem -- half the time it's not returning a face
with rolling eyes at all! Instead, it's returning the cursing face, which is
not what it should do. So let's roll back to the previous state -- nothing
requires that you always take a canary to completion.

To roll back, we'll just reapply the previous HTTPRoute, so that we still get
heart-eyed smileys for the edge cells.

```bash
bat k8s/03-canary/smiley-edge.yaml
kubectl apply -f k8s/03-canary/smiley-edge.yaml
```

Now we're right back to the way things were, and we can fix the problem at our
leisure without the stress of having our production traffic broken while we
work on a fix.

<!-- @wait -->

And, of course, we could be even more drastic and just delete the HTTPRoute
entirely. In this case, that will return the world back to all grinning
smilies.

```bash
kubectl delete -n faces httproute smiley-edge
```

<!-- @wait_clear -->

## Dynamic Routing with gRPC

We can also do dynamic routing with gRPC services. Where the `smiley` workload
uses two separate paths, the `color` workload provides two separate gRPC
methods: the `Center` method and the `Edge` method. We can route these to
different workloads, just as we did with the `smiley` service -- here we'll
send all the edge cells to `color2`, which returns green.

```bash
bat k8s/03-canary/color-edge.yaml
kubectl apply -f k8s/03-canary/color-edge.yaml
```

Now we have all green cells at the edge -- but wait. We're still seeing some
green in the center cells. Any guesses as to why?

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

<!-- @wait_clear -->

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

## A/B Testing

Another common use case for Gateway API is A/B testing: sending just part of
your traffic to a new destination, based on a header or some other attribute
of the request. The classic example here is to base the decision on which user
is logged in, so that's what we'll do... if "logged in" isn't too strong a
term for a demo that lets you pick who you're logged in as with no
authentication at all!

Under the hood, when you enter a username in the Faces GUI, it sets the
`X-Faces-User` header in the requests being sent. This header gets propagated
everywhere in the app, so we can use it for A/B testing. Let's start by doing
an A/B test for the `smiley` service: we'll arrange for the `heart` user to
get heart-eyed smilies, and everyone else to get grinning smilies.

```bash
bat k8s/04-abtest/smiley-ab.yaml
kubectl apply -f k8s/04-abtest/smiley-ab.yaml
```

The Faces GUI allows us to switch the user we're "logged in" as by editing the
username above the cell grid. We can best see the effect of the A/B test by
using two browsers for this, one logged in as `heart` and one logged in as
anything else (or not logged in at all). Since the GUI sends the logged-in
username as the value of the `X-Faces-User` header, the `heart` browser should
see heart-eyed smilies, but the other should see grinning smilies.

If we do this, and find that everyone really loves heart-eyed smilies, we can
make sure of that by unconditionally routing all the traffic to `smiley2`:

```bash
bat k8s/04-abtest/smiley2-unconditional.yaml
kubectl apply -f k8s/04-abtest/smiley2-unconditional.yaml
```

Normally, as noted before, you'd clean up the Deployments after this. For the
moment, though, we'll just delete the HTTPRoute (which will switch everyone
back to grinning smilies).

```bash
kubectl delete -n faces httproute smiley-a-b
```

<!-- @wait_clear -->

## A/B Testing

We can do the same trick with gRPC, too. Let's give all the `heart` users the
dark-blue color from `color3`:

```bash
bat k8s/04-abtest/color-ab.yaml
kubectl apply -f k8s/04-abtest/color-ab.yaml
```

Now we have dark blue cells at the center -- but we're still seeing green at
the edges? Why is that?

<!-- @wait_clear -->

## Conflict Resolution

This is another aspect of the conflict resolution rules. We currently have two
GRPCRoutes in play:

```bash
kubectl get -n faces grpcroute
```

`color-a-b` is doing our A/B test: it specifies matches on the gRPC Service
and a header. `color-edge` is doing our edge/cell routing: it specifies
matches on the gRPC Service and the gRPC method. These are basically
equivalent in terms of specificity, so the _older route wins_ -- and for the
edge cells where `color-edge` matches, `color-edge` is older than `color-a-b`.

Deleting `color-edge` will let us see all dark blue cells.

```bash
kubectl delete -n faces grpcroute color-edge
```

The conflict resolution rules are a critical part of Gateway API, but they're
not always intuitive -- once multiple rules are in play, testing is very
important.

<!-- @wait_clear -->

## A/B Testing

Back to our A/B test, there's nothing preventing us from doing an A/B test of
`smiley` at the same time as `color`:

```bash
kubectl apply -f k8s/04-abtest/smiley-ab.yaml
```

In the real world, running multiple A/B tests simultaneously like this can be
a bit of a mess, but the tooling supports it if you want to!

For now, let's go ahead and shut the A/B tests down by deleting the routes:

```bash
kubectl delete -n faces httproute smiley-a-b
kubectl delete -n faces grpcroute color-a-b
```

Once again, we'll be back to grinning faces on blue backgrounds.

<!-- @wait_clear -->

## Timeouts

OK, we've done canaries and A/B testing. Now let's look at timeouts. Every
cell fading away is a request that's taking too long -- we'll add some
timeouts to improve that, starting from the bottom of the call graph.

Note that timeouts are not about protecting the service: they are about
**providing agency to the client** by giving the client a chance to decide
what to do when things take too long. They actually **increase** load on the
workload.

<!-- @wait -->

Unfortunately, for now, we have to do timeouts slightly differently in the
different meshes. Linkerd currently uses its own `policy.linkerd.io` HTTPRoute
for timeout support. Istio, on the other hand, uses the timeouts field in the
official Gateway API HTTPRoute.

<!-- @wait -->

We'll start by adding a timeout to the `smiley` Service. If the `face`
workload's request to `smiley` times out, the GUI will show this as a sleeping
face.

```bash
bat k8s/05-timeouts/smiley-timeout-${DEMO_MESH}.yaml
kubectl apply -f k8s/05-timeouts/smiley-timeout-${DEMO_MESH}.yaml
```

<!-- @wait_clear -->

## Timeouts

Finally, we'll add a timeout for the GUI's calls to `face` itself. We'll do
this a bit differently: when the GUI sees a timeout talking to the face
service, it will just keep showing the user the old data for awhile. There are
a lot of applications where this makes an enormous amount of sense: if you
can't get updated data, the most recent data may still be valuable for some
time! Eventually, though, the app should really show the user that something
is wrong: in our GUI, repeated timeouts eventually lead to a faded
sleeping-face cell with a pink background.

For the moment, too, the GUI will show a counter of timed-out attempts, to
make it a little more clear what's going on.

<!-- @wait -->

We'll use our Gateway controller to implement this timeout, rather than the
mesh, illustrating that there can be a lot of overlap between these two
components. Also note that we already have an HTTPRoute for the `/face/` path,
so we'll add the timeout to that route, rather than creating a new one.

```bash
diff -u99 --color=always k8s/{01-base,05-timeouts}/face-route.yaml
kubectl apply -f k8s/05-timeouts/face-route.yaml
```

We should now start seeing counters appear -- and after long enough, we should
see faded cells.

<!-- @wait_clear -->

## What About the `Color` Workload?

We can't actually demonstrate a timeout on the `color` workload, because
Gateway API doesn't yet include GRPCRoute timeouts...

...but cross your fingers for them at KubeCon in London!

<!-- @wait_clear -->

## Wrapping Up

So that's the Gateway API, with HTTP and gRPC canaries, A/B testing, and
timeouts, managing a Gateway controller and a service mesh!

If you have any questions or feedback, please feel free to reach out to us on
Kubernetes Slack, or via email to <flynn@buoyant.io> or <mike.morris@microsoft.com>.
Gateway API is evolving, too, so keep an eye out for more at KubeCon in
London!

<!-- @wait -->
