#!/bin/bash
aws s3 cp s3://sops2/terraform.tfstate unencrypted.tfstate
sops -e --config .sops.yaml unencrypted.tfstate > encrypted.tfstate
aws s3 mv encrypted.tfstate s3://sops2/terraform.tfstate
rm unencrypted.tfstate