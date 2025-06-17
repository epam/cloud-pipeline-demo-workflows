# Cloud Pipeline Demo Workflows

This repository contains demo versions of bioinformatics pipelines adapted for the [Cloud Pipeline](https://github.com/epam/cloud-pipeline) platform. Most of the pipelines originate from the [nf-core](https://nf-co.re/) project and have been modified for the platform environments.

The repository provides configuration templates and adaptation guidelines, including instructions on modifying parameters such as Docker images, instance types, and input/output paths to ensure correct execution within a demo deployment.

---

## `.env` File

The `deploy-pipelines-nextflow.sh` script requires a `.env` file containing environment variables. These variables define credentials and endpoints needed to connect to the Cloud Pipeline platform and Git service for pipeline deployment.

### Example `.env` template:

```env
CP_CODE_BASE=<cloud_pipeline_code_base_path>
CP_API_JWT_ADMIN=<your_jwt_token_here>
CP_API_SRV_INTERNAL_HOST=<cloud_pipeline_host>
CP_API_SRV_INTERNAL_PORT=443
GITLAB_ROOT_USER=<user_name>
GITLAB_ROOT_PASSWORD=<your_gitlab_user_password>
CP_GITLAB_INTERNAL_HOST=<git_host>
CP_GITLAB_INTERNAL_PORT=443
CP_CLOUD_PLATFORM=<aws|gcp>
NF_DEMO_BUCKET=<gs|s3://demo_data_bucket>
```
---

## Adapting a Pipeline for Demo

To prepare a working Nextflow pipeline for demo deployment on Cloud Pipeline, apply the following modifications to its `config.json`:

1. **Docker image**  
   Remove the registry URL from the `docker_image` value to use local or default image resolution.

2. **Instance size**  
   Replace hardcoded instance types with a variable:  
   ```json
   "instance_size": "${CP_CONFIG_JSON_INSTANCE_TYPE}"
   ```

3. **Input/output paths**  
   Modify all file and directory paths to begin with `${NF_DEMO_BUCKET}` to ensure they reference cloud demo storage.

4. **Escaping variables**  
   If using `${RUN_ID}` in the config, escape it for Cloud Pipeline compatibility:  
   ```json
   "${CP_DOLLAR}{RUN_ID}"
   ```

---

## Structure

Each pipeline resides in its own subdirectory and includes:

- `config.json` – Cloud Pipeline configuration template  
- `spec.json` - Pipeline specification file containing metadata, version info and the platform specific settings.

Read more details how to manage pipelines in the [Cloud Pipeline Docs](https://github.com/epam/cloud-pipeline/blob/master/docs/md/manual/06_Manage_Pipeline/6._Manage_Pipeline.md).


---

## Notes

- This repository is meant for demonstration and educational purposes
- Ensure all sensitive credentials in `.env` are stored securely and never committed to version control.
