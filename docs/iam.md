# IAM: least privilege

| Identity | Before | Now | Why |
|---|---|---|---|
| Worker node role | `AmazonEC2ContainerRegistryReadOnly` (every repo in the account) + CNI policy | Inline policy: pull only from the 2 Faraja repos; CNI policy removed | Pods that reach the node's credentials can't read other images or touch the VPC |
| `aws-node` (VPC CNI) | Used the node role | Own IRSA role (`faraja-cluster-vpc-cni-role`) bound to `kube-system:aws-node` | Only the CNI pod gets network permissions |
| EBS CSI driver | IRSA role (already scoped) | unchanged | Already least privilege |
| `jenkins-ci` user | Push to 2 repos | Same, plus optional `aws:SourceIp` restriction (`jenkins_allowed_source_cidrs`) | Stolen keys are useless from another network |
| Person running Terraform | Needs AdministratorAccess | `terraform/iam-deployer`: scoped policy + permission boundary | Admin in the account is not required; created roles can't escalate |
| ArgoCD app | `default` project (any repo, any namespace) | `faraja` AppProject: one repo, one namespace, 2 cluster kinds | Limits blast radius of a bad commit |

## Deployer policy and boundary
The account admin runs `terraform/iam-deployer` once. It creates:
- `faraja-role-boundary`: the maximum any role created by the deployer can have (EC2, ELB, EKS, ECR, logs; no IAM actions except service-linked roles).
- `faraja-terraform-deployer`: EC2/EKS/ECR in one region, the state bucket and lock table, IAM only for `faraja-cluster-*` roles *created with the boundary attached*, PassRole only to EKS/EC2, no tampering with the boundary itself.

Then the stack is applied with `-var permissions_boundary_arn=<boundary arn>`.

## How to verify
- `terraform plan` shows the node role losing 2 managed policies, gaining an inline one, and a new `vpc-cni` role + add-on.
- `aws iam simulate-principal-policy` against the node role: `ecr:BatchGetImage` on another repo = denied.
- IAM Access Analyzer: no findings for external access.
- Fallback if CNI over IRSA misbehaves: `-var cni_via_irsa=false`.

## Known gaps (honest list)
- `jenkins-ci` still uses long-lived access keys (rotate every 90 days); moving Jenkins to short-lived credentials is the next step.
- Not yet tested against a live account: the deployer policy and boundary may need one iteration (apply, read the AccessDenied, adjust).
- Kubernetes ServiceAccount token hardening and namespace RBAC for people are not done yet.

## Terraform init in any account
```bash
terraform init -backend-config="bucket=faraja-terraform-state-<ACCOUNT_ID>"
terraform plan -var aws_account_id=<ACCOUNT_ID> -var 'cluster_endpoint_public_access_cidrs=["<YOUR_IP>/32"]'
```
Optional variables: `jenkins_allowed_source_cidrs`, `cni_via_irsa`, `permissions_boundary_arn`.

## ArgoCD project
Apply `argocd/faraja-project.yaml` before `argocd/faraja-app.yaml`.
