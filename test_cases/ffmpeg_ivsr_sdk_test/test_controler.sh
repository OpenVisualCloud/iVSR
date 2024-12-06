#!/bin/bash

if command -v jq > /dev/null 2>&1; then
    echo "jq is already installed."
else
    echo "jq is not installed. Try to install it."
    apt-get update
    apt-get install -y jq
    if command -v jq > /dev/null 2>&1; then
        echo "jq has been successfully installed."
    else
        echo "There was an issue while installing jq."
    fi
fi

json_file="test_params.json"
json_data=$(cat "$json_file")
test_cases=$(echo "$json_data" | jq -r '.test_cases[]')
for cur_case in ${test_cases}; do
    echo $cur_case
    case ${cur_case} in
    function)
        source ./function_test.sh
        ;;
    stress_long)
        source ./stress_test_long.sh
        ;;
    stress_loop)
        source ./stress_test_loop.sh
        ;;
    *)
        echo "Unknown test case name: $cur_case"
        ;;
    esac
done