#!/bin/bash
set -e

KUBECTL_VERSION="v1.31.0"
curl -LO "https://dl.k8s.io/release/${KUBECTL_VERSION}/bin/linux/amd64/kubectl"
curl -LO "https://dl.k8s.io/release/${KUBECTL_VERSION}/bin/linux/amd64/kubectl.sha256"
echo "$(cat kubectl.sha256)  kubectl" | sha256sum --check
chmod +x kubectl && mv kubectl /usr/local/bin/

EKSCTL_VERSION="0.191.0"
curl -sLO "https://github.com/eksctl-io/eksctl/releases/download/v${EKSCTL_VERSION}/eksctl_Linux_amd64.tar.gz"
curl -sLO
"https://github.com/eksctl-io/eksctl/releases/download/v${EKSCTL_VERSION}/eksctl_checksums.txt"
grep "eksctl_Linux_amd64.tar.gz" eksctl_checksums.txt | sha256sum --check
tar -xzf eksctl_Linux_amd64.tar.gz -C /tmp && mv /tmp/eksctl /usr/local/bin/