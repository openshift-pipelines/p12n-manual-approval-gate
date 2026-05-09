ARG GO_BUILDER=registry.access.redhat.com/ubi9/go-toolset:1.25
ARG RUNTIME=registry.access.redhat.com/ubi9/ubi-minimal:latest@sha256:b9b10f42d7eba7ad4a6d5ef26b7d34fdc892b2ffe59b8d0372ec884008569eb6

FROM $GO_BUILDER AS builder

WORKDIR /go/src/github.com/openshift-pipelines/manual-approval-gate
COPY upstream .
RUN set -e; for f in patches/*.patch; do echo ${f}; [[ -f ${f} ]] || continue; git apply ${f}; done
ENV GODEBUG="http2server=0"
ENV GOEXPERIMENT=strictfipsruntime

RUN CGO_ENABLED=1 \
    go build -ldflags="-X 'knative.dev/pkg/changeset.rev=$(cat /tmp/HEAD)'" -mod=vendor -tags disable_gcp,strictfipsruntime  -v -o /tmp/manual-approval-gate-controller \
    ./cmd/controller

FROM $RUNTIME
ARG VERSION=1.18

ENV KO_APP=/ko-app \
    KO_DATA_PATH=/kodata

COPY --from=builder /tmp/manual-approval-gate-controller ${KO_APP}/manual-approval-gate-controller

LABEL \
    com.redhat.component="openshift-pipelines-manual-approval-gate-controller-rhel9-container" \
    cpe="cpe:/a:redhat:openshift_pipelines:1.18::el9" \
    description="Red Hat OpenShift Pipelines manual-approval-gate controller" \
    io.k8s.description="Red Hat OpenShift Pipelines manual-approval-gate controller" \
    io.k8s.display-name="Red Hat OpenShift Pipelines manual-approval-gate controller" \
    io.openshift.tags="tekton,openshift,manual-approval-gate,controller" \
    maintainer="pipelines-extcomm@redhat.com" \
    name="openshift-pipelines/pipelines-manual-approval-gate-controller-rhel9" \
    summary="Red Hat OpenShift Pipelines manual-approval-gate controller" \
    version="v1.18.0"

RUN groupadd -r -g 65532 nonroot && useradd --no-log-init -r -u 65532 -g nonroot nonroot
USER 65532

ENTRYPOINT ["/ko-app/manual-approval-gate-controller"]
