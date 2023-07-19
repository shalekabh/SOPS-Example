#!/bin/bash

FLAG_FILE="terraform_state_flag.txt"

if [ ! -f "$FLAG_FILE" ]; then
  # First time run: Use local .terraform/terraform.tfstate
  if [ -f ".terraform/terraform.tfstate" ]; then
    aws s3 cp s3://sops2/terraform.tfstate unencrypted.tfstate
    sops -e --config .sops.yaml unencrypted.tfstate > encrypted.tfstate
    aws s3 mv encrypted.tfstate s3://sops2/terraform.tfstate
    rm unencrypted.tfstate
  else
    echo "Error: .terraform/terraform.tfstate not found locally."
    exit 1
  fi

  # Create the flag file to indicate that the script has been run once.
  touch "$FLAG_FILE"
else
  # Subsequent runs: Use state file from S3
  aws s3 cp s3://sops2/terraform.tfstate encrypted.tfstate
  sops -d --config .sops.yaml encrypted.tfstate > .terraform/terraform.tfstate
  aws s3 mv .terraform/terraform.tfstate s3://sops2/terraform.tfstate
  rm encrypted.tfstate
  terraform init

  # Remove the flag file to allow using S3 state for future runs.
  rm "$FLAG_FILE"
fi
