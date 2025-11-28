# Architectural Design for Innovate Inc. on AWS

## 1. Introduction

This document outlines the cloud architecture for Innovate Inc.'s web application on Amazon Web Services (AWS). The design prioritizes security, scalability, cost-effectiveness, and operational efficiency, leveraging managed services and Kubernetes.

## 2. Cloud Environment Structure

We recommend a multi-account strategy using AWS Organizations. This approach provides strong resource isolation, simplifies billing, and enhances security.

### Recommended AWS Accounts:

*   **Management Account:** This account is the root of the AWS Organization. It's used for consolidated billing, account management, and centralized security services like AWS GuardDuty and AWS Control Tower. No application resources should be deployed here.
*   **Shared Services Account:** This account hosts services that are shared across all other accounts, such as CI/CD infrastructure (e.g., self-hosted GitLab runners or Jenkins), container image registries (Amazon ECR), and private networking connections.
*   **Development Account:** An environment for developers to experiment and test new features. It will have its own EKS cluster and a replica of the production infrastructure but with less stringent security and lower-cost resources.
*   **Staging Account:** A pre-production environment that mirrors the production setup as closely as possible. It's used for final testing, performance validation, and user acceptance testing (UAT) before deploying to production.
*   **Production Account:** This account hosts the live, user-facing application. It has the highest level of security, monitoring, and operational rigor. Access to this account is strictly controlled.

**Justification:**

*   **Isolation:** Separating environments prevents development or testing activities from impacting the production application.
*   **Security:** Applying different security policies and access controls to each account minimizes the blast radius of a security incident.
*   **Billing:** Tracking costs per environment becomes straightforward, allowing for better budget management.
*   **Management:** Teams can operate with more autonomy within their respective accounts without affecting others.

## 3. Network Design

### VPC Architecture

A new Virtual Private Cloud (VPC) will be created for each environment (Dev, Staging, Prod). The VPC will be designed for high availability and security.

*   **CIDR Block:** A /16 CIDR block will be used for each VPC (e.g., `10.0.0.0/16`), providing ample IP address space for growth.
*   **Subnets:**
    *   **Public Subnets:** At least two public subnets will be provisioned across different Availability Zones (AZs). These subnets will host resources that need direct internet access, such as NAT Gateways and load balancers.
    *   **Private Subnets:** At least two private subnets will be provisioned across different AZs. The EKS cluster nodes and the PostgreSQL database will reside in these subnets to protect them from direct internet exposure.
*   **Internet Gateway (IGW):** An IGW will be attached to the VPC to allow resources in the public subnets to communicate with the internet.
*   **NAT Gateways:** A NAT Gateway will be deployed in each public subnet. Resources in the private subnets will use NAT Gateways to access the internet for things like pulling container images or applying patches, without being directly accessible from the outside.

### Network Security

*   **Security Groups:** Security Groups will act as virtual firewalls for the EKS nodes and the PostgreSQL database, controlling inbound and outbound traffic at the instance level. Rules will be strict, only allowing necessary traffic (e.g., allowing traffic from the application nodes to the database on the PostgreSQL port).
*   **Network Access Control Lists (NACLs):** NACLs will provide a stateless layer of defense at the subnet level. They will be configured to allow all traffic between subnets within the VPC but can be tightened if needed.
*   **VPC Flow Logs:** Flow Logs will be enabled to capture information about the IP traffic going to and from network interfaces in the VPC. This is crucial for security monitoring and troubleshooting.

## 4. Compute Platform

### Amazon EKS with Karpenter

We will use Amazon Elastic Kubernetes Service (EKS) as the managed Kubernetes platform. EKS simplifies the process of running Kubernetes on AWS by managing the control plane.

*   **EKS Cluster:** A new EKS cluster will be deployed in each environment's VPC. The EKS control plane will be managed by AWS, ensuring high availability and scalability.
*   **Karpenter for Autoscaling:** We will use Karpenter for cluster autoscaling. Karpenter is an open-source, flexible, high-performance Kubernetes cluster autoscaler built by AWS.
    *   **Node Pools (Provisioners):** We will configure Karpenter with two main `Provisioners`:
        1.  **x86 Provisioner:** This will manage `amd64` based nodes (e.g., from the `m5`, `c5` families).
        2.  **ARM64 (Graviton) Provisioner:** This will manage `arm64` based nodes (e.g., from the `m7g`, `c7g` families) to leverage the price/performance benefits of AWS Graviton processors.
    *   **Spot Instances:** Both provisioners will be configured to prioritize Spot instances to significantly reduce costs, with a fallback to On-Demand instances to ensure availability.
    *   **Scaling:** Karpenter will watch for unschedulable pods and launch the most appropriate and cost-effective nodes to meet their requirements. It will also consolidate nodes to reduce waste when they are underutilized.

### Containerization Strategy

*   **Container Images:** The backend (Python/Flask) and frontend (React SPA) applications will be containerized using Docker. Multi-stage builds will be used to create small, secure, and efficient images.
*   **Image Registry:** Amazon Elastic Container Registry (ECR) will be used to store and manage the container images. ECR is a fully-managed, secure, and reliable registry. A separate ECR repository will be created for the backend and frontend applications.
*   **CI/CD Process:**
    1.  Developers push code to a Git repository (e.g., GitHub, AWS CodeCommit).
    2.  A CI/CD pipeline (e.g., GitHub Actions, Jenkins, AWS CodePipeline) is triggered.
    3.  The pipeline builds the Docker images.
    4.  The images are tagged and pushed to ECR.
    5.  The pipeline updates the Kubernetes `Deployment` manifests with the new image tag and applies them to the EKS cluster, triggering a rolling update.

## 5. Database

### Amazon RDS for PostgreSQL

For the PostgreSQL database, we recommend using Amazon Relational Database Service (RDS). RDS is a managed database service that simplifies setup, operation, and scaling of relational databases.

**Justification:**

*   **Managed Service:** RDS handles routine database tasks such as patching, backups, and high availability, allowing the development team to focus on the application.
*   **Scalability:** RDS instances can be easily scaled up (by changing the instance type) or out (by adding read replicas).
*   **Security:** RDS provides multiple security features, including encryption at rest and in transit, and integration with AWS IAM for access control.

### High Availability and Disaster Recovery

*   **Multi-AZ Deployment:** The RDS for PostgreSQL instance will be deployed in a Multi-AZ configuration. In this setup, RDS automatically provisions and maintains a synchronous standby replica in a different Availability Zone. In the event of an infrastructure failure, RDS performs an automatic failover to the standby, minimizing downtime.
*   **Backups:**
    *   **Automated Backups:** RDS will be configured to take automated daily snapshots of the database. These backups will be retained for a configurable period (e.g., 7 days).
    *   **Point-in-Time Recovery:** Transaction logs will be captured, allowing for point-in-time recovery to any second during the retention period.
    *   **Manual Snapshots:** Manual snapshots can be taken before major application changes or for long-term archival.
*   **Disaster Recovery:** For cross-region disaster recovery, automated snapshots can be copied to another AWS region. In the event of a region-wide outage, a new RDS instance can be restored from these snapshots in the disaster recovery region.

This architecture provides a solid foundation for Innovate Inc. to build and scale their application on AWS. It is secure, resilient, and cost-optimized, while also enabling developer agility through a modern CI/CD workflow.
