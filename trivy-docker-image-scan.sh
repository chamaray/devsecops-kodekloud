#!/bin/bash

# Get image name from Dockerfile
dockerImageName=$(awk 'NR==1 {print $2}' Dockerfile)
echo "Scanning Image: $dockerImageName"

# Pull Trivy image (safe)
docker pull aquasec/trivy:0.17.2

# Run HIGH severity scan (does NOT fail build)
docker run --rm \
  -v $WORKSPACE:/root/.cache/ \
  aquasec/trivy:0.17.2 image \
  --severity HIGH \
  --exit-code 0 \
  --no-progress \
  $dockerImageName

# Run CRITICAL severity scan (FAIL build if found)
docker run --rm \
  -v $WORKSPACE:/root/.cache/ \
  aquasec/trivy:0.17.2 image \
  --severity CRITICAL \
  --exit-code 1 \
  --no-progress \
  $dockerImageName

exit_code=$?

echo "Exit Code: $exit_code"

if [[ "$exit_code" -eq 1 ]]; then
  echo "❌ Image scanning failed. Critical vulnerabilities found!"
  exit 1
else
  echo "✅ Image scanning passed. No critical vulnerabilities."
fi
