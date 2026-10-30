ARG GO_BUILDER=registry.access.redhat.com/ubi10/go-toolset:latest@sha256:be70aa468168f1ecd46e56d5f362e697243bcf9d3a2d98819597e43471a5d0e4
ARG UBI_RUNTIME=registry.access.redhat.com/ubi10/ubi-minimal:latest@sha256:ab67cd02caf8706e34a695a1432ebe965934f6128ec352a6c3f4048b43a4fb5e

FROM $GO_BUILDER AS builder

WORKDIR /go/src/github.com/openshift-pipelines/manual-approval-gate
COPY upstream .
RUN set -e; for f in patches/*.patch; do echo ${f}; [[ -f ${f} ]] || continue; git apply ${f}; done
ENV GODEBUG="http2server=0"
ENV GOEXPERIMENT=strictfipsruntime

RUN CGO_ENABLED=1 \
    go build -ldflags="-X 'knative.dev/pkg/changeset.rev=$(cat /tmp/HEAD)'" -mod=vendor -tags disable_gcp,strictfipsruntime  -v -o /tmp/manual-approval-gate-controller \
    ./cmd/controller

FROM $UBI_RUNTIME
ARG VERSION=nightly

ENV KO_APP=/ko-app \
    KO_DATA_PATH=/kodata

COPY --from=builder /tmp/manual-approval-gate-controller ${KO_APP}/manual-approval-gate-controller

LABEL \
    com.redhat.component="openshift-pipelines-manual-approval-gate-controller-rhel10-container" \
    cpe="cpe:/a:redhat:openshift_pipelines:nightly::el10" \
    description="Red Hat OpenShift Pipelines manual-approval-gate controller" \
    io.k8s.description="Red Hat OpenShift Pipelines manual-approval-gate controller" \
    io.k8s.display-name="Red Hat OpenShift Pipelines manual-approval-gate controller" \
    io.openshift.tags="tekton,openshift,manual-approval-gate,controller" \
    maintainer="pipelines-extcomm@redhat.com" \
    name="openshift-pipelines/pipelines-manual-approval-gate-controller-rhel10" \
    summary="Red Hat OpenShift Pipelines manual-approval-gate controller" \
    version="nightly"

# ubi10/ubi-minimal does not ship shadow-utils, which provides groupadd/useradd
RUN microdnf install -y shadow-utils && \
    groupadd -r -g 65532 nonroot && useradd --no-log-init -r -u 65532 -g nonroot nonroot
USER 65532

ENTRYPOINT ["/ko-app/manual-approval-gate-controller"]
