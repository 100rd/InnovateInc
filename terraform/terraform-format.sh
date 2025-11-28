#!/bin/bash
# ============================================================================
# Terraform Format Script
# ============================================================================

echo "Formatting Terraform files..."
terraform fmt -recursive

echo "Done! All files formatted."
