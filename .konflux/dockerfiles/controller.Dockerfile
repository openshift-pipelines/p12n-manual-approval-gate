ARG GO_BUILDER=registry.redhat.io/ubi9/go-toolset:latest@sha256:2cac9704c8182ea8cf34a3cb8db3870f993446a0eb98d4068ac26e19e1900f41
ARG UBI_RUNTIME=registry.redhat.io/ubi9/ubi-minimal-pqc:latest@sha256:5e9a0970f73f4800445c3ce0ca0d6b7ea1a8c620b81e735d16432db09d6787bc

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
ARG VERSION=next

ENV KO_APP=/ko-app \
    KO_DATA_PATH=/kodata

COPY --from=builder /tmp/manual-approval-gate-controller ${KO_APP}/manual-approval-gate-controller

LABEL \
    com.redhat.component="openshift-pipelines-manual-approval-gate-controller-rhel9-container" \
    cpe="cpe:/a:redhat:openshift_pipelines:next::el9" \
    description="Red Hat OpenShift Pipelines manual-approval-gate controller" \
    io.k8s.description="Red Hat OpenShift Pipelines manual-approval-gate controller" \
    io.k8s.display-name="Red Hat OpenShift Pipelines manual-approval-gate controller" \
    io.openshift.tags="tekton,openshift,manual-approval-gate,controller" \
    maintainer="pipelines-extcomm@redhat.com" \
    name="openshift-pipelines/pipelines-manual-approval-gate-controller-rhel9" \
    summary="Red Hat OpenShift Pipelines manual-approval-gate controller" \
    version="next"

RUN groupadd -r -g 65532 nonroot && useradd --no-log-init -r -u 65532 -g nonroot nonroot
USER 65532

ENTRYPOINT ["/ko-app/manual-approval-gate-controller"]
