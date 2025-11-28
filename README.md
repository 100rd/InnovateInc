# EKS Cluster with Karpenter Terraform

This Terraform project deploys a new Amazon EKS cluster into a new VPC. The cluster is configured with [Karpenter](https://karpenter.sh/) for autoscaling.

## Features

- Creates a new VPC with public and private subnets across multiple Availability Zones.
- Deploys an EKS cluster (latest version available at the time of writing).
- Installs and configures Karpenter for intelligent node provisioning.
- Configures Karpenter with two `NodePools`:
  - `default`: For `amd64` (x86) workloads, prioritizing Spot instances.
  - `arm64`: For `arm64` (Graviton) workloads, also prioritizing Spot instances.

## Prerequisites

- [Terraform](https://learn.hashicorp.com/tutorials/terraform/install-cli) (v1.5+)
- [AWS CLI](https://aws.amazon.com/cli/) configured with appropriate credentials.
- [kubectl](https://kubernetes.io/docs/tasks/tools/install-kubectl/)
- [Helm](https://helm.sh/docs/intro/install/)

## How to Use

1.  **Initialize Terraform:**
    ```bash
    terraform init
    ```

2.  **Plan the deployment:**
    Review the resources that will be created. You will be prompted to provide the availability zones. For example: `["us-east-1a", "us-east-1b", "us-east-1c"]`
    ```bash
    terraform plan
    ```

3.  **Apply the configuration:**
    This will provision the VPC, EKS cluster, and all related resources.
    ```bash
    terraform apply
    ```

4.  **Configure kubectl:**
    After the apply is complete, Terraform will output a command to configure `kubectl`. Run this command:
    ```bash
    aws eks update-kubeconfig --name innovate-inc-cluster --region us-east-1
    ```

5.  **Verify the cluster:**
    Check that the nodes are running and the `kube-system` and `karpenter` pods are healthy.
    ```bash
    kubectl get nodes
    kubectl get pods -n kube-system
    kubectl get pods -n karpenter
    ```

## Deploying Applications

You can control where your pods are scheduled by using the `kubernetes.io/arch` node selector.

### Example: Deploying a Pod on an x86 (amd64) Instance

This manifest will cause Karpenter to provision a new `amd64` node if one is not already available.

**`nginx-x86.yaml`**
```yaml
apiVersion: apps/v1
kind: Deployment
metadata:
  name: nginx-x86
spec:
  replicas: 1
  selector:
    matchLabels:
      app: nginx-x86
  template:
    metadata:
      labels:
        app: nginx-x86
    spec:
      nodeSelector:
        kubernetes.io/arch: "amd64"
      containers:
      - name: nginx
        image: nginx:latest
        ports:
        - containerPort: 80
```

Deploy it with:
```bash
kubectl apply -f nginx-x86.yaml
```

### Example: Deploying a Pod on a Graviton (arm64) Instance

This manifest will cause Karpenter to provision a new `arm64` (Graviton) node.

**`nginx-arm64.yaml`**
```yaml
apiVersion: apps/v1
kind: Deployment
metadata:
  name: nginx-arm64
spec:
  replicas: 1
  selector:
    matchLabels:
      app: nginx-arm64
  template:
    metadata:
      labels:
        app: nginx-arm64
    spec:
      nodeSelector:
        kubernetes.io/arch: "arm64"
      containers:
      - name: nginx
        image: public.ecr.aws/nginx/nginx:latest-arm64
        ports:
        - containerPort: 80
```

Deploy it with:
```bash
kubectl apply -f nginx-arm64.yaml
```

After a minute or two, you can check the nodes again to see that Karpenter has provisioned new nodes to satisfy these deployments.

```bash
kubectl get nodes --label-columns=kubernetes.io/arch
```
# InnovateInc
