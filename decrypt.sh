#!/bin/bash
aws s3 cp s3://sops2/terraform.tfstate encrypted.tfstate
sops -d --config .sops.yaml encrypted.tfstate > terraform.tfstate
aws s3 mv terraform.tfstate s3://sops2/terraform.tfstate
rm encrypted.tfstate
