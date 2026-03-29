# Scripts Repository

This repository contains two sets of DevOps scripts for Docker container management and AWS resource administration.

## Docker Container Management Scripts

These scripts are used to spin up Docker containers with Ubuntu images and test networking between them.

### Files

- **setup.sh** - Initializes and configures the Docker environment, sets up network infrastructure, and prepares Ubuntu container images for deployment.

- **start.sh** - Starts the Docker containers and establishes the network connections between them for testing networking configurations.

- **stop.sh** - Stops all running Docker containers gracefully without removing them, allowing for later restart.

- **destroy.sh** - Completely removes all Docker containers, networks, and associated resources created by the setup process. Use this to clean up when you're done testing.

### Usage

```bash
# Initialize the environment
./setup.sh

# Start the containers
./start.sh

# Stop the containers (preserves them for restart)
./stop.sh

# Remove everything (clean slate)
./destroy.sh
```

## AWS Resource Management Scripts

These scripts are used for inspecting and managing AWS resources.

### Files

- **aws_inventory.zsh** - Inspects and lists AWS resources in your account, providing an inventory of deployed infrastructure, instances, and other AWS services.

- **aws_cleanup_resources.zsh** - Safely removes and cleans up AWS resources to prevent unnecessary costs and maintain a clean AWS environment.

### Usage

```bash
# View AWS resource inventory
./aws_inventory.zsh

# Clean up AWS resources
./aws_cleanup_resources.zsh
```

## Requirements

- Docker (for container management scripts)
- AWS CLI configured with appropriate credentials (for AWS management scripts)
- zsh shell (for AWS scripts)
- bash shell (for Docker scripts)

## Notes

- Ensure you have proper permissions before running AWS cleanup operations
- Review the Docker network configuration in `setup.sh` before initial deployment
- Always run `destroy.sh` before `setup.sh` when redeploying to avoid conflicts
