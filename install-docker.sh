#!/bin/bash

set -e

echo "🔄 Updating system packages..."
sudo apt update && sudo apt upgrade -y

echo "📦 Installing required packages..."
sudo apt install -y apt-transport-https ca-certificates curl software-properties-common git

echo "🔑 Adding Docker's GPG key..."
curl -fsSL https://download.docker.com/linux/debian/gpg | sudo gpg --dearmor -o /usr/share/keyrings/docker-archive-keyring.gpg

echo "📁 Adding Docker repository..."
echo "deb [arch=$(dpkg --print-architecture) signed-by=/usr/share/keyrings/docker-archive-keyring.gpg] https://download.docker.com/linux/debian $(lsb_release -cs) stable" | sudo tee /etc/apt/sources.list.d/docker.list > /dev/null

echo "🔄 Updating package list after adding Docker repo..."
sudo apt update

echo "🐳 Installing Docker components..."
sudo apt install -y docker-ce docker-ce-cli containerd.io apparmor

echo "🧩 Installing Docker Compose plugin..."
sudo apt install -y docker-compose-plugin

echo "✅ Verifying Docker installation..."
docker --version

echo "🚀 Enabling Docker service..."
sudo systemctl start docker
sudo systemctl enable docker

echo "🎉 Installation complete!"
