# Default Connnection to GitHub
resource "random_id" "id" {
  byte_length = 4
}

resource "aws_codestarconnections_connection" "default" {
  name          = "github-connection-${random_id.id.hex}"
  provider_type = "GitHub"
}

# Default Configurations
module "default_bucket" {
  source        = "./modules/s3"
  bucket_prefix = "${var.resource_prefix}-codepipeline-artifacts"
  bucket_name   = "CodePipelineArtifactsBucket"
}

# EKS Cluster
module "cluster_auth" {
  source = "./modules/eks-config"

  eks_cluster_name = var.eks_cluster_name
  roles = [{
    rolearn  = "${module.awsome_fastapi_pipeline.codebuild_iam_role_arn}"
    username = "${module.awsome_fastapi_pipeline.codebuild_iam_role_name}"
    groups   = ["system:masters"]
  }]

  users = [{
    userarn  = "arn:aws:iam::${data.aws_caller_identity.current.account_id}:user/damien"
    username = "damien"
    groups   = ["system:masters"]
  }]
}

# Pipelines
module "awsome_fastapi_pipeline" {
  source = "./modules/codepipeline"

  github_connection_arn = aws_codestarconnections_connection.default.arn

  s3_bucket_name = module.default_bucket.bucket_name
  s3_bucket_arn  = module.default_bucket.bucket_arn

  repo_name     = "awsome-fastapi"
  repository_id = "The-DevSec-Blueprint/awsome-fastapi"
  branch_name   = "main"

  eks_cluster_name = var.eks_cluster_name
  eks_cluster_arn  = "arn:aws:eks:${var.region}:${data.aws_caller_identity.current.account_id}:cluster/${var.eks_cluster_name}"

  compute_type     = "BUILD_GENERAL1_SMALL"
  build_image      = "aws/codebuild/standard:5.0"
  environment_type = "LINUX_CONTAINER"
  privileged_mode  = true

  buildspec_path  = file("./buildspecs/awsome-fastapi/build.yml")
  deployspec_path = file("./buildspecs/awsome-fastapi/deploy.yml")

  snyk_org_id = var.SNYK_ORG_ID
  snyk_token  = var.SNYK_TOKEN

  enable_dast        = var.ENABLE_DAST
  darkmoon_pro_url   = var.DARKMOON_PRO_URL
  darkmoon_pro_token = var.DARKMOON_PRO_TOKEN
  dast_target_url    = var.DAST_TARGET_URL
}
