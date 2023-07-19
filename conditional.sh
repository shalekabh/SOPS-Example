#!/bin/bash

if [ -f ".terraform/terraform.tfstate" ]; then
  sops --encrypt --kms arn:aws:kms:eu-west-1:537561209985:key/mrk-9f08dc560e1f41e1ac10b521c9b5223c .terraform/terraform.tfstate > encrypted.tfstate
  aws s3 cp encrypted.tfstate s3://sops2/terraform.tfstate
  rm .terraform/terraform.tfstate
else
  aws s3 cp s3://sops2/terraform.tfstate encrypted.tfstate
  sops -d --config .sops.yaml encrypted.tfstate > terraform.tfstate
  aws s3 rm s3://sops2/terraform.tfstate
  rm encrypted.tfstate
  terraform init
fi
