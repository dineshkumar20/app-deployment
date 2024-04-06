terraform {
  required_version = "= 1.1.8"

  required_providers {
    aws = "~> 5.3.0"
    helmfile = {
      source = "mumoshu/helmfile"
      version = "VERSION"
    }
  }

  backend "s3" {
    # Set here by "terraform init -backend-config=..."
  }
}

provider "helmfile" {}


resource "helmfile_release_set" "mystack" {
    content = file("${var.helm_file_path}")
}