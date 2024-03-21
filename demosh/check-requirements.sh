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

if [[ $DEMO_MESH = "linkerd" ]]; then \
	check linkerd "https://linkerd.io/2/getting-started/" ;\
elif [[ $DEMO_MESH = "istio" ]]; then \
	check istioctl "https://istio.io/latest/docs/setup/additional-setup/getting-started/" ;\
else \
	echo "Please rerun with DEMO_MESH=linkerd or DEMO_MESH=istio" >&2 ;\
	exit 1 ;\
fi

# We need an _empty_ cluster.

if ! check_ns kube-system; then \
	echo "No cluster found. Please create one." >&2 ;\
	exit 1 ;\
fi

set +e
