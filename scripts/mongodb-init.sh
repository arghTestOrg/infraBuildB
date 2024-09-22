#!/bin/bash

# Update and upgrade system packages
#apt-get update -y
#apt-get upgrade -y

# Install packages
sudo apt-get install jq gnupg curl -y
sudo snap install aws-cli --classic

# Install MongoDB
sudo curl -fsSL https://pgp.mongodb.com/server-7.0.asc | sudo gpg -o /usr/share/keyrings/mongodb-server-7.0.gpg --dearmor
sudo echo "deb [ arch=amd64,arm64 signed-by=/usr/share/keyrings/mongodb-server-7.0.gpg] https://repo.mongodb.org/apt/ubuntu jammy/mongodb-org/7.0 multiverse" | sudo tee /etc/apt/sources.list.d/mongodb-org-7.0.list
sudo apt-get update
sudo systemctl daemon-reload
sudo apt-get install -y mongodb-org

# Get the private IP and today date of the instance
PRIVATE_IP="$(hostname -I | cut -f1 -d' ')"
BACKUP_DATE=$(date +"%Y-%m-%d")
echo $PRIVATE_IP

# Modify MongoDB configuration to bind to the private IP
#sudo sed -i "s/^bindIp: .*/bindIp: $PRIVATE_IP/" /etc/mongod.conf
sudo sed -i "s/^\(\s*bindIp:\s*\).*/\1${PRIVATE_IP}/" /etc/mongod.conf

# Restart cron service to ensure the cron job is registered
sudo systemctl restart cron

# Restart MongoDB service to apply the new configuration
sudo systemctl restart mongod
sleep 60

# Set up a daily cron job to back up MongoDB to S3
echo "0 0 * * * /usr/bin/mongodump --archive --gzip --out /tmp/mongo_backup && \
/usr/local/bin/aws s3 cp /tmp/mongo_backup s3://mongo-bkup-cron/mongodb-backup-\$(date +\\%F).gz > /var/log/mongo_backup.log 2>&1" | crontab -

# Retrieve credentials from AWS Secrets Manager
ADMIN_CREDENTIALS=$(aws secretsmanager get-secret-value --secret-id mongodb_admin_credentials --query SecretString --output text)
ADMIN_USERNAME=$(echo "$ADMIN_CREDENTIALS" | jq -r '.username')
ADMIN_PASSWORD=$(echo "$ADMIN_CREDENTIALS" | jq -r '.password')

APP_CREDENTIALS=$(aws secretsmanager get-secret-value --secret-id mongodb_app_credentials --query SecretString --output text)
APP_USERNAME=$(echo "$APP_CREDENTIALS" | jq -r '.username')
APP_PASSWORD=$(echo "$APP_CREDENTIALS" | jq -r '.password')

# Create MongoDB admin user using mongosh heredoc
mongosh $PRIVATE_IP <<EOF
db.createUser({
  user: "$ADMIN_USERNAME",
  pwd: "$ADMIN_PASSWORD",
  roles: [
    { role: "userAdminAnyDatabase", db: "admin" },
    { role: "dbAdminAnyDatabase", db: "admin" },
    { role: "readWriteAnyDatabase", db: "admin" },
    { role: "clusterAdmin", db: "admin" }
  ]
})
db.createUser({
  user: "$APP_USERNAME",
  pwd: "$APP_PASSWORD",
  roles: [
    { role: "readWrite", db: "customers" }
  ]
})
exit
EOF

echo "MongoDB setup and configuration complete."

  # Restart server with auth enabled
  # edit the Mongodb file with security:
  #                               authorization: enabled
  # sudo systemctl start --noblock mongod
  # Set correct permissions for /tmp
  # - chmod 1777 /tmp