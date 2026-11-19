#!/usr/bin/env bash
# Deploys the exercise inside the AWS learner lab: ZooKeeper on one node,
# the node binary on five app nodes. Run terraform apply first.
set -euo pipefail

KEY=${LABSUSER_PEM:-$HOME/Downloads/labsuser.pem}
REMOTE_USER=${REMOTE_USER:-ec2-user}
SSH_OPTIONS=${SSH_OPTIONS:-}
DIR=$(cd "$(dirname "$0")" && pwd)
ZK_VERSION=3.9.3

output()
{
	terraform -chdir="$DIR" output -json | python3 -c "import json,sys; print(json.load(sys.stdin)['$1']['value'])"
}

zk_public=$(output zookeeper_public_ip)
zk_private=$(output zookeeper_private_ip)
mapfile -t apps < <(terraform -chdir="$DIR" output -json |
	python3 -c "import json,sys; print('\n'.join(json.load(sys.stdin)['app_public_ips']['value']))")

remote()
{
	local host=$1
	shift
	ssh $SSH_OPTIONS -i "$KEY" -o StrictHostKeyChecking=no -o UserKnownHostsFile=/dev/null "$REMOTE_USER@$host" "$@"
}

copy_up()
{
	scp $SSH_OPTIONS -i "$KEY" -o StrictHostKeyChecking=no -o UserKnownHostsFile=/dev/null "$1" "$REMOTE_USER@$2:$3"
}

copy_down()
{
	scp $SSH_OPTIONS -i "$KEY" -o StrictHostKeyChecking=no -o UserKnownHostsFile=/dev/null "$REMOTE_USER@$1:$2" "$3"
}

echo "=== ZooKeeper on $zk_public (apps use $zk_private)"
remote "$zk_public" 'bash -s' <<EOF
set -e
sudo dnf install -y java-17-amazon-corretto-headless
cd "\$HOME"
if [ ! -d apache-zookeeper-$ZK_VERSION-bin ]; then
	curl -fsSL -o zk-bin.tar.gz https://archive.apache.org/dist/zookeeper/zookeeper-$ZK_VERSION/apache-zookeeper-$ZK_VERSION-bin.tar.gz
	tar xzf zk-bin.tar.gz
fi
mkdir -p zk-data
printf 'tickTime=2000\ndataDir=%s/zk-data\nclientPort=2181\nadmin.enableServer=false\n' "\$HOME" > apache-zookeeper-$ZK_VERSION-bin/conf/zoo.cfg
if ! apache-zookeeper-$ZK_VERSION-bin/bin/zkServer.sh status >/dev/null 2>&1; then
	apache-zookeeper-$ZK_VERSION-bin/bin/zkServer.sh start
fi
EOF

echo "=== building the ZooKeeper C client and the node on ${apps[0]}"
remote "${apps[0]}" 'mkdir -p src'
copy_up "$DIR/src/node.cpp" "${apps[0]}" src/node.cpp
copy_up "$DIR/CMakeLists.txt" "${apps[0]}" CMakeLists.txt
remote "${apps[0]}" 'bash -s' <<EOF
set -e
sudo dnf install -y gcc-c++ cmake make autoconf automake libtool maven
cd "\$HOME"
if [ ! -d apache-zookeeper-$ZK_VERSION ]; then
	curl -fsSL -o zk-src.tar.gz https://archive.apache.org/dist/zookeeper/zookeeper-$ZK_VERSION/apache-zookeeper-$ZK_VERSION.tar.gz
	tar xzf zk-src.tar.gz
fi
cd apache-zookeeper-$ZK_VERSION
mvn -q -pl zookeeper-jute -am generate-sources -DskipTests </dev/null
cd zookeeper-client/zookeeper-client-c
if [ ! -x configure ]; then
	autoreconf -if
fi
./configure --prefix="\$HOME/zk-c" --without-cppunit
make -j2
make install
cd "\$HOME"
cmake -S . -B build -DZOOKEEPER_ROOT="\$HOME/zk-c"
cmake --build build
cp build/node "\$HOME/node"
cp zk-c/lib/libzookeeper_mt.so.2 "\$HOME/"
EOF

echo "=== copying the node binary to the other four app nodes"
tmp=$(mktemp -d)
trap 'rm -rf "$tmp"' EXIT
copy_down "${apps[0]}" /home/$REMOTE_USER/node "$tmp/node"
copy_down "${apps[0]}" /home/$REMOTE_USER/libzookeeper_mt.so.2 "$tmp/libzookeeper_mt.so.2"
for app in "${apps[@]:1}"; do
	copy_up "$tmp/node" "$app" node
	copy_up "$tmp/libzookeeper_mt.so.2" "$app" libzookeeper_mt.so.2
done

echo "=== done: ZooKeeper reachable at $zk_private:2181; run ./run_experiment.sh"
