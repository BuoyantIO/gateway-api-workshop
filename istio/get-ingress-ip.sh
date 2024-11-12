#!/bin/bash

kubectl \
    get gateway ingress \
        -ojsonpath='{ .status.addresses[0].value }'
