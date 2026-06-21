#!/bin/bash
# Get the directory of the script
SCRIPT_DIR="$( cd "$( dirname "${BASH_SOURCE[0]}" )" &> /dev/null && pwd )"
REPO_DIR="$SCRIPT_DIR"
CHART_URL="https://artifactory.example-org.com/artifactory/helm3-example-org"
for dir in $REPO_DIR/* ; do
  if [ -f "$dir/Chart.yaml" ]; then
    CHART_NAME=$(basename $dir)
    CHART_TAG=$(awk '/^version/ {print$2}' ./$CHART_NAME/Chart.yaml)
    FILE=$CHART_NAME-$CHART_TAG.tgz
    helm dependency update $dir
    helm package "$dir" --destination $dir
    curl_out=$(curl -s "$CHART_URL/$CHART_NAME/$FILE")
    res_has_404=$(echo $curl_out | grep 404)
    if [ "$res_has_404" ]; then
    curl -k -u"$ARTIFACTORY_USERNAME":"$ARTIFACTORY_PASSWORD" -T "$dir/$FILE" "$CHART_URL/$CHART_NAME/$FILE"
    else
      echo "Chart version already exists; $FILE"
    fi
  fi
done
