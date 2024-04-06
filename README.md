# ML Service Deployment with Helmfile and Kubernetes
This repository contains Helm charts and deployment configurations for managing ML services (ml-api and ml-batch) in various environments using Helmfile, Kubernetes, and other supporting tools.

Helmfile is a declarative spec for deploying helm charts. It lets you...

 - Keep a directory of chart value files and maintain changes in version control.
 - Apply CI/CD to configuration changes.
 - Periodically sync to avoid skew in environments.
To avoid upgrades for each iteration of `helm`, the `helmfile` executable delegates to `helm` - as a result, helm must be installed.

### Highlights
*Declarative*: Write, version-control, apply the desired state file for visibility and reproducibility.

*Modules*: Modularize common patterns of your infrastructure, distribute it via Git, S3, etc. to be reused across the entire company (See #648)

*Versatility*: Manage your cluster consisting of charts, kustomizations, and directories of Kubernetes resources, turning everything to Helm releases (See #673)

*Patch*: JSON/Strategic-Merge Patch Kubernetes resources before helm-installing, without forking upstream charts (See #673)

## Installation

macOS (using homebrew): `brew install helmfile`
For other OS: https://helmfile.readthedocs.io/en/latest/#installation

## Getting Started
Created helmfile for each environment separately. It will have multiple releases (multiple charts). When new project is created we can publish the chart into cloud and release it via helmfile. I've added published helmchart [external-secrets](deployments/published/helmfile.yaml) for reference.

This is also allowing us to deploy particular release to the environment. 

Directory structure as follows:
```

charts/
  |
  |___ml-api/        # helm chart for ml-api application
  |___ml-batch/      # helm chart for ml-batch application
deployments/
  |
  |___dev/
      |__helmfile.yaml    # helmfile for dev environments to manage multiple releases
  |___staging/
      |__helmfile.yaml    # helmfile for staging environments to manage multiple releases
  |___prod/
      |__helmfile.yaml    # helmfile for prod environments to manage multiple releases
  |___published/
      |__helmfile.yaml    # helmfile for published charts to manage multiple releases
values/
  |
  |___dev/
      |__values.yaml # values for helm chart to override the base values in chart
  |___staging/
      |__values.yaml # values for helm chart to override the base values in chart
  |___prod/
      |__values.yaml # values for helm chart to override the base values in chart
```
Created 2 charts ml-api and ml-batch. Both services uses same docker image for testing. If we want to deploy both charts we can apply without `selector` flag. If we want to deploy only particular chart we can release it using `selector` flag.

Each chart has its own `values.yaml` file which can be overridden based on environments. 


### To deploy chart via helmfile
```shell
# Release ml-api chart into dev environment
helmfile --selector service=ml-api --file deployments/dev/helmfile.yaml apply

# Release ml-batch chart into dev environment
helmfile --selector service=ml-batch --file deployments/dev/helmfile.yaml apply
```
This command will release the chart into the dev environment and package the chart to push into the cloud.

### To verify the release
```shell
# List the releases
helm list --all-namespaces
```
### Accessing services
Forward ports to access the deployed services:
```shell
# Get the service URL for dev-ml-api
kubectl port-forward svc/dev-ml-api -n dev 8000:8000

# Get the service URL for staging-ml-api
kubectl port-forward svc/staging-ml-api -n staging 8000:8000

# Get the service URL for prod-ml-api
kubectl port-forward svc/prod-ml-api -n prod 8000:8000
```


## Autoscaling
Configured autoscaling based on CPU utilisation percentage. If it's goes beyond that it will scale pods upto 10 replicas. Also, We can use [Keda Autoscaler](https://keda.sh/) to scale based on custom metrics like queue length, etc.

## Secrets
Secrets are managed using [External Secrets Operator](https://github.com/external-secrets/external-secrets?ref=blog.gitguardian.com).
The External Secrets Operator is a K8s operator that facilitates the integration of external secret management systems, such as AWS Secrets Manager, HashiCorp Vault, Google Secrets Manager, and Azure Key Vault, with K8s.

Simply put, this operator automatically retrieves secrets from these secrets managers using external APIs and injects them into Kubernetes Secrets.

```shell
# To install external-secrets operator via helmfile
helmfile apply --file deployments/published/helmfile.yaml

# To install external-secrets operator via helm
helm repo add external-secrets https://charts.external-secrets.io
helm repo update
helm install external-secrets \
  external-secrets/external-secrets \
  -n external-secrets \
  --create-namespace
```

## CI/CD
CI/CD is managed using GitHub Actions. refer `.github/workflows` directory for more details.


# Alternative Approach
### ML Service Deployment with Helmfile, Kustomize, and ArgoCD
Use of Helmfile, Kustomize, and ArgoCD for managing ML service deployments in Kubernetes. 

Directory structure:
```
ml-api-kustomize/
├── base
│   ├── configMap.yaml
│   ├── deployment.yaml
│   ├── kustomization.yaml
│   └── service.yaml
└── overlays
    ├── default
    │   ├── kustomization.yaml
    │   └── map.yaml
    ├── production
    │   ├── deployment.yaml
    │   └── kustomization.yaml
    └── staging
        ├── kustomization.yaml
        └── map.yaml
```
### Implementations
#### Helmfile
Create a helmfile.yaml to manage Helm releases and integrate with Kustomize:

```yaml
- name: kustomize
  chart: ./foo
  hooks:
  - events: ["prepare", "cleanup"]
    command: "../helmify"
    args: ["{{`{{if eq .Event.Name \"prepare\"}}build{{else}}clean{{end}}`}}", "{{`{{.Release.Ch\
art}}`}}", "{{`{{.Environment.Name}}`}}"]
```
Use Helmfile to synchronize environments:
```shell
helmfile --environment staging sync
```
This command results in Helmfile running `kustomize build ml-api-kustomize/overlays/staging > ml-api/templates/all.yaml`.

### Kustomize
The `ml-api-kustomize` directory contains Kustomize base and overlay configurations for different environments (`base`, `overlays/staging`, `overlays/prod`). Customize Kubernetes manifests using Kustomize to manage environment-specific configurations.

### ArgoCD Integration
Configure ArgoCD to manage the ml-api/templates/ folder and sync all manifest YAMLs:

1. Create an application in ArgoCD.
2. Configure the sync directory to ml-api/templates/ to automatically sync all manifest files to the Kubernetes cluster.