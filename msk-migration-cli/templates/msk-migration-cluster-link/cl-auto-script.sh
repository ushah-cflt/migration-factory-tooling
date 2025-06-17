#!/bin/bash

# Fail on errors
set -e

show_usage() {
    echo "Usage: $0 [--help]"
    echo ""
    echo "This script generates a Confluent cluster link between the msk cluster and Confluent cloud."
    echo ""
    echo "Required environment variables:"
    echo "  CONFLUENT_CLOUD_EMAIL      Your Confluent Cloud login email"
    echo "  CONFLUENT_CLOUD_PASSWORD   Your Confluent Cloud login password"
    echo ""
    echo "Options:"
    echo "    --help -- Prints this page"
    echo "    --link-name [link-name]"
    echo "    --cluster-id [cluster-id]"
    echo "    --environment-id [environment-id]"
    echo "    --msk-cluster-bootstrap-servers [bootstrap.servers]"
    echo "    --msk-cluster-client-config-file-path [config-file-path]"
    echo "    --topics-file-path [config-file-path]"
    echo "    --consumer-groups-file-path [config-file-path]"
    echo ""
    exit 0
}

# Show help if --help is passed
if [[ "$1" == "--help" ]]; then
    show_usage
fi

if [[ $# -eq 0 ]];then
   echo "No input arguments provided."
   show_usage
   exit 1
fi

while [ ! -z "$1" ]
do
    if [[ "$1" == "--help" ]]
    then
        show_usage
        exit 0
    elif [[ "$1" == "--link-name" ]]
    then
        if [[ "$2" == --* ]] || [[ -z "$2" ]]
        then
            echo "No Value provided for "$1". Please ensure proper values are provided"
            show_usage
            exit 1
        fi
        linkId="$2"
        shift
    elif [[ "$1" == "--cluster-id" ]]
    then
        if [[ "$2" == --* ]] || [[ -z "$2" ]]
        then
            echo "No Value provided for "$1". Please ensure proper values are provided"
            show_usage
            exit 1
        fi
        clusterId="$2"
        echo "Cluster ID: ${clusterId}"
        shift
    elif [[ "$1" == "--environment-id" ]]
    then
        if [[ "$2" == --* ]] || [[ -z "$2" ]]
        then
            echo "No Value provided for "$1". Please ensure proper values are provided"
            show_usage
            exit 1
        fi
        environmentId="$2"
        echo "Environment ID: ${environmentId}"
        shift
    elif [[ "$1" == "--msk-cluster-bootstrap-servers" ]]
    then
        if [[ "$2" == --* ]] || [[ -z "$2" ]]
        then
            echo "No Value provided for "$1". Please ensure proper values are provided"
            show_usage
            exit 1
        fi
        mskBootstrapServers="$2"
        echo "MSK Cluster bootstrap servers: ${mskBootstrapServers}"
        shift
    elif [[ "$1" == "--msk-cluster-client-config-file-path" ]]
    then
        if [[ "$2" == --* ]] || [[ -z "$2" ]]
        then
            echo "No Value provided for "$1". Please ensure proper values are provided"
            show_usage
            exit 1
        fi
        mskConfigFilePath="$2"
        echo "Msk config file path: ${mskConfigFilePath}"
        shift
    elif [[ "$1" == "--topics-file-path" ]]
    then
        if [[ "$2" == --* ]] || [[ -z "$2" ]]
        then
            echo "No Value provided for "$1". Please ensure proper values are provided"
            show_usage
            exit 1
        fi
        topicsFilePath="$2"
        echo "Topics file path: ${topicsFilePath}"
        shift
    elif [[ "$1" == "--consumer-groups-file-path" ]]
    then
        if [[ "$2" == --* ]] || [[ -z "$2" ]]
        then
            echo "No Value provided for "$1". Please ensure proper values are provided"
            show_usage
            exit 1
        fi
        consumerGroupsFilePath="$2"
        echo "Consumer Groups file path: ${consumerGroupsFilePath}"
    fi
    shift
done

if [[ -z "$linkId"  ]] || [[ -z "$clusterId"  ]] || [[ -z "$environmentId"  ]] || [[ -z "$mskBootstrapServers"  ]] || [[ -z "$mskConfigFilePath" ]] || [[ -z "$topicsFilePath" ]] || [[ -z "$consumerGroupsFilePath" ]]
then
    echo "--link-name, --cluster-id, --environment-id, --msk-cluster-bootstrap-servers, --msk-cluster-client-config-file-path, --topics-file-path, --consumer-groups-file-path are required for execution."
    show_usage
    exit 1
fi

# Required environment variables
: "${CONFLUENT_CLOUD_EMAIL:?Set CONFLUENT_CLOUD_EMAIL}"
: "${CONFLUENT_CLOUD_PASSWORD:?Set CONFLUENT_CLOUD_PASSWORD}"

CONFIG_FILE="cp-link-scram-client.config"


echo "bootstrap.servers=$mskBootstrapServers" > "$CONFIG_FILE"
# Begin writing to config file
cat $mskConfigFilePath >> "$CONFIG_FILE"
echo " " >> "$CONFIG_FILE"


# Add topic filters
echo 'auto.create.mirror.topics.enable=true' >> "$CONFIG_FILE"
echo -n 'auto.create.mirror.topics.filters={"topicFilters":[' >> "$CONFIG_FILE"

# Read input file for topics and groups

# Read topics.txt file

filters=""
while IFS= read -r line || [[ "$line" ]];
    do
        filters+="{\"name\": \"$line\", \"patternType\": \"LITERAL\", \"filterType\": \"INCLUDE\"}, "
    done < $topicsFilePath
filters=${filters%, }
echo -n $filters >> "$CONFIG_FILE"

# Add hardcoded excludes
echo -n ', {"name": "__amazon_msk_canary", "patternType": "LITERAL", "filterType": "EXCLUDE"}' >> "$CONFIG_FILE"
echo ']}' >> "$CONFIG_FILE"

# Add offset sync
echo " " >> "$CONFIG_FILE"
echo 'consumer.offset.sync.enable=true' >> "$CONFIG_FILE"
echo 'consumer.offset.sync.ms=1000' >> "$CONFIG_FILE"

# Add group filters from group txt file
echo -n 'consumer.offset.group.filters={"groupFilters":[' >> "$CONFIG_FILE"
grp_filters=""

while IFS= read -r line || [[ "$line" ]];
    do
        grp_filters+="{\"name\": \"$line\", \"patternType\": \"LITERAL\", \"filterType\": \"INCLUDE\"}, "
    done < $consumerGroupsFilePath

grp_filters=${grp_filters%, }
echo -n $grp_filters >> "$CONFIG_FILE"
echo ']}' >> "$CONFIG_FILE"

cat $CONFIG_FILE
# Confluent Cloud login
echo "Logging into Confluent Cloud..."
CONFLUENT_CLOUD_EMAIL="$CONFLUENT_CLOUD_EMAIL" \
CONFLUENT_CLOUD_PASSWORD="$CONFLUENT_CLOUD_PASSWORD" \

confluent login --save

# Create cluster link
echo "Creating cluster link"
confluent kafka link create $linkId \
  --destination-cluster $clusterId \
  --config-file $CONFIG_FILE \
  --environment $environmentId \
  --cluster $clusterId

echo "Checking if CL is created"
sleep 5
confluent kafka link list --cluster $clusterId --environment $environmentId