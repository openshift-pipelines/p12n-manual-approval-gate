ARG GO_BUILDER=registry.redhat.io/ubi9/go-toolset:9.7
ARG RUNTIME=registry.access.redhat.com/ubi9/ubi-minimal:latest@sha256:ecd4751c45e076b4e1e8d37ac0b1b9c7271930c094d1bcc5e6a4d6954c6b2289

FROM $GO_BUILDER AS builder

WORKDIR /go/src/github.com/openshift-pipelines/manual-approval-gate
COPY upstream .
RUN set -e; for f in patches/*.patch; do echo ${f}; [[ -f ${f} ]] || continue; git apply ${f}; done
ENV GODEBUG="http2server=0"
ENV GOEXPERIMENT=strictfipsruntime

RUN CGO_ENABLED=0 \
    go build -ldflags="-X 'knative.dev/pkg/changeset.rev=$(cat /tmp/HEAD)'" -mod=vendor -tags disable_gcp,strictfipsruntime  -v -o /tmp/manual-approval-gate-controller \
    ./cmd/controller

FROM $RUNTIME
ARG VERSION=manual-approval-gate-controller-main

ENV KO_APP=/ko-app \
    KO_DATA_PATH=/kodata

COPY --from=builder /tmp/manual-approval-gate-controller ${KO_APP}/manual-approval-gate-controller

LABEL \
    com.redhat.component="openshift-pipelines-manual-approval-gate-rhel8-container" \
    name="openshift-pipelines/pipelines-manual-approval-gate-rhel8" \
    version=$VERSION \
    summary="Red Hat OpenShift Pipelines Manual Approval Gate" \
    maintainer="pipelines-extcomm@redhat.com" \
    description="Red Hat OpenShift Pipelines Manual Approval Gate" \
    io.k8s.display-name="Red Hat OpenShift Pipelines Manual Approval Gate" \
    io.k8s.description="Red Hat OpenShift Pipelines Manual Approval Gate" \
    io.openshift.tags="pipelines,tekton,openshift"

RUN groupadd -r -g 65532 nonroot && useradd --no-log-init -r -u 65532 -g nonroot nonroot
USER 65532

ENTRYPOINT ["/ko-app/manual-approval-gate-controller"]
