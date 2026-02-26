
# Outline Wiki on Azure — Terraform + Ansible + Azure PostgreSQL + Azure Blob (S3 via MinIO Gateway)

This repository deploys **Outline Wiki** (getoutline.com) on **Azure** using **Terraform** and configures it with **Ansible**. The install follows the **official recommendation to self-host with Docker**, and connects to a **managed Azure PostgreSQL** database. File uploads are stored in **Azure Blob** and exposed to Outline via an **S3-compatible MinIO gateway**.

> Outline's self-host docs recommend Docker for production, and require PostgreSQL, Redis, and S3-compatible (or local) storage; OAuth is required for login. 

## What this deploys
- Azure Resource Group, VNet/Subnets, NSG, Public IP, NIC
- Ubuntu 22.04 LTS VM (Docker host)
- **Azure Database for PostgreSQL Flexible Server** (VNet-integrated)
- **Azure Storage Account** (Blob) + private container `outline`
- Ansible installs Docker, Redis, **MinIO gateway for Azure Blob**, **Outline Wiki** container, Nginx, and Let’s Encrypt
- TLS certificate for `wiki.mccoy-partners.com`
- OAuth via **Azure AD (OIDC)**

### Why MinIO gateway for Azure Blob?
Outline expects an S3-compatible API when not using local storage. MinIO’s **Azure gateway** maps S3 calls to Azure Blob using the storage account name/key and works as an S3 endpoint for your app. 
---

## Prerequisites
1. Azure subscription and a Service Principal for CI (ARM_CLIENT_ID/SECRET/TENANT_ID/SUBSCRIPTION_ID). 
2. Terraform remote backend (Azure Storage). Use the provided script: 
   ```bash
   ./scripts/bootstrap/create-remote-backend.sh rg-tf-backend westeurope stoutlineXXXX tfstate
   ```
   Then pass those values to `terraform init` or the GitHub Action. citeturn3search28
3. DNS A-record: `wiki.mccoy-partners.com` → VM public IP (output after apply)
4. SSH keypair for the VM admin (store pub/priv in GitHub Secrets)
5. Azure AD App Registration (OIDC) with redirect `https://wiki.mccoy-partners.com/auth/oidc.callback`, scopes `openid profile email`. Collect **Client ID/Secret** and **Tenant ID**. 
---

## Configure GitHub Secrets
- `ARM_CLIENT_ID`, `ARM_CLIENT_SECRET`, `ARM_TENANT_ID`, `ARM_SUBSCRIPTION_ID`
- `OUTLINE_SSH_PUBLIC_KEY` — contents of `~/.ssh/outline.pub`
- `OUTLINE_SSH_PRIVATE_KEY` — contents of `~/.ssh/outline`
- `AZURE_STORAGE_KEY` — primary key of the Storage Account (Terraform also outputs the name)
- `OIDC_CLIENT_ID`, `OIDC_CLIENT_SECRET` — Azure AD app credentials
- (Optional) `POSTGRES_PASSWORD_OVERRIDE` — if you want to override the generated password

> The Outline container will connect to Azure PostgreSQL over SSL (`sslmode=require`), consistent with production guidance.

## One‑click deploy with GitHub Actions
1. Push this repo to GitHub.
2. Run **Actions → Deploy Outline Wiki on Azure**. Provide the backend inputs created in the bootstrap step.
3. After completion, visit **https://wiki.mccoy-partners.com** and sign in via Azure AD.

---

## Local run (optional)
```bash
cd terraform
terraform init   -backend-config="resource_group_name=..."   -backend-config="storage_account_name=..."   -backend-config="container_name=tfstate"   -backend-config="key=outline.tfstate"

terraform apply -auto-approve   -var admin_ssh_public_key="$(cat ~/.ssh/outline.pub)"   -var domain_name="wiki.mccoy-partners.com"   -var tenant_id="91f2f599-24f7-4b73-bdcf-d30f018c1002"   -var certbot_email="casper.ballemans@mccoy-partners.com"

IP=$(terraform output -raw public_ip)
cd ../ansible
printf "[outline]
outline ansible_host=%s
" "$IP" > hosts.ini
ansible-playbook -i hosts.ini outline.yml   --extra-vars "oidc_client_id=... oidc_client_secret=..."   --extra-vars "azure_storage_account=$(terraform -chdir=../terraform output -raw storage_account_name) azure_storage_key=..."   --extra-vars "postgres_fqdn=$(terraform -chdir=../terraform output -raw postgres_fqdn) postgres_user=$(terraform -chdir=../terraform output -raw postgres_username) postgres_password=$(terraform -chdir=../terraform output -raw postgres_password)"
```

---

## Notes & references
- **Outline install methods** (Docker recommended for self-hosting): [docs.getoutline.com](citeturn3search37)
- **Outline Docker image / env requirements** incl. Postgres/Redis/S3: [doc mirror](citeturn3search50)
- **OIDC with Outline** (Dex/Azure AD examples): [blog + config](citeturn3search48)
- **MinIO Azure gateway (S3 over Blob)**: [MS Learn sample](citeturn8search50), [GitLab docs](citeturn8search52), [Article/example command](citeturn8search54)
- **Terraform Azure Linux VM resource** (Ubuntu 22.04 reference): [registry]

---

## Troubleshooting
- If OAuth fails, double‑check the **redirect URI** and **tenant/client IDs** in Azure AD. Ensure scopes include `openid profile email`. citeturn3search48
- If uploads fail, confirm MinIO is running (`docker ps`) and Endpoint/keys in `.env` match the storage account name/key. The gateway exposes an S3 API on port 9000. citeturn8search54
- For DB connectivity, ensure `sslmode=require` is present in `DATABASE_URL` as Azure Postgres enforces SSL in production. 
