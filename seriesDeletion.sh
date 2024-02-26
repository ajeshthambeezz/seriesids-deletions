#!/bin/bash

# Check if jq is installed, if not, install it
if ! [ -x "$(command -v jq)" ]; then
  echo 'jq is not installed, installing...'
  sudo apt update
  sudo apt install -y jq
fi

SERVERURL="https://10.72.1.47:4446/maui"
LOGIN_URL="$SERVERURL/j_spring_security_check"
SERIESID="$SERVERURL/rest/season/search/"
SEASONID="$SERVERURL/rest/season/list-episodes/"
EPISODEID_DELETE_URL="$SERVERURL/rest/asset/delete"
SEASONID_DELETE_URL="$SERVERURL/rest/season/delete/"

# Set credentials
username="dishadm1"
password="Dish@4321"

if [ "$#" -ne 1 ]; then
    echo "Usage: $0 <series_id>"
    exit 1
fi

SERIES_ID="$1"
TODAY=$(date +"%d-%m-%Y")
COOKIE_FILE="maui-${SERIES_ID}-${TODAY}.cookie"
LOG_FILE="${SERIES_ID}-SeriesDelete-${TODAY}.log"

# Authenticate to obtain cookies
login_response=$(curl -i -k -c "$COOKIE_FILE" -b "$COOKIE_FILE" -X POST -s "$LOGIN_URL?j_username=$username&j_password=$password")

# Check if login was successful
if grep -q "j_spring_security_check" "$COOKIE_FILE"; then
    echo "Login failed. Unable to obtain cookies." | tee -a "$LOG_FILE"
    exit 1
fi

# Extract JSESSIONID from login response and set it as a delete cookie
JSESSIONID="JSESSIONID=$(echo "$login_response" | grep -oP 'JSESSIONID=\K[^;]+')"

# Check if login was successful
if [[ -z "$JSESSIONID" ]]; then
    echo "Login failed. Unable to obtain JSESSIONID." | tee -a "$LOG_FILE"
    exit 1
fi

# Set the series ID from the argument
series_id="$1"

# Send a GET request to obtain the seasons for the provided series ID
seasonResponse=$(curl -k -X GET -s /dev/null -H "Content-Type: application/json" -b "$JSESSIONID" "$SERIESID/$series_id")

# Check if the response is valid JSON
if jq -e . >/dev/null 2>&1 <<<"$seasonResponse"; then
    # Extract the values from the JSON response
    status_code=$(echo "$seasonResponse" | jq -r '.httpStatus')

    # Check if the response array is empty
    if [[ $(echo "$seasonResponse" | jq '.response | length') -eq 0 ]]; then
        echo "No seasons found for series ID: $series_id" | tee -a "$LOG_FILE"
    else
        # Echo asset ID and requested ID before outputting the status message
        echo "Seasons listed successfully for series ID: $series_id :: $status_code" | tee -a "$LOG_FILE"

        # Loop through each retrieved Season ID and its corresponding extId and Details them together
        i=0
        for season_id in $(echo "$seasonResponse" | jq -r '.response[].id'); do
            ext_season_id=$(echo "$seasonResponse" | jq -r --argjson index "$i" '.response[$index].extId')
            seasonNumber=$(echo "$seasonResponse" | jq -r --argjson index "$i" '.response[$index].seasonNumber')
            seasonTitle=$(echo "$seasonResponse" | jq -r --argjson index "$i" '.response[$index].title')
            echo "Season ID: $season_id  Ext_SeasonID: $ext_season_id  SeasonNumber: $seasonNumber SeasonTitle: $seasonTitle"  | tee -a "$LOG_FILE"

            # Now, curl the response for the current season ID
            seasonDetailsResponse=$(curl -k -X GET -s /dev/null -H "Content-Type: application/json" -b "$JSESSIONID" "$SEASONID/$season_id")

            # Check if the response is valid JSON
            if jq -e . >/dev/null 2>&1 <<<"$seasonDetailsResponse"; then
                # Extract episode IDs from the response and list them
                episodeIDs=$(echo "$seasonDetailsResponse" | jq -r '.response[]')
                if [ -z "$episodeIDs" ]; then
                    echo "Error: No episode IDs found for season $season_id" | tee -a "$LOG_FILE"
                else
                    echo "Episode IDs for season $season_id" | tee -a "$LOG_FILE"
                    for episode in $episodeIDs; do
                        episodeID=$(echo "$episode" | jq -r '.')
                        echo "$episodeID" | tee -a "$LOG_FILE"
                    done
                    echo "Episode listing completed for the $season_id" | tee -a "$LOG_FILE"
                fi

                # Now, delete each episode ID for the current season
                for episodeID in $episodeIDs; do
                    delete_response=$(curl -k -X DELETE -s /dev/null -H "Content-Type: application/json" -b "$JSESSIONID" "$EPISODEID_DELETE_URL/$episodeID")
                    # Check if the response is valid JSON
                    if jq -e . >/dev/null 2>&1 <<<"$delete_response"; then
                        # Extract the values from the JSON response
                        status_code=$(echo "$delete_response" | jq -r '.statusCode')
                        error_message=$(echo "$delete_response" | jq -r '.errorMessage')
                        statusMessage=$(echo "$delete_response" | jq -r '.statusMessage')

                        # Check the status code to determine success or failure
                        if [ "$status_code" == "1" ]; then
                            echo "Failed to delete episode $episodeID. Error message: $error_message" | tee -a "$LOG_FILE"
                        elif [ "$status_code" == "0" ]; then
                            echo "Episode $episodeID deleted successfully.  Status message: $statusMessage" | tee -a "$LOG_FILE"
                        else
                            echo "Failed to delete episode $episodeID. Unknown status code: $status_code" | tee -a "$LOG_FILE"
                        fi
                    else
                        echo "Failed to parse JSON response for episode $episodeID: $delete_response" | tee -a "$LOG_FILE"
                    fi
                done
            else
                echo "Failed to parse JSON response for season ID: $season_id" | tee -a "$LOG_FILE"
            fi

            # Delete the season ID after deleting episodes
            delete_season_response=$(curl -k -X DELETE -s /dev/null -H "Content-Type: application/json" -b "$JSESSIONID" "$SEASONID_DELETE_URL/$season_id")
            if jq -e . >/dev/null 2>&1 <<<"$delete_season_response"; then
                # Extract the values from the JSON response
                status_code=$(echo "$delete_season_response" | jq -r '.statusCode')
                error_message=$(echo "$delete_season_response" | jq -r '.errorMessage')
                statusMessage=$(echo "$delete_season_response" | jq -r '.statusMessage')

                # Check the status code to determine success or failure
                if [ "$status_code" == "1" ]; then
                    echo "Failed to delete season $season_id. Error message: $error_message" | tee -a "$LOG_FILE"
                elif [ "$status_code" == "0" ]; then
                    echo "Season $season_id deleted successfully.  Status message: $statusMessage" | tee -a "$LOG_FILE"
                else
                    echo "Failed to delete season $season_id. Unknown status code: $status_code" | tee -a "$LOG_FILE"
                fi
            else
                echo "Failed to parse JSON response for season $season_id deletion: $delete_season_response" | tee -a "$LOG_FILE"
            fi

            ((i++))
        done
    fi
else
    echo "Failed to parse JSON response for series ID $series_id" | tee -a "$LOG_FILE"
fi

