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

# Start Jenkins before the provisioning tools below: this script runs under
# `set -e`, so a failure further down must not leave Jenkins installed but dead.
systemctl enable --now jenkins

# Provisioning tools the infra pipeline runs (Terraform + Ansible).
# ansible-core comes from the AL2023 repo, not pip: python3 here has no pip
# module, and a pip install would land in /usr/local/bin, off Jenkins' PATH.
dnf install -y dnf-plugins-core
dnf config-manager --add-repo https://rpm.releases.hashicorp.com/AmazonLinux/hashicorp.repo
dnf install -y terraform
dnf install -y ansible-core

echo "user-data-complete" > /var/log/jenkins-userdata-done.txt
