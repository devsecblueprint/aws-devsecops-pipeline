# Pipeline Default IAM Roles
resource "aws_iam_role" "pipeline_role" {
  name = "${var.repo_name}-role"

  assume_role_policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Action = "sts:AssumeRole"
        Effect = "Allow"
        Principal = {
          Service = "codepipeline.amazonaws.com"
        }
      }
    ]
  })
}

resource "aws_iam_policy" "pipeline_policy" {
  name        = "${var.repo_name}-role-policy"
  description = "IAM policy for CodePipeline"

  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Effect = "Allow"
        Action = [
          "s3:*",
          "codebuild:*",
          "iam:PassRole",
          "secretsmanager:GetSecretValue",
          "codestar-connections:UseConnection",
          "events:PutRule",
          "events:PutTargets",
          "events:DeleteRule",
          "events:RemoveTargets",
          "events:DescribeRule"
        ]
        Resource = "*"
      }
    ]
  })
}

resource "aws_iam_role_policy_attachment" "pipeline_policy_attach" {
  role       = aws_iam_role.pipeline_role.name
  policy_arn = aws_iam_policy.pipeline_policy.arn
}

resource "aws_iam_policy" "eks_deploy_policy" {
  name = "${var.repo_name}-ekspolicy"

  policy = jsonencode({
    Version = "2012-10-17",
    Statement = [
      {
        Effect = "Allow",
        Action = [
          "eks:DescribeCluster",
          "eks:UpdateKubeconfig"
        ],
        Resource = "*"
      },
      {
        Effect = "Allow",
        Action = [
          "ecr:GetAuthorizationToken",
          "ecr:BatchCheckLayerAvailability",
          "ecr:PutImage",
          "ecr:CompleteLayerUpload",
          "ecr:BatchGetImage"
        ],
        Resource = "*"
      },
      {
        "Effect" : "Allow",
        "Action" : [
          "eks:DescribeCluster",
          "eks:ListClusters",
          "eks:AccessKubernetesApi"
        ],
        "Resource" : var.eks_cluster_arn
      },
      {
        Effect = "Allow",
        Action = [
          "sts:AssumeRole"
        ],
        Resource = "*"
      }
    ]
  })
}

resource "aws_iam_role_policy_attachment" "eks_pipeline_attach_role" {
  role       = aws_iam_role.pipeline_role.name
  policy_arn = aws_iam_policy.eks_deploy_policy.arn
}


# Codebuild Default Role
resource "aws_iam_role" "codebuild_role" {
  name = "${var.repo_name}-codebuild-role"

  assume_role_policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Effect = "Allow"
        Principal = {
          Service = "codebuild.amazonaws.com"
        }
        Action = "sts:AssumeRole"
      }
    ]
  })
}

resource "aws_iam_policy" "codebuild_policy" {
  name        = "${var.repo_name}-codebuild-policy"
  description = "IAM policy for AWS CodeBuild to access required resources"

  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Effect = "Allow"
        Action = [
          "logs:CreateLogGroup",
          "logs:CreateLogStream",
          "logs:PutLogEvents"
        ]
        Resource = "arn:aws:logs:*:*:*"
      },
      {
        Effect = "Allow"
        Action = [
          "ssm:GetParameter",
          "ssm:GetParameters"
        ]
        Resource = "*"
      },
      {
        Effect = "Allow"
        Action = [
          "s3:GetObject",
          "s3:PutObject",
          "s3:ListBucket"
        ]
        Resource = [
          "${var.s3_bucket_arn}",
          "${var.s3_bucket_arn}/*"
        ]
      },
      {
        Effect = "Allow"
        Action = [
          "codebuild:CreateReportGroup",
          "codebuild:CreateReport",
          "codebuild:UpdateReport"
        ]
        Resource = "*"
      },
      {
        Effect = "Allow"
        Action = [
          "ecr:GetDownloadUrlForLayer",
          "ecr:BatchGetImage",
          "ecr:GetAuthorizationToken",
          "ecr:InitiateLayerUpload",
          "ecr:UploadLayerPart",
          "ecr:CompleteLayerUpload",
          "ecr:BatchCheckLayerAvailability",
          "ecr:PutImage"
        ]
        Resource = "*"
      }
    ]
  })
}

resource "aws_iam_role_policy_attachment" "codebuild_policy_attachment" {
  role       = aws_iam_role.codebuild_role.name
  policy_arn = aws_iam_policy.codebuild_policy.arn
}

resource "aws_iam_role_policy_attachment" "eks_buildprj_attach_role" {
  role       = aws_iam_role.codebuild_role.name
  policy_arn = aws_iam_policy.eks_deploy_policy.arn
}

# Pipeline
resource "aws_codepipeline" "pipeline" {
  name          = var.repo_name
  role_arn      = aws_iam_role.pipeline_role.arn
  pipeline_type = "V2"

  artifact_store {
    type     = "S3"
    location = var.s3_bucket_name
  }

  # Source Stage
  stage {
    name = "Source"

    action {
      name             = "Source"
      category         = "Source"
      owner            = "AWS"
      provider         = "CodeStarSourceConnection"
      version          = "1"
      output_artifacts = ["SourceArtifact"]

      configuration = {
        ConnectionArn    = var.github_connection_arn
        FullRepositoryId = var.repository_id
        BranchName       = var.branch_name
      }
    }
  }

  # Build Stage
  stage {
    name = "Build"

    action {
      name             = "Build"
      category         = "Build"
      owner            = "AWS"
      provider         = "CodeBuild"
      version          = "1"
      input_artifacts  = ["SourceArtifact"]
      output_artifacts = ["BuildArtifact"]

      configuration = {
        ProjectName = aws_codebuild_project.build_project.name
      }
    }
  }

  # Static Analysis Stage
  stage {
    name = "Test"

    action {
      name            = "FormatCheck"
      category        = "Test"
      owner           = "AWS"
      provider        = "CodeBuild"
      version         = "1"
      input_artifacts = ["SourceArtifact"]
      run_order       = 1

      configuration = {
        ProjectName = aws_codebuild_project.format_check_project.name
      }
    }

    action {
      name            = "LintCheck"
      category        = "Test"
      owner           = "AWS"
      provider        = "CodeBuild"
      version         = "1"
      input_artifacts = ["SourceArtifact"]
      run_order       = 1

      configuration = {
        ProjectName = aws_codebuild_project.lint_check_project.name
      }
    }

    action {
      name            = "RunUnitTests"
      category        = "Test"
      owner           = "AWS"
      provider        = "CodeBuild"
      version         = "1"
      input_artifacts = ["SourceArtifact"]
      run_order       = 2

      configuration = {
        ProjectName = aws_codebuild_project.unittest_project.name
      }
    }

    action {
      name            = "SnykSecurityScan"
      category        = "Test"
      owner           = "AWS"
      provider        = "CodeBuild"
      version         = "1"
      input_artifacts = ["SourceArtifact"]
      run_order       = 3

      configuration = {
        ProjectName = aws_codebuild_project.static_analysis_project.name
      }
    }

    action {
      name            = "ContainerSecurityScan"
      category        = "Test"
      owner           = "AWS"
      provider        = "CodeBuild"
      version         = "1"
      input_artifacts = ["SourceArtifact"]
      run_order       = 3

      configuration = {
        ProjectName = aws_codebuild_project.oss_scanning_project.name
      }
    }
  }

  # Open Source Scanning Stage

  stage {
    name = "Deploy"

    action {
      name            = "DeployToEKS"
      category        = "Build" # Using CodeBuild for EKS deployments
      owner           = "AWS"
      provider        = "CodeBuild"
      version         = "1"
      input_artifacts = ["BuildArtifact"]
      configuration = {
        ProjectName = aws_codebuild_project.deploy_project.name
      }
    }
  }

  # Runtime Pentest Stage (optional): attacks the app that the Deploy stage just shipped
  dynamic "stage" {
    for_each = var.enable_dast ? [1] : []

    content {
      name = "RuntimePentest"

      action {
        name            = "DarkmoonRuntimePentest"
        category        = "Test"
        owner           = "AWS"
        provider        = "CodeBuild"
        version         = "1"
        input_artifacts = ["SourceArtifact"]

        configuration = {
          ProjectName = aws_codebuild_project.dast_project[0].name
        }
      }
    }
  }

  trigger {
    provider_type = "CodeStarSourceConnection"
    git_configuration {
      source_action_name = "Source"
      push {
        branches {
          includes = ["main"]
        }
      }
    }
  }
}

# CodeBuild for Build
resource "aws_codebuild_project" "build_project" {
  name         = "${var.repo_name}-build-project"
  service_role = aws_iam_role.codebuild_role.arn

  environment {
    compute_type    = var.compute_type
    image           = var.build_image
    type            = var.environment_type
    privileged_mode = var.privileged_mode

    environment_variable {
      name  = "IMAGE_REPO_NAME"
      value = aws_ecr_repository.this.name
    }
  }

  source {
    type      = "NO_SOURCE"
    buildspec = var.buildspec_path
  }

  artifacts {
    type     = "S3"
    location = var.s3_bucket_name
  }
}

resource "aws_codebuild_project" "format_check_project" {
  name         = "${var.repo_name}-formatcheck-project"
  service_role = aws_iam_role.codebuild_role.arn

  environment {
    compute_type    = var.compute_type
    image           = var.build_image
    type            = var.environment_type
    privileged_mode = var.privileged_mode

    environment_variable {
      name  = "IMAGE_REPO_NAME"
      value = aws_ecr_repository.this.name
    }
  }

  source {
    type      = "NO_SOURCE"
    buildspec = file("${path.module}/buildspecs/formatcheck.yml")
  }

  artifacts {
    type     = "S3"
    location = var.s3_bucket_name
  }
}

resource "aws_codebuild_project" "unittest_project" {
  name         = "${var.repo_name}-unittest-project"
  service_role = aws_iam_role.codebuild_role.arn

  environment {
    compute_type    = var.compute_type
    image           = var.build_image
    type            = var.environment_type
    privileged_mode = var.privileged_mode

    environment_variable {
      name  = "IMAGE_REPO_NAME"
      value = aws_ecr_repository.this.name
    }
  }

  source {
    type      = "NO_SOURCE"
    buildspec = file("${path.module}/buildspecs/unittests.yml")
  }

  artifacts {
    type     = "S3"
    location = var.s3_bucket_name
  }
}


resource "aws_codebuild_project" "lint_check_project" {
  name         = "${var.repo_name}-lintcheck-project"
  service_role = aws_iam_role.codebuild_role.arn

  environment {
    compute_type    = var.compute_type
    image           = var.build_image
    type            = var.environment_type
    privileged_mode = var.privileged_mode

    environment_variable {
      name  = "IMAGE_REPO_NAME"
      value = aws_ecr_repository.this.name
    }
  }

  source {
    type      = "NO_SOURCE"
    buildspec = file("${path.module}/buildspecs/lintcheck.yml")
  }

  artifacts {
    type     = "S3"
    location = var.s3_bucket_name
  }
}

resource "aws_codebuild_project" "deploy_project" {
  name         = "${var.repo_name}-deploy-prj"
  service_role = aws_iam_role.codebuild_role.arn

  environment {
    compute_type    = var.compute_type
    image           = var.build_image
    type            = var.environment_type
    privileged_mode = var.privileged_mode

    environment_variable {
      name  = "CLUSTER_NAME"
      value = var.eks_cluster_name
    }
  }

  source {
    type      = "CODEPIPELINE"
    buildspec = var.deployspec_path
  }

  artifacts {
    type = "CODEPIPELINE"
  }
}


# CodeBuild for Static Analysis
resource "aws_codebuild_project" "static_analysis_project" {
  name         = "${var.repo_name}-static-analysis-project"
  service_role = aws_iam_role.codebuild_role.arn

  environment {
    compute_type    = var.compute_type
    image           = var.build_image
    type            = var.environment_type
    privileged_mode = var.privileged_mode

    environment_variable {
      name  = "SNYK_TOKEN"
      value = aws_ssm_parameter.snyk_token.name
      type  = "PARAMETER_STORE"
    }

    environment_variable {
      name  = "SNYK_ORG_ID"
      value = aws_ssm_parameter.snyk_org_id.name
      type  = "PARAMETER_STORE"
    }
  }

  source {
    type      = "NO_SOURCE"
    buildspec = file("${path.module}/buildspecs/sastscanning.yml")
  }

  artifacts {
    type     = "S3"
    location = var.s3_bucket_name
  }

}

# CodeBuild for OSS Dependency Scanning
resource "aws_codebuild_project" "oss_scanning_project" {
  name         = "${var.repo_name}-oss-scanning-project"
  service_role = aws_iam_role.codebuild_role.arn

  environment {
    compute_type    = var.compute_type
    image           = var.build_image
    type            = var.environment_type
    privileged_mode = var.privileged_mode

    environment_variable {
      name  = "IMAGE_REPO_NAME"
      value = aws_ecr_repository.this.name
    }
  }

  source {
    type      = "NO_SOURCE"
    buildspec = file("${path.module}/buildspecs/ossdepscan.yml")
  }

  artifacts {
    type     = "S3"
    location = var.s3_bucket_name
  }
}

# CodeBuild for Runtime Pentest (DAST)
resource "aws_codebuild_project" "dast_project" {
  count = var.enable_dast ? 1 : 0

  name         = "${var.repo_name}-dast-project"
  service_role = aws_iam_role.codebuild_role.arn

  environment {
    compute_type = var.compute_type
    image        = var.build_image
    type         = var.environment_type

    environment_variable {
      name  = "DARKMOON_PRO_URL"
      value = aws_ssm_parameter.darkmoon_pro_url[0].name
      type  = "PARAMETER_STORE"
    }

    environment_variable {
      name  = "DARKMOON_PRO_TOKEN"
      value = aws_ssm_parameter.darkmoon_pro_token[0].name
      type  = "PARAMETER_STORE"
    }

    environment_variable {
      name  = "TARGET_URL"
      value = var.dast_target_url
    }
  }

  source {
    type      = "NO_SOURCE"
    buildspec = file("${path.module}/buildspecs/dastscanning.yml")
  }

  artifacts {
    type     = "S3"
    location = var.s3_bucket_name
  }
}
