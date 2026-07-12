#!/bin/bash
set -eux

dnf update -y
dnf install -y java-21-amazon-corretto git
dnf install -y docker
systemctl enable --now docker

wget -O /etc/yum.repos.d/jenkins.repo https://pkg.jenkins.io/redhat-stable/jenkins.repo
rpm --import https://pkg.jenkins.io/redhat-stable/jenkins.io-2023.key
dnf install -y jenkins
usermod -aG docker jenkins

# Trust github.com so Jenkins can clone over SSH.
mkdir -p /var/lib/jenkins/.ssh
ssh-keyscan -t ed25519,rsa github.com > /var/lib/jenkins/.ssh/known_hosts 2>/dev/null
chown -R jenkins:jenkins /var/lib/jenkins/.ssh
chmod 700 /var/lib/jenkins/.ssh
chmod 644 /var/lib/jenkins/.ssh/known_hosts

systemctl enable --now jenkins
echo "user-data-complete" > /var/log/jenkins-userdata-done.txt
