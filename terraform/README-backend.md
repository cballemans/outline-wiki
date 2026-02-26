
# Terraform Backend

This project expects a remote backend in Azure Storage. Create it once using the bootstrap script in `scripts/bootstrap/create-remote-backend.sh` and then supply the values to `terraform init` using `-backend-config` or via the GitHub Actions workflow.
