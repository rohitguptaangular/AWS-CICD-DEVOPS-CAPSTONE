#!/bin/bash
# Runs on first boot (EC2 user-data), as root. Installs Jenkins + Docker.
# Every step here encodes a lesson learned the hard way in Sprint 1.
set -eux

# --- System update ---
dnf update -y

# --- Java 21 (current Jenkins LTS needs 21+; Java 17 crash-loops) + git ---
dnf install -y java-21-amazon-corretto git

# --- Docker (Jenkins builds images with it) ---
dnf install -y docker
systemctl enable --now docker

# --- Jenkins (official stable repo) ---
wget -O /etc/yum.repos.d/jenkins.repo https://pkg.jenkins.io/redhat-stable/jenkins.repo
rpm --import https://pkg.jenkins.io/redhat-stable/jenkins.io-2023.key
dnf install -y jenkins

# Let the jenkins user run docker without sudo
usermod -aG docker jenkins

# --- Seed GitHub host keys so Jenkins can clone over SSH ---
# (Sprint 1: clone failed with "No ED25519 host key known" until we did this.)
mkdir -p /var/lib/jenkins/.ssh
ssh-keyscan -t ed25519,rsa github.com > /var/lib/jenkins/.ssh/known_hosts 2>/dev/null
chown -R jenkins:jenkins /var/lib/jenkins/.ssh
chmod 700 /var/lib/jenkins/.ssh
chmod 644 /var/lib/jenkins/.ssh/known_hosts

# --- Start Jenkins ---
systemctl enable --now jenkins

# Marker so we can confirm from SSH that user-data finished
echo "user-data-complete" > /var/log/jenkins-userdata-done.txt
