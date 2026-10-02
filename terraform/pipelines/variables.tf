variable "resource_prefix" {
  type        = string
  description = "Prefix for AWS Resources"
  default     = "dsb"
}

variable "eks_cluster_name" {
  type        = string
  description = "Name of the EKS Cluster"
  default     = "dsb-devsecops-cluster"
}

variable "region" {
  type        = string
  description = "AWS Region"
  default     = "us-east-1"
}

variable "SNYK_TOKEN" {}
variable "SNYK_ORG_ID" {}

variable "ENABLE_DAST" {
  type        = bool
  description = "Add a runtime pentest (DAST) stage after Deploy. Requires a Darkmoon Pro endpoint."
  default     = false
}

variable "DARKMOON_PRO_URL" {
  type        = string
  description = "Darkmoon Pro API base URL (only used when ENABLE_DAST is true)"
  default     = ""
}

variable "DARKMOON_PRO_TOKEN" {
  type        = string
  description = "Darkmoon Pro bearer token (only used when ENABLE_DAST is true)"
  default     = ""
  sensitive   = true
}

variable "DAST_TARGET_URL" {
  type        = string
  description = "URL of the deployed app to test; only test systems you are authorized to test"
  default     = ""
}
