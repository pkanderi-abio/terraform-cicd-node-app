# terraform-cicd-node-app
CI/CD Pipeline with GitHub Actions
[![Terraform CI/CD](https://github.com/pkanderi-abio/terraform-cicd-node-app/actions/workflows/terraform.yml/badge.svg)](https://github.com/pkanderi-abio/terraform-cicd-node-app/actions/workflows/terraform.yml)

**Project Overview**
# CI/CD Pipeline with GitHub Actions:
Automate terraform init, plan, and apply on code changes.
Store Terraform state in your existing S3 bucket (my-terraform-state-XXXXXXX) with DynamoDB locking.
Trigger on push to the main branch.
# Node.js Web Application:
Deploy a simple Node.js app (e.g., a “Hello World” HTTP server) to the EC2 instances.
Update user_data in the aws_launch_template to install Node.js, clone the app, and start it alongside Nginx.
