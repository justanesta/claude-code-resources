# CI Integration

## GitHub Actions: Terraform Workflow

A standard Terraform CI pipeline runs `init`, `validate`, `plan` on PRs and `apply` on merge to main.

```yaml
name: Terraform
on:
  pull_request:
    branches: [main]
    paths: ['terraform/**']
  push:
    branches: [main]
    paths: ['terraform/**']

permissions:
  id-token: write
  contents: read
  pull-requests: write

env:
  TF_VERSION: "1.7.0"
  AWS_REGION: "us-east-1"

jobs:
  plan:
    name: Terraform Plan
    runs-on: ubuntu-latest
    if: github.event_name == 'pull_request'
    steps:
      - uses: actions/checkout@v4
      - uses: hashicorp/setup-terraform@v3
        with:
          terraform_version: ${{ env.TF_VERSION }}

      - name: Configure AWS Credentials
        uses: aws-actions/configure-aws-credentials@v4
        with:
          role-to-assume: arn:aws:iam::123456789:role/terraform-ci
          aws-region: ${{ env.AWS_REGION }}

      - name: Terraform Init
        working-directory: terraform/
        run: terraform init -input=false

      - name: Terraform Validate & Format
        working-directory: terraform/
        run: |
          terraform validate
          terraform fmt -check -recursive -diff

      - name: Terraform Plan
        working-directory: terraform/
        run: |
          terraform plan -input=false -no-color \
            -var-file="environments/prod.tfvars" \
            -out=tfplan 2>&1 | tee plan-output.txt

      - name: Upload Plan Artifact
        uses: actions/upload-artifact@v4
        with:
          name: tfplan-${{ github.sha }}
          path: terraform/tfplan
          retention-days: 5

  apply:
    name: Terraform Apply
    runs-on: ubuntu-latest
    if: github.event_name == 'push' && github.ref == 'refs/heads/main'
    environment: production
    steps:
      - uses: actions/checkout@v4
      - uses: hashicorp/setup-terraform@v3
        with:
          terraform_version: ${{ env.TF_VERSION }}

      - name: Configure AWS Credentials
        uses: aws-actions/configure-aws-credentials@v4
        with:
          role-to-assume: arn:aws:iam::123456789:role/terraform-ci
          aws-region: ${{ env.AWS_REGION }}

      - name: Terraform Init & Apply
        working-directory: terraform/
        run: |
          terraform init -input=false
          terraform apply -input=false -auto-approve \
            -var-file="environments/prod.tfvars"
```

---

## GitLab CI Pipeline

```yaml
stages:
  - validate
  - plan
  - apply

variables:
  TF_VERSION: "1.7.0"
  TF_ROOT: terraform/

.terraform-base:
  image: hashicorp/terraform:${TF_VERSION}
  before_script:
    - cd ${TF_ROOT}
    - terraform init -input=false

validate:
  extends: .terraform-base
  stage: validate
  script:
    - terraform validate
    - terraform fmt -check -recursive
  rules:
    - if: $CI_PIPELINE_SOURCE == "merge_request_event"

plan:
  extends: .terraform-base
  stage: plan
  script:
    - terraform plan -input=false -no-color
        -var-file="environments/${CI_ENVIRONMENT_NAME}.tfvars"
        -out=tfplan
  artifacts:
    paths:
      - ${TF_ROOT}/tfplan
    expire_in: 3 days
  rules:
    - if: $CI_PIPELINE_SOURCE == "merge_request_event"

apply:
  extends: .terraform-base
  stage: apply
  script:
    - terraform apply -input=false tfplan
  dependencies:
    - plan
  rules:
    - if: $CI_COMMIT_BRANCH == "main"
      when: manual
  environment:
    name: production
```

---

## Plan Artifacts

Save binary plan files as CI artifacts for deterministic applies. The plan captures the exact changes at a point in time.

```bash
# Generate plan and save as binary
terraform plan -out=tfplan -var-file="environments/prod.tfvars"

# Show human-readable output of saved plan
terraform show tfplan

# Export plan as JSON for programmatic analysis
terraform show -json tfplan > plan.json

# Check for destructive changes in CI
terraform show -json tfplan | jq '
  [.resource_changes[] |
   select(.change.actions | contains(["delete"]))] |
  length
' | read DESTROY_COUNT

if [ "$DESTROY_COUNT" -gt 0 ]; then
  echo "WARNING: Plan includes $DESTROY_COUNT resource destructions"
  echo "Manual approval required"
fi
```

---

## Atlantis Configuration

Atlantis automates Terraform via pull request comments. Configure with `atlantis.yaml` in the repo root.

```yaml
# atlantis.yaml
version: 3
automerge: false
delete_source_branch_on_merge: true

projects:
  - name: networking
    dir: terraform/networking
    workspace: default
    terraform_version: v1.7.0
    autoplan:
      when_modified: ["*.tf", "*.tfvars", "modules/**/*.tf"]
      enabled: true
    apply_requirements: [approved, mergeable]
    workflow: default

  - name: compute
    dir: terraform/compute
    workspace: default
    terraform_version: v1.7.0
    autoplan:
      when_modified: ["*.tf", "environments/*.tfvars"]
      enabled: true
    apply_requirements: [approved, mergeable]

workflows:
  default:
    plan:
      steps:
        - init:
            extra_args: ["-input=false"]
        - plan:
            extra_args: ["-var-file=environments/prod.tfvars"]
    apply:
      steps:
        - apply
```

Atlantis commands in PR comments:

```
atlantis plan                    # Run plan for all projects
atlantis plan -p networking      # Plan specific project
atlantis apply                   # Apply all planned changes
atlantis apply -p networking     # Apply specific project
atlantis unlock                  # Release locks
```

---

## Drift Detection

Schedule periodic plan runs to detect infrastructure drift caused by manual changes.

```yaml
name: Terraform Drift Detection
on:
  schedule:
    - cron: '0 8 * * 1-5'  # Weekdays at 8 AM UTC

jobs:
  drift-check:
    runs-on: ubuntu-latest
    steps:
      - uses: actions/checkout@v4
      - uses: hashicorp/setup-terraform@v3
        with:
          terraform_version: "1.7.0"

      - name: Configure AWS Credentials
        uses: aws-actions/configure-aws-credentials@v4
        with:
          role-to-assume: arn:aws:iam::123456789:role/terraform-ci
          aws-region: us-east-1

      - name: Check for Drift
        id: drift
        working-directory: terraform/
        run: |
          terraform init -input=false
          set +e
          terraform plan -input=false -detailed-exitcode \
            -var-file="environments/prod.tfvars" 2>&1 | tee drift.txt
          EXIT_CODE=$?
          set -e
          if [ $EXIT_CODE -eq 2 ]; then
            echo "drift_detected=true" >> "$GITHUB_OUTPUT"
          else
            echo "drift_detected=false" >> "$GITHUB_OUTPUT"
          fi

      - name: Notify on Drift
        if: steps.drift.outputs.drift_detected == 'true'
        uses: slackapi/slack-github-action@v1
        with:
          payload: |
            {
              "text": "Terraform drift detected in production. Review required."
            }
        env:
          SLACK_WEBHOOK_URL: ${{ secrets.SLACK_WEBHOOK }}
```

---

## Edge Cases

- **Plan artifact expiry** — Binary plans are tied to the exact state and provider versions at creation time. If state changes between plan and apply, the saved plan becomes stale and Terraform rejects it. Re-plan when this happens.
- **Concurrent pipelines** — State locking prevents concurrent applies, but two pipelines can generate conflicting plans simultaneously. Use branch protection or Atlantis project locks to serialize.
- **Secrets in plan output** — Plan output may contain sensitive values. Post truncated or redacted plan output to PRs. Use `sensitive = true` on variables and outputs.
- **Large plan output** — GitHub PR comments have a 65536-character limit. Truncate plan output or link to full artifacts.
- **Atlantis locks** — Atlantis locks a project directory when a plan runs. Other PRs modifying the same directory must wait. Use `atlantis unlock` if a PR is abandoned.
- **Auto-apply safety** — Never enable auto-apply for production without required reviewers and branch protection. Auto-apply is acceptable for dev environments behind feature flags.
