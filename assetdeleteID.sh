#!/bin/bash

# # Function to check if a command exists
# command_exists() {
#     command -v "$1" >/dev/null 2>&1
# }

# # Check if jq is installed, and install it if not
# if ! command_exists jq; then
#     echo "jq is not installed. Installing..."
#     # Check the package manager and install jq
#     if command_exists apt-get; then
#         sudo apt-get update
#         sudo apt-get install -y jq
#     elif command_exists yum; then
#         sudo yum install -y jq
#     elif command_exists brew; then
#         brew install jq
#     else
#         echo "Cannot install jq. Please install it manually."
#         exit 1
#     fi
# fi

# Check if curl is installed, and install it if not
# if ! command_exists curl; then
#     echo "curl is not installed. Please install curl."
#     exit 1
# fi

# Server Urls and API Information
LOGIN_URL="https://10.72.1.47:4446/maui/j_spring_security_check"
DELETE_URL="https://10.72.1.47:4446/maui/rest/asset/delete"
TODAY=$(date +"%d-%m-%Y")
COOKIE_FILE="maui-$TODAY.cookie"


# Set credentials
username="dishadm1"
password="Dish@4321"

# Authenticate to obtain cookies
login_response=$(curl -i -k -c $COOKIE_FILE -b $COOKIE_FILE -X POST -s "$LOGIN_URL?j_username=$username&j_password=$password")

# Check if login was successful
if grep -q "j_spring_security_check" $COOKIE_FILE; then
    echo "Login failed. Unable to obtain cookies."
    exit 1
fi

# Extract JSESSIONID from login response and set it as a delete cookie
JSESSIONID="JSESSIONID="$(echo "$login_response" | grep -oP 'JSESSIONID=\K[^;]+')

# Check if login was successful
if [[ -z "$JSESSIONID" ]]; then
    echo "Login failed. Unable to obtain JSESSIONID."
    exit 1
fi

# # Check if series ID argument is provided
# if [ -z "$1" ]; then
#     echo "Error: Please provide the series ID as an argument."
#     exit 1
# fi

# # Extract series ID from command-line argument
# series_id="$1"

# File containing asset 
asset_file="asset_ids.txt"

# Check if the file exists
if [ ! -f "$asset_file" ]; then
    echo "Error: Asset ID file not found: $asset_file"
    exit 1
fi

# Read asset IDs from the file into an array
mapfile -t asset_ids < "$asset_file"

# Loop through each asset ID and send a DELETE request
for id in "${asset_ids[@]}"; do
delete_assetid=$(curl -k -X DELETE -s /dev/null -H "Content-Type: application/json" -b $JSESSIONID "$DELETE_URL/$id")
echo $delete_assetid
    # Check if the response is valid JSON
    if jq -e . >/dev/null 2>&1 <<<"$delete_assetid"; then
        # Extract the values from the JSON response
        status_code=$(echo "$delete_assetid" | jq -r '.statusCode')
        error_message=$(echo "$delete_assetid" | jq -r '.errorMessage')
        statusMessage=$(echo "$delete_assetid" | jq -r '.statusMessage')

        # Check the status code to determine success or failure
        if [ "$status_code" == "1" ]; then
            echo "Failed to delete asset $id. Error message: $error_message"
        elif [ "$status_code" == "0" ]; then
            echo "Asset deleted successfully.  Status message: $statusMessage" :: $id
        else
            echo "Failed to delete asset $id. Unknown status code: $status_code"
        fi
    else
        echo "Failed to parse JSON response for asset $id: $response"
    fi
done

#!/bin/bash

LOGIN_URL="https://10.72.1.47:4446/maui/j_spring_security_check"
SERIESID="https://10.72.1.47:4446/maui/rest/season/search/"
SEASONID="https://10.72.1.47:4446/maui/rest/season/list-episodes/"
EPISODEID_DELETE_URL="https://10.72.1.47:4446/maui/rest/asset/delete/"
SEASONID_DELETE_URL="https://10.72.1.47:4446/maui/rest/season/delete/"
SERIESID_IMAGES="https://10.72.1.47:4446/maui/rest/multipleimages/VOD_SERIES/"

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
seriesResponse=$(curl -k -X GET -s /dev/null -H "Content-Type: application/json" -b "$JSESSIONID" "$SERIESID/$series_id")

# Check if the response is valid JSON
if jq -e . >/dev/null 2>&1 <<<"$seriesResponse"; then
    # Extract the values from the JSON response
    status_code=$(echo "$seriesResponse" | jq -r '.httpStatus')

    # Check if the response array is empty
    if [[ $(echo "$seriesResponse" | jq '.response | length') -eq 0 ]]; then
        echo "No seasons found for series ID: $series_id" | tee -a "$LOG_FILE"
        # Now, check for associated images
        imagesResponse=$(curl -k -X GET -s /dev/null -H "Content-Type: application/json" -b "$JSESSIONID" "$SERIESID_IMAGES/$series_id")
        if jq -e . >/dev/null 2>&1 <<<"$imagesResponse"; then
            image_count=$(echo "$imagesResponse" | jq -r '. | length')
            if [[ $image_count -eq 0 ]]; then
                echo "No images associated with series ID: $series_id" | tee -a "$LOG_FILE"
            else
                echo "Images associated with series ID: $series_id" | tee -a "$LOG_FILE"
                for image in $(echo "$imagesResponse" | jq -r '.[]'); do
                    echo "$image" | tee -a "$LOG_FILE"
                    # Now, delete the image
                    deleteImage=$(curl -k -X DELETE -s /dev/null -H "Content-Type: application/json" -b "$JSESSIONID" "$SERIESID_IMAGES/$series_id/$image")
                    # Check if the response is valid JSON
                    if jq -e . >/dev/null 2>&1 <<<"$deleteImage"; then
                        # Extract the values from the JSON response
                        status_code=$(echo "$deleteImage" | jq -r '.statusCode')
                        error_message=$(echo "$deleteImage" | jq -r '.errorMessage')
                        statusMessage=$(echo "$deleteImage" | jq -r '.statusMessage')

                        # Check the status code to determine success or failure
                        if [ "$status_code" == "1" ]; then
                            echo "Failed to delete image $image. Error message: $error_message" | tee -a "$LOG_FILE"
                        elif [ "$status_code" == "0" ]; then
                            echo "Image $image deleted successfully. Status message: $statusMessage" | tee -a "$LOG_FILE"
                        else
                            echo "Failed to delete image $image. Unknown status code: $status_code" | tee -a "$LOG_FILE"
                        fi
                    else
                        echo "Failed to parse JSON response for image deletion: $deleteImage" | tee -a "$LOG_FILE"
                    fi
                done
            fi
        else
            echo "Failed to fetch images associated with series ID: $series_id" | tee -a "$LOG_FILE"
        fi
    else
        # Echo asset ID and requested ID before outputting the status message
        echo "Seasons listed successfully for series ID: $series_id :: $status_code" | tee -a "$LOG_FILE"

        # Loop through each retrieved Season ID and its corresponding extId and Details them together
        i=0
        for season_id in $(echo "$seriesResponse" | jq -r '.response[].id'); do
            ext_season_id=$(echo "$seriesResponse" | jq -r --argjson index "$i" '.response[$index].extId')
            seasonNumber=$(echo "$seriesResponse" | jq -r --argjson index "$i" '.response[$index].seasonNumber')
            seasonTitle=$(echo "$seriesResponse" | jq -r --argjson index "$i" '.response[$index].title')
            echo "Season ID: $season_id  Ext_SeasonID: $ext_season_id  SeasonNumber: $seasonNumber SeasonTitle: $seasonTitle" | tee -a "$LOG_FILE"

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
                    deleteEpisodes=$(curl -k -X DELETE -s /dev/null -H "Content-Type: application/json" -b "$JSESSIONID" "$EPISODEID_DELETE_URL/$episodeID")
                    # Check if the response is valid JSON
                    if jq -e . >/dev/null 2>&1 <<<"$deleteEpisodes"; then
                        # Extract the values from the JSON response
                        status_code=$(echo "$deleteEpisodes" | jq -r '.statusCode')
                        error_message=$(echo "$deleteEpisodes" | jq -r '.errorMessage')
                        statusMessage=$(echo "$deleteEpisodes" | jq -r '.statusMessage')

                        # Check the status code to determine success or failure
                        if [ "$status_code" == "1" ]; then
                            echo "Failed to delete episode $episodeID. Error message: $error_message" | tee -a "$LOG_FILE"
                        elif [ "$status_code" == "0" ]; then
                            echo "Episode $episodeID deleted successfully. Status message: $statusMessage" | tee -a "$LOG_FILE"
                        else
                            echo "Failed to delete episode $episodeID. Unknown status code: $status_code" | tee -a "$LOG_FILE"
                        fi
                    else
                        echo "Failed to parse JSON response for episode $episodeID: $deleteEpisodes" | tee -a "$LOG_FILE"
                    fi
                done
            else
                echo "Failed to parse JSON response for season ID: $season_id" | tee -a "$LOG_FILE"
            fi

            # Delete the season ID after deleting episodes
            deleteSeason=$(curl -k -X DELETE -s /dev/null -H "Content-Type: application/json" -b "$JSESSIONID" "$SEASONID_DELETE_URL/$series_id")
            if jq -e . >/dev/null 2>&1 <<<"$deleteSeason"; then
                # Extract the values from the JSON response
                status_code=$(echo "$deleteSeason" | jq -r '.statusCode')
                error_message=$(echo "$deleteSeason" | jq -r '.errorMessage')
                statusMessage=$(echo "$deleteSeason" | jq -r '.statusMessage')

                # Check the status code to determine success or failure
                if [ "$status_code" == "1" ]; then
                    echo "Failed to delete season $season_id. Error message: $error_message" | tee -a "$LOG_FILE"
                elif [ "$status_code" == "0" ]; then
                    echo "Season $season_id deleted successfully. Status message: $statusMessage" | tee -a "$LOG_FILE"
                else
                    echo "Failed to delete season $season_id. Unknown status code: $status_code" | tee -a "$LOG_FILE"
                fi
            else
                echo "Failed to parse JSON response for season $season_id deletion: $deleteSeason" | tee -a "$LOG_FILE"
            fi

            ((i++))
        done
    fi
else
    echo "Failed to parse JSON response for series ID $series_id" | tee -a "$LOG_FILE"
fi
