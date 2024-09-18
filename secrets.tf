# Create a secret for the MongoDB administrative user
resource "aws_secretsmanager_secret" "mongodb_admin_secret" {
  name        = "mongodb_admin_credentials"
  description = "Admin credentials for MongoDB"
  # to force deletion asap in order for terraform destroy to work
  recovery_window_in_days = 0
}

resource "aws_secretsmanager_secret_version" "mongodb_admin_secret_version" {
  secret_id = aws_secretsmanager_secret.mongodb_admin_secret.id
  secret_string = jsonencode({
    username = "adminUser"
    password = "W!zadry2024"
  })
}

# Create a secret for the MongoDB application user
resource "aws_secretsmanager_secret" "mongodb_app_secret" {
  name        = "mongodb_app_credentials"
  description = "Application user credentials for MongoDB"
  # to force deletion asap in order for terraform destroy to work
  recovery_window_in_days = 0
}

resource "aws_secretsmanager_secret_version" "mongodb_app_secret_version" {
  secret_id = aws_secretsmanager_secret.mongodb_app_secret.id
  secret_string = jsonencode({
    username = "appUser"
    password = "W!zadry2024"
  })
}


#Policy

resource "aws_iam_policy" "ec2_secrets_policy" {
  name        = "EC2SecretsPolicy"
  description = "Policy for EC2 to access MongoDB credentials in Secrets Manager"

  policy = <<EOF
{
  "Version": "2012-10-17",
  "Statement": [
    {
      "Effect": "Allow",
      "Action": [
        "secretsmanager:GetSecretValue"
      ],
      "Resource": [
        "${aws_secretsmanager_secret.mongodb_admin_secret.arn}",
        "${aws_secretsmanager_secret.mongodb_app_secret.arn}"
      ]
    }
  ]
}
EOF
}

resource "aws_iam_role_policy_attachment" "ec2_secrets_policy_attach" {
  role       = aws_iam_role.ec2_role.name
  policy_arn = aws_iam_policy.ec2_secrets_policy.arn
}