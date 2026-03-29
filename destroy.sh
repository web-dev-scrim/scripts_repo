#!/bin/zsh

echo "==> Destroying lab..."
docker rm -f node1 node2 2>/dev/null || true
docker network rm mynet 2>/dev/null || true
echo "✅ All containers and network removed."