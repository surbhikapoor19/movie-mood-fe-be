#! /bin/bash

PORT=22010
MACHINE=paffenroth-23.dyn.wpi.edu
NAME=group10
PUBLIC_KEY_PATH="/home/cmfrench/.ssh/"
PUBLIC_KEY_NAME="group_key"
AUTHORIZED_KEY_PATH="/home/cmfrench/Documents/MLops/authorized_keys"
KNOWN_HOSTS_PATH="/home/cmfrench/.ssh/fakeKnownHosts"

# Clean up from previous runs
ssh-keygen -f "${KNOWN_HOSTS_PATH}" -R "[${MACHINE}]:${PORT}" || true
ssh-keygen -f "${KNOWN_HOSTS_PATH}" -R "[130.215.182.20]:${PORT}" || true
rm -rf tmp

# Make a temporary directory
mkdir tmp

# copy the key to the temporary directory
cp ${PUBLIC_KEY_PATH}/${PUBLIC_KEY_NAME}* tmp

# Change the premissions of the directory
chmod 700 tmp

# Change to the temporary directory
cd tmp

# Set the permissions of the key
chmod 600 ${PUBLIC_KEY_NAME}*

# Make sure our authorized_keys have the correct permissions
chmod 600 ${AUTHORIZED_KEY_PATH}

echo "checking that the authorized_keys file is correct"
# ls -l ${AUTHORIZED_KEY_PATH}
# cat ${AUTHORIZED_KEY_PATH}

scp -i ${PUBLIC_KEY_PATH}/${PUBLIC_KEY_NAME} \
    -P ${PORT}\
    -o StrictHostKeyChecking=no \
    -o UserKnownHostsFile=${KNOWN_HOSTS_PATH} \
    ${AUTHORIZED_KEY_PATH} ${NAME}@${MACHINE}:~/.ssh/

