
Terraform module for deploying [external-secrets](https://github.com/external-secrets/external-secrets), this enables to use AWS Secrets Manager and SSM Parameters inside a pre-existing EKS cluster.

## Usage

```hcl
module "external_secrets" {
  source = "easy-modules/external-secrets/easy"
  enabled = true
  cluster_name                     = "eks-prod-42"
  chart_name                       = "external-secrets"
  namespace                        = "external-secret-system"
  set_values                       = {}
}
```
## System architecture

![architecture](./images/architecture.png)

1. `ExternalSecrets` are added in the cluster (e.g., `kubectl apply -f external-secret-example.yml`)
2. Controller fetches `ExternalSecrets` using the Kubernetes API
3. Controller uses `ExternalSecrets` to fetch secret data from external providers (e.g, AWS Secrets Manager)
4. Controller upserts `Secrets`
5. `Pods` can access `Secrets` normally

## Add a SecretStore or ClusterSecretStore

Please check the documentation: https://external-secrets.io/v0.7.2/api/secretstore/

Please check the documentation: https://external-secrets.io/v0.7.2/api/clustersecretstore/

## Add a secret

Add your secret data to your backend. For example, AWS Secrets Manager:

```
aws secretsmanager create-secret --name hello-service/password --secret-string "1234"
```

AWS Parameter Store:

```
aws ssm put-parameter --name "/hello-service/password" --type "String" --value "1234"
```

and then create a `hello-service-external-secret.yml` file:

```yml
apiVersion: "kubernetes-client.io/v1"
kind: ExternalSecret
metadata:
  name: hello-service
spec:
  backendType: secretsManager
  # optional: specify role to assume when retrieving the data
  roleArn: arn:aws:iam::123456789012:role/test-role
  data:
    - key: hello-service/password
      name: password
  # optional: specify a template with any additional markup you would like added to the downstream Secret resource.
  # This template will be deep merged without mutating any existing fields. For example: you cannot override metadata.name.
  template:
    metadata:
      annotations:
        cat: cheese
      labels:
        dog: farfel
```

or

```yml
apiVersion: "kubernetes-client.io/v1"
kind: ExternalSecret
metadata:
  name: hello-service
spec:
  backendType: systemManager
  data:
    - key: /hello-service/password
      name: password
```

The following IAM policy allows a user or role to access parameters matching `prod-*`.

```json
{
  "Version": "2012-10-17",
  "Statement": [
    {
      "Effect": "Allow",
      "Action": "ssm:GetParameter",
      "Resource": "arn:aws:ssm:us-west-2:123456789012:parameter/prod-*"
    }
  ]
}
```

The IAM policy for Secrets Manager is similar ([see docs](https://docs.aws.amazon.com/mediaconnect/latest/ug/iam-policy-examples-asm-secrets.html)):

```json
{
  "Version": "2012-10-17",
  "Statement": [
    {
      "Effect": "Allow",
      "Action": [
        "secretsmanager:GetResourcePolicy",
        "secretsmanager:GetSecretValue",
        "secretsmanager:DescribeSecret",
        "secretsmanager:ListSecretVersionIds"
      ],
      "Resource": [
        "arn:aws:secretsmanager:us-west-2:111122223333:secret:aes128-1a2b3c",
        "arn:aws:secretsmanager:us-west-2:111122223333:secret:aes192-4D5e6F",
        "arn:aws:secretsmanager:us-west-2:111122223333:secret:aes256-7g8H9i"
      ]
    }
  ]
}
```

Save the file and run:

```sh
kubectl apply -f hello-service-external-secret.yml
```

Wait a few minutes and verify that the associated `Secret` has been created:

```sh
kubectl get secret hello-service -o=yaml
```

The `Secret` created by the controller should look like:

```yml
apiVersion: v1
kind: Secret
metadata:
  name: hello-service
  annotations:
    cat: cheese
  labels:
    dog: farfel
type: Opaque
data:
  password: MTIzNA==
```

### Create secrets of other types than opaque

You can override `ExternalSecret` type using `template`, for example:

```yaml
apiVersion: kubernetes-client.io/v1
kind: ExternalSecret
metadata:
  name: hello-docker
spec:
  backendType: systemManager
  template:
    type: kubernetes.io/dockerconfigjson
  data:
    - key: /hello-service/hello-docker
      name: .dockerconfigjson
```


## Backends

kubernetes-external-secrets supports AWS Secrets Manager, AWS System Manager, Hashicorp Vault, Azure Key Vault, Google Secret Manager and Alibaba Cloud KMS Secret Manager.

### AWS Secrets Manager

kubernetes-external-secrets supports both JSON objects ("Secret
key/value" in the AWS console) or strings ("Plaintext" in the AWS
console). Using JSON objects is useful when you need to atomically
update multiple values. For example, when rotating a client
certificate and private key.

When writing an ExternalSecret for a JSON object you must specify the
properties to use. For example, if we add our hello-service
credentials as a single JSON object:

```
aws secretsmanager create-secret --region us-west-2 --name hello-service/credentials --secret-string '{"username":"admin","password":"1234"}'
```

We can declare which properties we want from `hello-service/credentials`:

```yml
apiVersion: kubernetes-client.io/v1
kind: ExternalSecret
metadata:
  name: hello-service
spec:
  backendType: secretsManager
  # optional: specify role to assume when retrieving the data
  roleArn: arn:aws:iam::123456789012:role/test-role
  # optional: specify region
  region: us-east-1
  data:
    - key: hello-service/credentials
      name: password
      property: password
    - key: hello-service/credentials
      name: username
      property: username
    - key: hello-service/credentials
      name: password_previous
      # Version Stage in Secrets Manager
      versionStage: AWSPREVIOUS
      property: password
    - key: hello-service/credentials
      name: password_versioned
      # Version ID in Secrets Manager
      versionId: xxxxxxxx-xxxx-xxxx-xxxx-xxxxxxxxxxxx
      property: password
```

alternatively you can use `dataFrom` and get all the values from `hello-service/credentials`:

```yml
apiVersion: kubernetes-client.io/v1
kind: ExternalSecret
metadata:
  name: hello-service
spec:
  backendType: secretsManager
  # optional: specify role to assume when retrieving the data
  roleArn: arn:aws:iam::123456789012:role/test-role
  # optional: specify region
  region: us-east-1
  dataFrom:
    - hello-service/credentials
```

`data` and `dataFrom` can of course be combined, any naming conflicts will use the last defined, with `data` overriding `dataFrom`:

```yml
apiVersion: kubernetes-client.io/v1
kind: ExternalSecret
metadata:
  name: hello-service
spec:
  backendType: secretsManager
  # optional: specify role to assume when retrieving the data
  roleArn: arn:aws:iam::123456789012:role/test-role
  # optional: specify region
  region: us-east-1
  dataFrom:
    - hello-service/credentials
  data:
    - key: hello-service/migration-credentials
      name: password
      property: password
```

### AWS SSM Parameter Store

You can scrape values from SSM Parameter Store individually or by providing a path to fetch all keys inside.

Additionally you can also scrape all sub paths (child paths) if you need to. The default is not to scrape child paths.

```yml
apiVersion: kubernetes-client.io/v1
kind: ExternalSecret
metadata:
  name: hello-service
spec:
  backendType: systemManager
  # optional: specify role to assume when retrieving the data
  roleArn: arn:aws:iam::123456789012:role/test-role
  # optional: specify region
  region: us-east-1
  data:
    - key: /foo/name
      name: fooName
    - path: /extra-people/
      recursive: false
```

<!-- BEGINNING OF PRE-COMMIT-TERRAFORM DOCS HOOK -->
## Requirements

| Name | Version |
|------|---------|
| <a name="requirement_terraform"></a> [terraform](#requirement\_terraform) | >= 1.0.0 |
| <a name="requirement_aws"></a> [aws](#requirement\_aws) | 5.8.0 |
| <a name="requirement_helm"></a> [helm](#requirement\_helm) | 2.10.1 |
| <a name="requirement_kubernetes"></a> [kubernetes](#requirement\_kubernetes) | 2.22.0 |

## Providers

| Name | Version |
|------|---------|
| <a name="provider_aws"></a> [aws](#provider\_aws) | 5.8.0 |
| <a name="provider_helm"></a> [helm](#provider\_helm) | 2.10.1 |
| <a name="provider_kubernetes"></a> [kubernetes](#provider\_kubernetes) | 2.22.0 |

## Modules

No modules.

## Resources

| Name | Type |
|------|------|
| [aws_iam_policy.iam_policy](https://registry.terraform.io/providers/hashicorp/aws/5.8.0/docs/resources/iam_policy) | resource |
| [aws_iam_role.iam_role](https://registry.terraform.io/providers/hashicorp/aws/5.8.0/docs/resources/iam_role) | resource |
| [aws_iam_role_policy_attachment.external_secret_attach_policy](https://registry.terraform.io/providers/hashicorp/aws/5.8.0/docs/resources/iam_role_policy_attachment) | resource |
| [helm_release.external_secrets_system](https://registry.terraform.io/providers/hashicorp/helm/2.10.1/docs/resources/release) | resource |
| [kubernetes_service_account_v1.external_secrets_sa](https://registry.terraform.io/providers/hashicorp/kubernetes/2.22.0/docs/resources/service_account_v1) | resource |
| [aws_caller_identity.current](https://registry.terraform.io/providers/hashicorp/aws/5.8.0/docs/data-sources/caller_identity) | data source |
| [aws_eks_cluster.eks](https://registry.terraform.io/providers/hashicorp/aws/5.8.0/docs/data-sources/eks_cluster) | data source |
| [aws_iam_policy_document.external_secret_assume_role_policy](https://registry.terraform.io/providers/hashicorp/aws/5.8.0/docs/data-sources/iam_policy_document) | data source |
| [aws_iam_policy_document.external_secret_policy](https://registry.terraform.io/providers/hashicorp/aws/5.8.0/docs/data-sources/iam_policy_document) | data source |
| [aws_partition.current](https://registry.terraform.io/providers/hashicorp/aws/5.8.0/docs/data-sources/partition) | data source |

## Inputs

| Name | Description | Type | Default | Required |
|------|-------------|------|---------|:--------:|
| <a name="input_chart_name"></a> [chart\_name](#input\_chart\_name) | External Secrets chart name | `string` | `"external-secrets"` | no |
| <a name="input_chart_version"></a> [chart\_version](#input\_chart\_version) | External Secrets chart version | `string` | `"0.9.1"` | no |
| <a name="input_cleanup_on_fail"></a> [cleanup\_on\_fail](#input\_cleanup\_on\_fail) | Cleanup on fail | `bool` | `true` | no |
| <a name="input_cluster_name"></a> [cluster\_name](#input\_cluster\_name) | Cluster name | `string` | `"ecomm-dev"` | no |
| <a name="input_create_namespace"></a> [create\_namespace](#input\_create\_namespace) | Create namespace | `bool` | `true` | no |
| <a name="input_description"></a> [description](#input\_description) | External Secrets chart description | `string` | `"External Secrets Operator is a Kubernetes operator that integrates external secret management"` | no |
| <a name="input_max_history"></a> [max\_history](#input\_max\_history) | Max history for External Secrets | `number` | `5` | no |
| <a name="input_namespace"></a> [namespace](#input\_namespace) | External namespace | `string` | `"external-secret-system"` | no |
| <a name="input_repository"></a> [repository](#input\_repository) | External Secrets chart repository | `string` | `"https://charts.external-secrets.io"` | no |
| <a name="input_role_tags"></a> [role\_tags](#input\_role\_tags) | Role tags | `map(string)` | `{}` | no |
| <a name="input_set_values"></a> [set\_values](#input\_set\_values) | External Secrets values | `map(any)` | <pre>{<br>  "values": {}<br>}</pre> | no |
| <a name="input_wait"></a> [wait](#input\_wait) | Wait for External Secrets to be ready | `bool` | `true` | no |

## Outputs

| Name | Description |
|------|-------------|
| <a name="output_external_secrets_system_chart"></a> [external\_secrets\_system\_chart](#output\_external\_secrets\_system\_chart) | The chart of the external secrets system |
| <a name="output_external_secrets_system_name"></a> [external\_secrets\_system\_name](#output\_external\_secrets\_system\_name) | The name of the external secrets system |
| <a name="output_external_secrets_system_namespace"></a> [external\_secrets\_system\_namespace](#output\_external\_secrets\_system\_namespace) | The namespace of the external secrets system |
| <a name="output_external_secrets_system_version"></a> [external\_secrets\_system\_version](#output\_external\_secrets\_system\_version) | The version of the external secrets system |
| <a name="output_repository"></a> [repository](#output\_repository) | The repository of the external secrets system |
<!-- END OF PRE-COMMIT-TERRAFORM DOCS HOOK -->
