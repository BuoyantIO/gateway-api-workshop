set -e

check_ns() {
	kubectl get ns "$1" >/dev/null 2>&1
}

# We need an _empty_ cluster.

if ! check_ns kube-system; then \
	echo "No cluster found. Please create one." >&2 ;\
	exit 1 ;\
fi

# Make sure that we have what we need in our $PATH. Makefile-style escapes are
# required here.
missing= ;\

for cmd in bat kubectl; do \
	if ! command -v $cmd >/dev/null 2>&1; then\
		missing="$missing $cmd" ;\
	fi ;\
done ;\

if [ -n "$missing" ]; then \
	echo "Missing commands:$missing" >&2 ;\
	exit 1 ;\
fi

if [[ -n ${DEMO_HOOK_LINKERD} && -n ${DEMO_HOOK_ISTIO} ]]; then \
	echo "Please set only DEMO_HOOK_LINKERD or DEMO_HOOK_ISTIO, not both." ;\
	exit 1 ;\
elif [[ -z ${DEMO_HOOK_LINKERD} && -z ${DEMO_HOOK_ISTIO} ]]; then \
	echo "Please rerun with DEMO_HOOK_LINKERD=1 or DEMO_HOOK_ISTIO=1" ;\
	exit 1 ;\
elif [[ -n ${DEMO_HOOK_LINKERD} ]]; then \
	if ! command -v "linkerd" >/dev/null 2>&1; then \
		missing="$missing $cmd" ;\
		echo "Please install linkerd then try again." >&2 ;\
		exit 1 ;\
	fi ;\
elif [[ -n ${DEMO_HOOK_ISTIO} ]]; then \
	if ! command -v "istioctl" >/dev/null 2>&1; then \
		echo "Please install istioctl then try again." >&2 ;\
		exit 1 ;\
	fi ;\
fi

set +e
