# SOPS - Secrets OPerationS

SOPS is an open-source tool developed by Mozilla that integrates with existing encryption systems like PGP (Pretty Good Privacy) or AWS Key Management Service (KMS). It allows you to encrypt secrets using a public key and then decrypt them using a private key. This encryption process ensures that secrets remain protected and can only be accessed by authorized individuals or systems.

### Downloading and installing sops
Im using windows so I needed to install Chocolatey first using:

```
Set-ExecutionPolicy Bypass -Scope Process -Force; [System.Net.ServicePointManager]::SecurityProtocol = [System.Net.ServicePointManager]::SecurityProtocol -bor 3072; iex ((New-Object System.Net.WebClient).DownloadString('https://chocolatey.org/install.ps1'))
>> 
```

Then use Chocolatey to install sops:

```choco install sops```

```sops --version``` to check if its installed

### Install AWS CLI

Download and run the AWS CLI MSI installer for Windows (64-bit):

```msiexec.exe /i https://awscli.amazonaws.com/AWSCLIV2.msi```

To confirm the installation, open the Start menu, search for cmd to open a command prompt window, and at the command prompt use the aws --version command.

```aws --version```

### Create AWS KMS keys

Go to aws console and go to AMS KMS (Key Management Service) and create a key in one or two regions, I did two.

(Optional) Copy the ARN of each key and paste them using this comma seperated command:

```
export SOPS_KMS_ARN="arn:aws:kms:eu-west-2:537561209985:key/mrk-84be7a983ce34043972280ee64ac9567, arn:aws:kms:eu-west-1:537561209985:key/mrk-9f08dc560e1f41e1ac10b521c9b5223c"
```

Next create a ```.sops.yaml``` and put your KMS ARNs in there.

```
creation_rules:
  - kms: 'arn:aws:kms:eu-west-1:537561209985:key/mrk-9f08dc560e1f41e1ac10b521c9b5223c, arn:aws:kms:eu-west-2:537561209985:key/mrk-84be7a983ce34043972280ee64ac9567'

```

# Terraform backend set up

Create a main.tf file and configure youre backend with this:

```
provider "aws" {
  region = "eu-west-1"
}

terraform {

  backend "s3" {

    bucket = "sops2"

    key    = "terraform.tfstate"

    region = "eu-west-1"

  }

}
```
This will create an S3 Bucket called `sops2` where it will refer to our key `terraform.tfstate`

Then run ```terraform init``` to initialise the backend and a ```terraform apply``` to put the tfstate file in the bucket.

# Scripting

Now we have most of the requirements and configurations, we now want to create a script to encrypt and decrypt or file. Everytime you make a change or create a resource, it will automatically be updated to your s3 bucket, which is why we want to encrypt it. Create a file called `encrypt.sh` and use the following commands:

```
#!/bin/bash
aws s3 cp s3://sops2/terraform.tfstate unencrypted.tfstate
sops -e --config .sops.yaml unencrypted.tfstate > encrypted.tfstate
aws s3 mv encrypted.tfstate s3://sops2/terraform.tfstate
rm unencrypted.tfstate
```

The script first copies down your current state file from S3, encrypts it using the KMS keys in the .sops.yaml file, then moves the encrypted file back to s3 and lastly removes the unencrypted file from our local machine.

Check your s3 bucket that has the state file in it and see if the encryption worked.

Now we have in encrypted, lets say you want to add a resource. YOU CANNOT DO THIS WHILE THE STATE FILE INS ENCRYPTED, YOU MUST DECRYPT IT FIRST AND THEN APPLY THE RESOURCE. So we want to make a decryption script called `decrypt.sh` and use the following commands:

```
#!/bin/bash
aws s3 cp s3://sops2/terraform.tfstate encrypted.tfstate
sops -d --config .sops.yaml encrypted.tfstate > terraform.tfstate
aws s3 mv terraform.tfstate s3://sops2/terraform.tfstate
rm encrypted.tfstate
```

The script first copies the encrypted file from s3 to local, the the sops command decrypts it, refering to the .sops.yaml file, then the aws command moves the decrypted file back to s3 and removes the encrypted file from our local machine.

Check the s3 bucket to make sure it has been decrypted.

Now add your resource to your main.tf file, in my case i created an extra bucket:

```
resource "aws_s3_bucket" "new-test" {
    
  bucket = "sops3"
  
}
```

Run ```terraform apply``` and if it worked, go back to s3 and check to see if the new bucket was created and also check your state file in your other bucket to see if it has been updated with the new resource.

If all went according to expectations, then the final thing to do is to run the encryption script again and check to see if your latest file in your bucket is encrypted.

# Conditional statement script

If you want all of the commands in one script as a conditional statement, here are the following commands:

```
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
```