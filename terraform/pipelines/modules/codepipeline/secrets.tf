# SSM Parameters
resource "aws_ssm_parameter" "snyk_token" {
  name  = "/credentials/snyk/auth_token"
  type  = "SecureString"
  value = var.snyk_token
}

resource "aws_ssm_parameter" "snyk_org_id" {
  name  = "/credentials/snyk/org_id"
  type  = "String"
  value = var.snyk_org_id
}

resource "aws_ssm_parameter" "darkmoon_pro_url" {
  count = var.enable_dast ? 1 : 0

  name  = "/credentials/darkmoon/pro_url"
  type  = "String"
  value = var.darkmoon_pro_url
}

resource "aws_ssm_parameter" "darkmoon_pro_token" {
  count = var.enable_dast ? 1 : 0

  name  = "/credentials/darkmoon/pro_token"
  type  = "SecureString"
  value = var.darkmoon_pro_token
}
