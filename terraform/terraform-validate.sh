#!/bin/bash
# ============================================================================
# Terraform Validation Script
# ============================================================================

set -e

echo "========================================"
echo "Terraform Format Check"
echo "========================================"
terraform fmt -check -recursive

echo ""
echo "========================================"
echo "Terraform Init"
echo "========================================"
terraform init -backend=false

echo ""
echo "========================================"
echo "Terraform Validate"
echo "========================================"
terraform validate

echo ""
echo "========================================"
echo "TFLint Check (if installed)"
echo "========================================"
if command -v tflint &> /dev/null; then
    tflint --init
    tflint
else
    echo "TFLint not installed, skipping..."
fi

echo ""
echo "========================================"
echo "All checks passed!"
echo "========================================"
