#!/usr/bin/env bash
set -euo pipefail

APP_NAME=${1:-ecommerce_platform_api}
TEMPLATE_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/../template" && pwd)"

echo "Creating Rails API app: ${APP_NAME}"
rails new "${APP_NAME}" --api -d postgresql -m "${TEMPLATE_DIR}/template.rb"

echo "Done. Next steps:"
echo "  cd ${APP_NAME}"
echo "  bin/rails db:setup"
echo "  bin/rails server"
