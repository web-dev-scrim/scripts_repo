#!/bin/zsh
set -e

echo "==> Creating network..."
docker network create mynet 2>/dev/null || echo "Network 'mynet' already exists, skipping."

for NODE in node1 node2; do
  echo ""
  echo "==> Setting up $NODE..."

  if [[ -z "$(docker ps -aq -f name=^${NODE}$)" ]]; then
    docker run -dit \
      --name $NODE \
      --hostname $NODE \
      --network mynet \
      ubuntu:22.04 bash
    echo "    Container $NODE created."
  else
    echo "    Container $NODE already exists, skipping creation."
    docker start $NODE > /dev/null
  fi

  echo "    Installing networking tools on $NODE..."
  docker exec $NODE bash -c "
    apt-get update -q && apt-get install -y -q \
      iputils-ping \
      iproute2 \
      net-tools \
      curl \
      wget \
      dnsutils \
      traceroute \
      nmap \
      netcat-openbsd \
      tcpdump \
      iperf3 \
      telnet \
      openssh-client \
      openssh-server \
    && echo 'root:root' | chpasswd \
    && sed -i 's/#PermitRootLogin prohibit-password/PermitRootLogin yes/' /etc/ssh/sshd_config \
    && sed -i 's/#PasswordAuthentication yes/PasswordAuthentication yes/' /etc/ssh/sshd_config \
    && service ssh start
  "
  echo "    $NODE is ready."
done

echo ""
echo "✅ Done! Both containers are running."
echo "   Attach with:  docker exec -it node1 bash"
echo "                 docker exec -it node2 bash"