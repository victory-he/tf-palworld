#!/bin/bash

# Palworld envs
MAX_PLAYERS=${MAX_PLAYERS}
PUBLIC_IP=${PUBLIC_IP}
SERVER_NAME=${SERVER_NAME}
SERVER_DESCRIPTION=${SERVER_DESCRIPTION}
SERVER_PASSWORD=${SERVER_PASSWORD}
ADMIN_PASSWORD=${ADMIN_PASSWORD}
DEDICATED_SERVER_NAME=${DEDICATED_SERVER_NAME}

# AWS envs
AWS_DEFAULT_REGION=${AWS_REGION}
S3_REGION=${S3_REGION}
EIP_ALLOC=${EIP_ALLOC}
S3_URI=${S3_URI}
S3_KEY=`aws s3 --region $S3_REGION ls $S3_URI/saves --recursive | sort | tail -n1 | awk '{ print $4 }'`

# Associate allocated EIP
TOKEN=`curl -X PUT "http://169.254.169.254/latest/api/token" -H "X-aws-ec2-metadata-token-ttl-seconds: 21600"`
INSTANCE_ID=$(curl -H "X-aws-ec2-metadata-token: $TOKEN" -v http://169.254.169.254/latest/meta-data/instance-id)
ASSOC_ID=$(aws ec2 describe-addresses --allocation-id=$EIP_ALLOC --query Addresses[].AssociationId --output text)
aws ec2 disassociate-address --association-id $ASSOC_ID
sleep 5
aws ec2 associate-address --instance-id $INSTANCE_ID --allocation-id $EIP_ALLOC --allow-reassociation

# Install cronie since Amazon Linux 2023 doesn't include a cron scheduler by default
yum update -y
yum install cronie -y
systemctl enable crond.service
systemctl start crond.service

# Install Docker
yum install -y docker
service docker start
systemctl enable docker
usermod -a -G docker ec2-user

# Install Docker Compose plugin
sudo curl -L https://github.com/docker/compose/releases/latest/download/docker-compose-$(uname -s)-$(uname -m) -o /usr/local/bin/docker-compose
sudo chmod +x /usr/local/bin/docker-compose

# Create Palworld server directories
mkdir -p /srv/palworld/game /srv/palworld/backups /srv/palworld/game/Pal/Saved/SaveGames/0/${DEDICATED_SERVER_NAME} /srv/palworld/game/Pal/Saved/Config/LinuxServer/
chmod 777 /srv/palworld/game

curl -o /srv/palworld/game/Pal/Saved/Config/LinuxServer/GameUserSettings.ini https://raw.githubusercontent.com/victory-he/tf-palworld/master/scripts/GameUserSettings.ini
sed -i "/^DedicatedServerName/c\DedicatedServerName=$DEDICATED_SERVER_NAME" /srv/palworld/game/Pal/Saved/Config/LinuxServer/GameUserSettings.ini

# Download backed up Palworld save
aws s3 --region $S3_REGION cp $S3_URI/$S3_KEY /pal_save.zip
tar -xvf /pal_save.zip
chown -R 1000:1000 /srv/palworld/game
# Clean up backup files
rm /pal_save.zip

# Create backup to S3 bucket script
cat > /srv/palworld/s3backup.sh << EOF
UPLOAD_BUCKET=$S3_URI/saves
S3_REGION=$S3_REGION
EOF
cat >> /srv/palworld/s3backup.sh << 'EOF'
tar -czvf /srv/palworld/backups/pal_save_$(date '+%Y%m%d%H%M').zip /srv/palworld/game/Pal/Saved/SaveGames/
UPLOAD_FILE="$(ls /srv/palworld/backups -tr | tail -1)"
aws s3 --region $S3_REGION cp /srv/palworld/backups/$UPLOAD_FILE $UPLOAD_BUCKET/
EOF
chmod +x /srv/palworld/s3backup.sh

# Schedule cronjob to execute S3 bucket script every 30 minutes
cat > /etc/cron.d/s3backupjob << EOF
SHELL=/bin/sh
*/30 * * * * root /srv/palworld/s3backup.sh
EOF
chmod 644 /etc/cron.d/s3backupjob

# Start the server
cat > /srv/palworld/palworld.env << EOF
ALWAYS_UPDATE_ON_START=true
MAX_PLAYERS=$MAX_PLAYERS
MULTITHREAD_ENABLED=true
COMMUNITY_SERVER=true
RCON_ENABLED=true
RCON_PORT=25575
PUBLIC_IP=$PUBLIC_IP
PUBLIC_PORT=8211
SERVER_NAME=$SERVER_NAME
SERVER_DESCRIPTION=$SERVER_DESCRIPTION
SERVER_PASSWORD=$SERVER_PASSWORD
ADMIN_PASSWORD=$ADMIN_PASSWORD
EOF

curl -o /srv/palworld/docker-compose.yaml https://raw.githubusercontent.com/victory-he/tf-palworld/master/docker-compose.yml
cd /srv/palworld
docker-compose up
sleep 5
CONTAINER=`docker ps -a | grep palworld-dedicated-server | awk '{print $1}'`
RCON_IP=`docker inspect -f "{{ .NetworkSettings.Gateway }}" $CONTAINER`
sed -i "/entrypoint/c\ \ \  entrypoint: ['/rcon', '-a', '$RCON_IP:25575', '-p', '$ADMIN_PASSWORD']" /srv/palworld/docker-compose.yaml
