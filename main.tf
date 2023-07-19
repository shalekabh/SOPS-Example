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

resource "aws_s3_bucket" "new-test" {
    
  bucket = "sops3"
  
}
























# resource "aws_s3_object" "example_object" {
#   bucket = "sops2"
#   key    = "example_file.txt"
#   source = "./example_file.txt"
# }