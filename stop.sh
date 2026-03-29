#!/bin/zsh

echo "==> Stopping containers..."

for NODE in node1 node2; do
  if [[ -n "$(docker ps -q -f name=^${NODE}$)" ]]; then
    docker stop $NODE > /dev/null
    echo "    $NODE stopped."
  else
    echo "    $NODE is not running."
  fi
done

echo ""
echo "✅ Containers stopped. State is preserved — run start.sh to resume."