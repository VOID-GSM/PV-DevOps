data "aws_region" "current" {}
data "aws_caller_identity" "current" {}

resource "aws_ssm_document" "deploy" {
  name            = "${var.name}-deploy"
  document_type   = "Command"
  document_format = "YAML"

  content = <<-YAML
    schemaVersion: "2.2"
    description: Pull backend image from ECR and restart with docker compose (rollback on failure)
    parameters:
      tag:
        type: String
        description: Image tag (git commit SHA)
        allowedPattern: "^[0-9a-f]{7,40}$"
    mainSteps:
      - action: aws:runShellScript
        name: deploy
        inputs:
          timeoutSeconds: "900"
          runCommand:
            - |
              set -euo pipefail
              export AWS_REGION=${data.aws_region.current.region}
              REGISTRY=${data.aws_caller_identity.current.account_id}.dkr.ecr.${data.aws_region.current.region}.amazonaws.com
              REPO="$REGISTRY/${var.name}-backend"
              cd /data/backend
              {
                aws ssm get-parameters-by-path --path "/${var.name}/backend/" --with-decryption \
                  --query 'Parameters[].[Name,Value]' --output text \
                  | awk -F'\t' '{ n = $1; sub(".*/", "", n); print n "=" $2 }'
                echo "STORAGE_BUCKET=${var.uploads_bucket}"
                echo "PG_DATA_DIR=/data/postgres"
              } > .env.new
              grep -q '^DB_PASSWORD=' .env.new || { echo "missing /${var.name}/backend/DB_PASSWORD" >&2; exit 1; }
              install -m 600 .env.new .env && rm -f .env.new

              aws s3 cp "s3://${var.ops_bucket}/deploy/backend/docker-compose.yml" docker-compose.yml --only-show-errors
              aws ecr get-login-password | docker login -u AWS --password-stdin "$REGISTRY" > /dev/null
              prev="$(cat .backend_tag 2>/dev/null || true)"

              deploy() {
                export BACKEND_IMAGE="$REPO:$1"
                docker pull -q "$BACKEND_IMAGE"
                docker compose up -d --no-build --remove-orphans --wait --wait-timeout 300
              }

              if deploy "{{ tag }}"; then
                echo "{{ tag }}" > .backend_tag
                docker image prune -af --filter "until=72h" > /dev/null
                echo "deployed {{ tag }}"
                exit 0
              fi

              echo "!!! deploy failed: {{ tag }}" >&2
              docker compose logs --tail 80 backend || true
              if [ -n "$prev" ]; then
                deploy "$prev" && echo "rolled back to $prev" >&2
              fi
              exit 1
  YAML
}