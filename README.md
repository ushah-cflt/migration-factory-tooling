🧰 **msk-migration-cli**
A Linux CLI tool that automates the creation of an Amazon EKS Cluster using Terraform—designed for MSK to Confluent Platform migration workflows.

📦 **Features**
Create EKS clusters with custom names, sizes, and VPC/Subnet configuration
Fully automated Terraform deployment
Outputs EKS cluster information to a file
Supports external discovery config integration

**Pluggable & extensible**

📁 **Directory Structure**

msk-migration-cli/
├── bin/
│   └── msk-migration-cli          # Main CLI script
├── templates/
│   └── terraform-eks/             # Terraform templates
│       ├── main.tf
│       ├── variables.tf
│       └── outputs.tf
├── README.md                      # You are here

🚀 **Usage**
🔧 Command
```
msk-migration-cli eks-jump-cluster \
--create \
--name <cluster-name> \
--region <aws-region> \
--desired-size <number-of-nodes> \
--vpc-id <vpc-id> \
--subnet-id <subnet-1>,<subnet-2> \
--output-file <path-to-output.json> \
--discovery-config <path-to-config.yaml>
```

📌 **Arguments**


Flag	Required	Description
--create	✅	Triggers the cluster creation
--name	✅	Name of the EKS cluster
--region	✅	AWS region (e.g. us-east-1)
--desired-size	✅	Number of EC2 worker nodes
--vpc-id	✅	VPC ID to deploy into
--subnet-id	✅	Comma-separated list of subnet IDs
--output-file	✅	Path to save the Terraform outputs (JSON)
--discovery-config	Optional	Path to your discovery config YAML

✅ **Example**

```
./bin/msk-migration-cli eks-jump-cluster \
--create \
--name test-eks \
--region us-east-1 \
--desired-size 3 \
--instance-type m5.xlarge
--vpc-id vpc-0abc123456789def0 \
--subnet-id subnet-01abc,subnet-02def \
--output-file output.json \
--discovery-config discovery.json
```

🛠 **Requirements**
AWS CLI configured (aws configure)

kubectl & eksctl installed and in PATH

Terraform >= 1.0 installed

Bash (compatible with Linux/macOS)

🧪 **Outputs**
A file (e.g. output.json) containing:

EKS cluster name
Endpoint
AWS CLI kubeconfig command
EKS node count

Other useful cluster metadata

**Other commands**

**Destroy with confirmation:**

```
./bin/msk-migration-cli eks-jump-cluster --destroy --name test-eks
```

**Destroy without confirmation:**

```
./bin/msk-migration-cli eks-jump-cluster --destroy --name test-eks --force
```

**Destroy and clean working directory (no prompt):**

```
./bin/msk-migration-cli eks-jump-cluster --destroy --name test-eks --force --force-cleanup
```
📥 **Installation**
Clone and run:

git clone https://github.com/ushah-cflt/migration-factory-tooling.git
cd msk-migration-cli
chmod +x bin/msk-migration-cli
Add to your PATH (optional):

export PATH="$PATH:$(pwd)/bin"

📚** Notes**
This tool uses Terraform under the hood to provision EKS.
You can modify the templates in templates/terraform-eks/ for customizations (e.g., node groups, autoscaling, logging).
Make sure the AWS account has sufficient permissions to manage EKS, EC2, IAM, and networking resources.

🧩 **Roadmap**

Integrate CFK Kafka/Control Center deployment
Add Python version with better parsing/validation
