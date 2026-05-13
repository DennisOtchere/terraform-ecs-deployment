# Project Guide: Secure AWS ECS Deployment via GitHub Actions OIDC

This guide provides a detailed technical record of the end-to-end development of an automated deployment pipeline. It moves beyond a simple "how-to" by documenting the high-level concepts and the specific troubleshooting steps required to align GitHub Actions with AWS IAM security.

----
## 1. Core Architecture Concepts

### OpenID Connect (OIDC) vs. Static Keys
The primary goal was to move away from static `AWS_ACCESS_KEY_ID` and `AWS_SECRET_ACCESS_KEY` stored in GitHub Secrets. We used **OIDC**, which allows GitHub to prove its identity to AWS using a temporary JWT (JSON Web Token). 
* **Security Benefit:** No long-lived credentials to rotate; tokens expire immediately after the job finishes.

### Terraform State Management
We utilized an **S3 Backend** for state management. This ensures that the current state of infrastructure is shared between your local machine and the GitHub runner, preventing resource duplication or conflicts.

---

## 2. Part I: Bootstrapping the Trust Relationship (OIDC)

### The Trust Provider (`oidc.tf`)
The first step was creating an OIDC Provider in IAM. 
* **Lesson Learned:** Do not use dynamic certificate fetching for the thumbprint. AWS requires specific intermediate CA thumbprints for GitHub.
* **Fix:** Hardcoded the official thumbprints: `6938fd4d98bab03faadb97b34396831e3780aea1` and `1c58a3a8518e8759bf075b76b750d4f2df264fcd`.

### The IAM Role & Trust Policy
We created a role named `github-actions-terraform-role`.
* **The Case-Sensitivity Trap:** We discovered that while GitHub profile names might have capitals (e.g., `DennisOtchere`), the OIDC token sent to AWS is also case sensitive. 
* **Lesson:** The `sub` condition in the IAM Trust Policy **must** be in the same case as the name given to the GitHub resource: `repo:DennisOtchere/terraform-ecs-deployment:*`.

---

## 3. Part II: The GitHub Actions Workflow

### Workflow Orchestration
The workflow was configured to trigger on pushes to the `main` branch, targeting a GitHub Environment named `dev`.

### Key Workflow Steps:
1.  **OIDC Authentication:** Using `aws-actions/configure-aws-credentials@v3`.
2.  **Terraform Init:** Initializing the S3 backend.
3.  **Terraform Plan/Apply:** Using the `-input=false` flag.

### Variable Mapping
We mapped GitHub environment variables to Terraform using the `TF_VAR_` prefix.
* **Mistake:** Misnaming a variable (e.g., using `TF_VAR_public_subnet_cidrs` when Terraform expected `TF_VAR_public_subnets`).
* **Lesson:** Terraform will pause and wait for input if a variable is missing, causing the pipeline to hang indefinitely. Using `-input=false` forces an immediate error instead.

---

## 4. Part III: The Troubleshooting Log (Common Failures & Solutions)

### Issue: `403 Access Denied` (AssumeRoleWithWebIdentity)
* **Cause:** Incorrect thumbprints or case-sensitivity mismatch in the repository name/owner.
* **Solution:** Use the `StringLike` operator in the IAM policy and ensure the repository owner name is matching case.

### Issue: `failed to get shared config profile, engineer`
* **Cause:** Hardcoding `profile = "engineer"` in the `provider.tf`.
* **Solution:** Remove the `profile` line. In CI/CD, the runner uses environment variables automatically. Locally, use `export AWS_PROFILE=engineer` before running Terraform.

### Issue: `invalid CIDR address: "10.0.0.0/16"`
* **Cause:** In the GitHub UI, the user wrapped values in double quotes (`"`).
* **Solution:** Remove quotes in the GitHub Secrets/Variables UI for standard strings. GitHub already treats them as strings.

### Issue: Missing IAM Permissions for State Refresh
* **Cause:** The role could *create* resources but couldn't *read* them (e.g., `iam:GetRole`, `iam:GetOpenIDConnectProvider`).
* **Solution:** Broadened the IAM Role Policy to include `iam:Get*` and `iam:List*` actions so Terraform can refresh the state before planning.

### Issue: Local Terminal Credential Lockout
* **Cause:** Terminal had `AWS_PROFILE` set to a name that didn't exist in the `~/.aws/credentials` file (searching for `[engineer]` instead of using `[default]`).
* **Solution:** Run `unset AWS_PROFILE` to allow Terraform to fall back to the default credentials correctly.

---

## 5. Part IV: Final Operational Checklist

1.  **Local Bootstrap:** Run `terraform apply` locally once to create the OIDC provider and the role.
2.  **Push Code:** Once the role exists, push code to GitHub.
3.  **Monitor State:** Ensure the S3 backend is used by both local and remote runs to keep the `terraform.tfstate` synchronized.
4.  **Least Privilege:** As the project matures, refine the `Resource = "*"` in the IAM policy to specific resource ARNs for better security.

---
### Summary of Critical Commands
* `terraform init -reconfigure`: Used when switching backends or credential strategies.
* `terraform plan -input=false`: Essential for CI/CD to prevent hanging.
* `aws sts get-caller-identity`: Best tool for verifying local credentials.