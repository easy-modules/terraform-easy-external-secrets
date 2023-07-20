data "aws_caller_identity" "current" {}
data "aws_partition" "current" {}
data "aws_eks_cluster" "eks" {
  name = var.cluster_name
}

locals {
  account_id = data.aws_caller_identity.current.account_id
  partition  = data.aws_partition.current.partition
  tags = {
    Terraform = "true"
    ManagedBy = "Terraform"
  }
}

locals {
  k8s_service_account_name = "external-secrets-service-account"
  eks_oidc_issuer          = trimprefix(data.aws_eks_cluster.eks.identity[0].oidc[0].issuer, "https://")
}

#==============================================================================
# EXTERNAL SECRET IAM ROLES
#==============================================================================
data "aws_iam_policy_document" "external_secret_assume_role_policy" {
  statement {
    actions = ["sts:AssumeRoleWithWebIdentity"]
    effect  = "Allow"
    principals {
      type        = "Federated"
      identifiers = ["arn:${local.partition}:iam::${local.account_id}:oidc-provider/${local.eks_oidc_issuer}"]
    }
    condition {
      test     = "StringEquals"
      variable = "${local.eks_oidc_issuer}:sub"
      values   = ["system:serviceaccount:${var.namespace}:${local.k8s_service_account_name}"]
    }
  }
}

data "aws_iam_policy_document" "external_secret_policy" {
  statement {
    actions   = ["secretsmanager:*", "kms:*", "ssm:*"]
    effect    = "Allow"
    resources = ["*"]
  }
}

resource "aws_iam_role" "iam_role" {
  name               = format("%s-role", var.chart_name)
  description        = "Role for External Secrets"
  assume_role_policy = data.aws_iam_policy_document.external_secret_assume_role_policy.json
  tags               = merge(local.tags, var.role_tags)
}

resource "aws_iam_policy" "iam_policy" {
  name        = format("%s-policy", var.chart_name)
  description = "Policy for External Secrets"
  policy      = data.aws_iam_policy_document.external_secret_policy.json
}

resource "aws_iam_role_policy_attachment" "external_secret_attach_policy" {
  role       = aws_iam_role.iam_role.name
  policy_arn = aws_iam_policy.iam_policy.arn
}

#==============================================================================
# HELM CHART
#==============================================================================

resource "helm_release" "external_secrets_system" {
  name             = var.chart_name
  description      = var.description
  repository       = var.repository
  version          = var.chart_version
  chart            = var.chart_name
  namespace        = var.namespace
  create_namespace = var.create_namespace
  wait             = var.wait
  cleanup_on_fail  = var.cleanup_on_fail
  max_history      = var.max_history

  set {
    name  = "serviceAccount.annotations.eks\\.amazonaws\\.com/role-arn"
    value = aws_iam_role.iam_role.arn
  }

  dynamic "set" {
    for_each = try({ for key, value in var.set_values.values : key => value }, {})
    content {
      name  = set.key != null ? set.key : ""
      value = set.value != null ? set.value : ""
    }
  }
}

#==============================================================================
# KUBERNETES SERVICE ACCOUNT
#==============================================================================

resource "kubernetes_service_account_v1" "external_secrets_sa" {
  depends_on = [helm_release.external_secrets_system]
  metadata {
    name      = local.k8s_service_account_name
    namespace = var.namespace
    annotations = {
      "eks.amazonaws.com/role-arn" = aws_iam_role.iam_role.arn
    }
  }
}
