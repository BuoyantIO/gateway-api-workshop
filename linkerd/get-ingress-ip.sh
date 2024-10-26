#!/bin/bash

kubectl \
    get svc -n envoy-gateway-system \
            -l gateway.envoyproxy.io/owning-gateway-name=ingress \
            -ojsonpath='{ .items[0].status.loadBalancer.ingress[0].ip }'
