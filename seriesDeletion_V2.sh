#!/bin/bash

# Function to handle deletion of series
delete_all_seriesIds() {
    local SERIES_ID="$1"
    local LOG_FILE="$2"
    local JSESSIONID="$3"

    # Send a GET request to obtain the seasons for the provided series ID
    seasonResponse=$(curl -k -X GET -s /dev/null -H "Content-Type: application/json" -b "$JSESSIONID" "$SERIESID/$SERIES_ID")

    # Check if the response is valid JSON
    if jq -e . >/dev/null 2>&1 <<<"$seasonResponse"; then
        # Extract the values from the JSON response
        status_code=$(echo "$seasonResponse" | jq -r '.httpStatus')

        # Check if the response array is empty
        if [[ $(echo "$seasonResponse" | jq '.response | length') -eq 0 ]]; then
            echo "No seasons found for series ID: $SERIES_ID" | tee -a "$LOG_FILE"
        else
            # Echo asset ID and requested ID before outputting the status message
            echo "Seasons listed successfully for series ID: $SERIES_ID :: $status_code" | tee -a "$LOG_FILE"

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

    # After deleting seasons and associated episodes, check for associated images and delete them
    imagesResponse=$(curl -k -X GET -s /dev/null -H "Content-Type: application/json" -b "$JSESSIONID" "$SERIESID_IMAGES/$SERIES_ID")

    # Check if the response is valid JSON
    if jq -e . >/dev/null 2>&1 <<<"$imagesResponse"; then

        # Extract the values from the JSON response
        status_code=$(echo "$imagesResponse" | jq -r '.httpStatus')

        # Check if the response array is empty
        # if [[ $(echo "$imagesResponse" | jq '.response.imageList[].id') -eq 0 ]]; then
        if [[ $(echo "$imagesResponse" | jq '.response.imageList | length') -eq 0 ]]; then
            echo "No images found for series ID: $SERIES_ID" | tee -a "$LOG_FILE"
        else

            # Loop through each retrieved image and delete it
            for image_id in $(echo "$imagesResponse" | jq -r '.response.imageList[].id'); do
                echo $image_id
                deleteSeriesImage=$(curl -k -X DELETE -s /dev/null -H "Content-Type: application/json" -b "$JSESSIONID" "$SERIESID_IMAGES_DELETE/$image_id")
                if jq -e . >/dev/null 2>&1 <<<"$deleteSeriesImage"; then

                    # Extract the values from the JSON response
                    status_code=$(echo "$deleteSeriesImage" | jq -r '.statusCode')
                    error_message=$(echo "$deleteSeriesImage" | jq -r '.errorMessage')
                    statusMessage=$(echo "$deleteSeriesImage" | jq -r '.statusMessage')

                    # Check the status code to determine success or failure
                    if [ "$status_code" == "1" ]; then
                        echo "Failed to delete image $image_id. Error message: $error_message" | tee -a "$LOG_FILE"
                    elif [ "$status_code" == "0" ]; then
                        echo "Status message: $statusMessage" | tee -a "$LOG_FILE"
                    else
                        echo "Failed to delete image $image_id. Unknown status code: $status_code" | tee -a "$LOG_FILE"
                    fi
                else
                    echo "Failed to parse JSON response for image $image_id deletion: $deleteSeriesImage" | tee -a "$LOG_FILE"
                fi
            done
        fi
    else
        echo "Failed to parse JSON response for images associated with series ID $SERIES_ID" | tee -a "$LOG_FILE"
    fi
    echo >> "$LOG_FILE"
    # After deleting seasons, associated episodes, and images, delete the series ID
    deleteSeries=$(curl -k -X DELETE -s /dev/null -H "Content-Type: application/json" -b "$JSESSIONID" "$SERIESID_DELETE_URL/$SERIES_ID")

    # Check if the response is valid JSON
    if jq -e . >/dev/null 2>&1 <<<"$deleteSeries"; then

        # Extract the values from the JSON response
        status_code=$(echo "$deleteSeries" | jq -r '.statusCode')
        error_message=$(echo "$deleteSeries" | jq -r '.errorMessage')
        errorCode=$(echo "$deleteSeries" | jq -r '.errorCode')

        # Check the status code to determine success or failure
        if [ "$status_code" == "1" ]; then
            echo "Failed to delete series $SERIES_ID. Error message: $error_message errorCode: $errorCode  SeriesID Already Deleted"  | tee -a "$LOG_FILE"
        elif [ "$status_code" == "0" ]; then
            echo "Series $SERIES_ID deleted successfully with its all Branched Seasons and Episodes including images. Please confirm the same in DB export or MAUI Multiple Images VOD contents" | tee -a "$LOG_FILE"
        else
            echo "Failed to delete series $SERIES_ID. status code: $status_code" | tee -a "$LOG_FILE"
        fi
    else
        echo "Failed to parse JSON response for series ID $SERIES_ID" | tee -a "$LOG_FILE"
    fi
}

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
SERIESID_IMAGES="$SERVERURL/rest/multipleimages/VOD_SERIES/"
SERIESID_IMAGES_DELETE="$SERVERURL/rest/multipleimages/delete/"
SERIESID_DELETE_URL="$SERVERURL/rest/series/delete/"

# Set credentials
username="dishadm1"
password="Dish@4321"

# Check if an argument is provided
if [ "$#" -ne 1 ]; then
    echo "Usage: $0 <series_id or series_id.txt>"
    exit 1
fi

# Set series IDs based on the argument
if [ -f "$1" ]; then
    # If the argument is a file, read series IDs from the file
    while IFS= read -r SERIES_ID; do
        # Authenticate to obtain cookies
        COOKIE_FILE="maui-${SERIES_ID}-${TODAY}.cookie"
        LOG_FILE="${SERIES_ID}-SeriesDelete-${TODAY}.log"
        LOGIN_RESPONSE=$(curl -i -k -c "$COOKIE_FILE" -b "$COOKIE_FILE" -X POST -s "$LOGIN_URL?j_username=$username&j_password=$password")

        # Check if login was successful
        if grep -q "j_spring_security_check" "$COOKIE_FILE"; then
            echo "Login failed. Unable to obtain cookies." | tee -a "$LOG_FILE"
            exit 1
        fi

        # Extract JSESSIONID from login response and set it as a delete cookie
        JSESSIONID="JSESSIONID=$(echo "$LOGIN_RESPONSE" | grep -oP 'JSESSIONID=\K[^;]+')"

        # Check if login was successful
        if [[ -z "$JSESSIONID" ]]; then
            echo "Login failed. Unable to obtain JSESSIONID." | tee -a "$LOG_FILE"
            exit 1
        fi

        # Call delete_all_seriesIds function for each series ID
        delete_all_seriesIds "$SERIES_ID" "$LOG_FILE" "$JSESSIONID"
    done < "$1"
else
    # If the argument is a single series ID, directly delete it
    SERIES_ID="$1"
    COOKIE_FILE="maui-${SERIES_ID}-${TODAY}.cookie"
    LOG_FILE="${SERIES_ID}-SeriesDelete-${TODAY}.log"

    # Authenticate to obtain cookies
    LOGIN_RESPONSE=$(curl -i -k -c "$COOKIE_FILE" -b "$COOKIE_FILE" -X POST -s "$LOGIN_URL?j_username=$username&j_password=$password")

    # Check if login was successful
    if grep -q "j_spring_security_check" "$COOKIE_FILE"; then
        echo "Login failed. Unable to obtain cookies." | tee -a "$LOG_FILE"
        exit 1
    fi

    # Extract JSESSIONID from login response and set it as a delete cookie
    JSESSIONID="JSESSIONID=$(echo "$LOGIN_RESPONSE" | grep -oP 'JSESSIONID=\K[^;]+')"

    # Check if login was successful
    if [[ -z "$JSESSIONID" ]]; then
        echo "Login failed. Unable to obtain JSESSIONID." | tee -a "$LOG_FILE"
        exit 1
    fi

    # Call delete_all_seriesIds function for the single series ID
    delete_all_seriesIds "$SERIES_ID" "$LOG_FILE" "$JSESSIONID"
fi

#Author Ajesh ThambeeZzz....