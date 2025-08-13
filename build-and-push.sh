#!/bin/bash

# Configuration
DOCKER_USERNAME="YOUR_DOCKERHUB_USERNAME"
IMAGE_NAME="squid-proxy"
VERSION="v1.0.0"

# Colors for output
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
NC='\033[0m' # No Color

echo -e "${GREEN}Building Docker image...${NC}"
docker build -t $IMAGE_NAME .

if [ $? -eq 0 ]; then
    echo -e "${GREEN}Image built successfully!${NC}"
    
    echo -e "${YELLOW}Tagging images...${NC}"
    docker tag $IMAGE_NAME $DOCKER_USERNAME/$IMAGE_NAME:latest
    docker tag $IMAGE_NAME $DOCKER_USERNAME/$IMAGE_NAME:$VERSION
    
    echo -e "${YELLOW}Logging into Docker Hub...${NC}"
    docker login
    
    if [ $? -eq 0 ]; then
        echo -e "${GREEN}Pushing images to Docker Hub...${NC}"
        docker push $DOCKER_USERNAME/$IMAGE_NAME:latest
        docker push $DOCKER_USERNAME/$IMAGE_NAME:$VERSION
        
        echo -e "${GREEN}Successfully pushed to Docker Hub!${NC}"
        echo -e "${YELLOW}Image: $DOCKER_USERNAME/$IMAGE_NAME:latest${NC}"
        echo -e "${YELLOW}Image: $DOCKER_USERNAME/$IMAGE_NAME:$VERSION${NC}"
    else
        echo -e "${YELLOW}Failed to login to Docker Hub${NC}"
        exit 1
    fi
else
    echo -e "${YELLOW}Failed to build image${NC}"
    exit 1
fi
