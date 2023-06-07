#!/bin/sh
set -eu

execute_ssh(){
  echo "Execute Over SSH: $@"
  ssh -q -t -i "$HOME/.ssh/id_ed25519" \
      -o UserKnownHostsFile=/dev/null \
      -o StrictHostKeyChecking=no "$INPUT_REMOTE_DOCKER_HOST" -p "$INPUT_SSH_PORT" "$@"
}

if [ -z "$INPUT_REMOTE_DOCKER_HOST" ]; then
    echo "Input remote_docker_host is required!"
    exit 1
fi

if [ -z "$INPUT_SSH_PUBLIC_KEY" ]; then
    echo "Input ssh_public_key is required!"
    exit 1
fi

if [ -z "$INPUT_SSH_PRIVATE_KEY" ]; then
    echo "Input ssh_private_key is required!"
    exit 1
fi

if [ -z "$INPUT_ARGS" ]; then
  echo "Input input_args is required!"
  exit 1
fi

if [ -z "$INPUT_STACK_FILE_NAME" ]; then
  INPUT_STACK_FILE_NAME=docker-compose.yml
fi

if [ -z "$INPUT_SSH_PORT" ]; then
  INPUT_SSH_PORT=22
fi

STACK_FILE=${INPUT_STACK_FILE_NAME}
DEPLOYMENT_COMMAND_OPTIONS="--project-directory ."

DEPLOYMENT_COMMAND="docker-compose -f $STACK_FILE"


SSH_HOST=${INPUT_REMOTE_DOCKER_HOST#*@}

echo "Registering SSH keys..."

# register the private key with the agent.
mkdir -p ~/.ssh
ls ~/.ssh
printf '%s\n' "$INPUT_SSH_PRIVATE_KEY" > ~/.ssh/id_ed25519
chmod 600 ~/.ssh/id_ed25519
printf '%s\n' "$INPUT_SSH_PUBLIC_KEY" > ~/.ssh/id_ed25519.pub
chmod 600 ~/.ssh/id_ed25519.pub
#chmod 600 "~/.ssh"
eval $(ssh-agent)
path=~/.ssh/id_ed25519
echo "$path"

expect << EOF
  set timeout 3
  spawn ssh-add "$path"
  expect {
    "Enter passphrase" {
      send "$INPUT_KEY_PASS\r"
      expect eof
    }
    timeout {
      puts "Timed out waiting for 'Enter passphrase'. Continuing."
      expect eof
    }
  }
EOF

echo "Add known hosts"
ssh-keyscan -p $INPUT_SSH_PORT "$SSH_HOST" >> ~/.ssh/known_hosts
ssh-keyscan -p $INPUT_SSH_PORT "$SSH_HOST" >> /etc/ssh/ssh_known_hosts
# set context
echo "Create docker context"
docker context create staging --docker "host=ssh://$INPUT_REMOTE_DOCKER_HOST:$INPUT_SSH_PORT"
docker context use staging


if  [ -n "$INPUT_DOCKER_LOGIN_PASSWORD" ] || [ -n "$INPUT_DOCKER_LOGIN_USER" ] || [ -n "$INPUT_DOCKER_LOGIN_REGISTRY" ]; then
  echo "Connecting to $INPUT_REMOTE_DOCKER_HOST... Command: docker login"
  docker login -u "$INPUT_DOCKER_LOGIN_USER" -p "$INPUT_DOCKER_LOGIN_PASSWORD" "$INPUT_DOCKER_LOGIN_REGISTRY"
fi

echo $(docker --version)

echo "Command: ${DEPLOYMENT_COMMAND} build"
${DEPLOYMENT_COMMAND} ${DEPLOYMENT_COMMAND_OPTIONS} build

echo "Command: ${DEPLOYMENT_COMMAND} ${INPUT_ARGS}"
${DEPLOYMENT_COMMAND} ${DEPLOYMENT_COMMAND_OPTIONS} ${INPUT_ARGS}

docker context rm staging

