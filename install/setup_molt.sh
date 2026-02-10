#!/bin/bash
# Moltbot (formerly Clawdbot) Setup Script for Rocky OS
# Date: February 1, 2026

set -e

# 1. Colors for output
GREEN='\033[0;32m'
BLUE='\033[0;34m'
NC='\033[0m'

echo -e "${BLUE}Starting Moltbot installation on Rocky OS...${NC}"

# 2. Install Docker if not present
if ! [ -x "$(command -v docker)" ]; then
    echo -e "${BLUE}Installing Docker Engine...${NC}"
    sudo dnf install -y dnf-utils
    sudo dnf config-manager --add-repo https://download.docker.com/linux/centos/docker-ce.repo
    sudo dnf install -y docker-ce docker-ce-cli containerd.io docker-compose-plugin
    sudo systemctl enable --now docker
    sudo usermod -aG docker $USER
    echo -e "${GREEN}Docker installed. Note: You may need to log out/in after the script finishes for group changes.${NC}"
else
    echo -e "${GREEN}Docker already installed. Skipping.${NC}"
fi

# 3. Create the 'molt' folder structure
echo -e "${BLUE}Creating directory: ~/molt${NC}"
mkdir -p ~/molt/workspace
mkdir -p ~/molt/config
sudo chown -R 1000:1000 ~/molt

# 4. Create the docker-compose.yml
echo -e "${BLUE}Generating docker-compose.yml...${NC}"
cat <<EOF > ~/molt/docker-compose.yml
services:
  moltbot:
    image: moltbot/moltbot:latest
    container_name: moltbot
    restart: unless-stopped
    ports:
      - "18789:18789"
    environment:
      - OPENROUTER_API_KEY=\${OPENROUTER_API_KEY}
    volumes:
      - ./config:/home/node/.moltbot
      - ./workspace:/app/workspace
    deploy:
      resources:
        limits:
          cpus: '8.0'
          memory: 32G
EOF

echo -e "${GREEN}Setup complete!${NC}"
echo -e "--------------------------------------------------------"
echo -e "To start Moltbot, run the following commands:"
echo -e "${BLUE}cd ~/molt${NC}"
echo -e "${BLUE}export OPENROUTER_API_KEY='your_key_here'${NC}"
echo -e "${BLUE}docker compose up -d${NC}"
echo -e "--------------------------------------------------------"
echo -e "Your workspace (file exchange) is located at: ${GREEN}~/molt/workspace${NC}"
