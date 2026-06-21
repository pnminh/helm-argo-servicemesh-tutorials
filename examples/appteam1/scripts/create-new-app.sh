#!/bin/bash

# Check if an app name is provided
if [ -z "$1" ]; then
    echo "Please provide an app name."
    exit 1
fi
# Get the directory of the script
SCRIPT_DIR="$( cd "$( dirname "${BASH_SOURCE[0]}" )" &> /dev/null && pwd )"
# Set app name
APP_NAME=$1
BASE_DIR="$SCRIPT_DIR/../apps/$APP_NAME"
CHART_DIR="$BASE_DIR"
ENVIRONMENTS_DIR="$BASE_DIR/environments"
CHART_YAML="$CHART_DIR/Chart.yaml"
VALUES_YAML="$CHART_DIR/values.yaml"

# Create base directory
mkdir -p "$BASE_DIR"

# Create umbrella helm chart directory
mkdir -p "$CHART_DIR"

# Create Chart.yaml for umbrella helm chart
cat <<EOF > "$CHART_YAML"
apiVersion: v2
name: $APP_NAME
description: A Helm chart for $APP_NAME
type: application
version: 0.1.0
dependencies:
  - name: app-deployment
    version: ">=0.1.0"
    repository: "file://../../../../helm-charts/app-deployment"
EOF

# Create values.yaml for umbrella helm chart with a comment
echo "# Values file for $APP_NAME chart" > "$VALUES_YAML"

# Create environments directory
mkdir -p "$ENVIRONMENTS_DIR"

# Create dev, stage, and prod directories with dev-1, stage-1, prod-1, and prod-2 subdirectories
for environment in dev stage prod; do
    ENVIRONMENT_DIR="$ENVIRONMENTS_DIR/$environment"
    mkdir -p "$ENVIRONMENT_DIR"
    # Create values.yaml for each environment directory
    echo "# Values file for $APP_NAME in $environment environment" > "$ENVIRONMENT_DIR/values.yaml"
done

echo "Folder structure created successfully for $APP_NAME."
