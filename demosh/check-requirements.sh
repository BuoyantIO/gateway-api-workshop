set -e

check () {
    cmd="$1"
    url="$2"

    if ! command -v "$cmd" >/dev/null 2>&1; then
        echo "Missing: $cmd (see $url)" >&2
        exit 1
    fi
}

check_ns() {
	kubectl get ns "$1" >/dev/null 2>&1
}

check kubectl "https://kubernetes.io/docs/tasks/tools/"
check bat "https://github.com/sharkdp/bat"
check helm "https://helm.sh/docs/intro/quickstart/"
# check yq "https://github.com/mikefarah/yq?tab=readme-ov-file#install"

if [[ -n ${DEMO_HOOK_LINKERD} && -n ${DEMO_HOOK_ISTIO} ]]; then \
	echo "Please set only DEMO_HOOK_LINKERD or DEMO_HOOK_ISTIO, not both." ;\
	exit 1 ;\
elif [[ -z ${DEMO_HOOK_LINKERD} && -z ${DEMO_HOOK_ISTIO} ]]; then \
	echo "Please rerun with DEMO_HOOK_LINKERD=1 or DEMO_HOOK_ISTIO=1" ;\
	exit 1 ;\
elif [[ -n ${DEMO_HOOK_LINKERD} ]]; then \
	check linkerd "https://linkerd.io/2/getting-started/" ;\
elif [[ -n ${DEMO_HOOK_ISTIO} ]]; then \
	check istioctl "https://istio.io/latest/docs/setup/additional-setup/getting-started/" ;\
fi

# We need an _empty_ cluster.

if ! check_ns kube-system; then \
	echo "No cluster found. Please create one." >&2 ;\
	exit 1 ;\
fi

set +e
