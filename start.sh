#!/bin/bash

REPOSITORY=$REPO
ORGANIZATION=$ORG
ACCESS_TOKEN=$TOKEN

echo "REPO ${REPOSITORY}"
echo "ORG ${ORGANIZATION}"
echo "ACCESS_TOKEN ${ACCESS_TOKEN}"

if [ -z "$ACCESS_TOKEN" ]; then
    echo "TOKEN is not set. Please set the TOKEN environment variable."
    exit 1
fi

if [ -z "$REPOSITORY" ] && [ -z "$ORGANIZATION" ]; then
    echo "Either REPO or ORG must be set. Please set one of them."
    exit 1
fi
cd /home/node/actions-runner

if [ "$ORGANIZATION" ]; then
    echo "Using organization: ${ORGANIZATION}"
    ORG_TOKEN=$(curl -X POST -H "Authorization: token ${ACCESS_TOKEN}" -H "Accept: application/vnd.github+json" https://api.github.com/orgs/${ORGANIZATION}/actions/runners/registration-token | jq .token --raw-output)
    ./config.sh --url https://github.com/${ORGANIZATION} --token ${ORG_TOKEN}
else
    echo "Using repository: ${REPOSITORY}"
    ORG_TOKEN=$(curl -X POST -H "Authorization: token ${ACCESS_TOKEN}" -H "Accept: application/vnd.github+json" https://api.github.com/repos/${REPOSITORY}/actions/runners/registration-token | jq .token --raw-output)
    ./config.sh --url https://github.com/${REPOSITORY} --token ${ORG_TOKEN}
fi



cleanup() {
    echo "Removing runner..."
    ./config.sh remove --unattended --token ${ORG_TOKEN}
}

trap 'cleanup; exit 130' INT
trap 'cleanup; exit 143' TERM

./run.sh & wait $!