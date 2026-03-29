#!/bin/zsh

echo "==> Starting containers..."

for NODE in node1 node2; do
  if [[ -n "$(docker ps -aq -f name=^${NODE}$)" ]]; then
    docker start $NODE > /dev/null
    docker exec $NODE service ssh start > /dev/null 2>&1
    echo "    $NODE started."
  else
    echo "    $NODE not found — run setup.sh first."
  fi
done

echo ""
echo "✅ Containers running. Attach with:"
echo "   docker exec -it node1 bash"
echo "   docker exec -it node2 bash"