#!/bin/bash

# Function to handle deletion of series
delete_series() {
    local SERIES_ID="$1"
    local LOG_FILE="$2"
    local JSESSIONID="$3"
    local RESPONSE_FILE="${SERIES_ID}-responses.json"

    # Check if response file exists, if not, create an empty JSON array
    if [ ! -f "$RESPONSE_FILE" ]; then
        echo "[]" > "$RESPONSE_FILE"
    fi

    # Send a GET request to obtain the seasons for the provided series ID
    seriesResponse=$(curl -k -X GET -s /dev/null -H "Content-Type: application/json" -b "$JSESSIONID" "$SERIESID/$SERIES_ID")

    # Check if the response is valid JSON
    if jq -e . >/dev/null 2>&1 <<<"$seriesResponse"; then
        # Extract the values from the JSON response
        status_code=$(echo "$seriesResponse" | jq -r '.httpStatus')

        # Check if the response array is empty
        if [[ $(echo "$seriesResponse" | jq '.response | length') -eq 0 ]]; then
            echo "No seasons found for series ID: $SERIES_ID" | tee -a "$LOG_FILE"
        else
            # Echo asset ID and requested ID before outputting the status message
            echo "Seasons listed successfully for series ID: $SERIES_ID :: $status_code" | tee -a "$LOG_FILE"
            # Loop through each retrieved Season ID and its corresponding extId and Details them together
            i=0
            for season_id in $(echo "$seriesResponse" | jq -r '.response[].id'); do
                ext_season_id=$(echo "$seriesResponse" | jq -r --argjson index "$i" '.response[$index].extId')
                SereisSeasonIDs=" $season_id"
                seasonNumber=$(echo "$seriesResponse" | jq -r --argjson index "$i" '.response[$index].seasonNumber')
                seasonTitle=$(echo "$seriesResponse" | jq -r --argjson index "$i" '.response[$index].title')
                echo "Season ID: $season_id  Ext_SeasonID: $ext_season_id  SeasonNumber: $seasonNumber SeasonTitle: $seasonTitle"  | tee -a "$LOG_FILE"
                ((i++))
            done
            echo | tee -a $LOG_FILE

            # Prompt the user to enter the season number they want to delete
            read -p "Enter the season number you want to delete: " season_number
            # Find the season ID corresponding to the entered season number
            selected_season_id=$(echo "$seriesResponse" | jq -r --arg season_number "$season_number" '.response[] | select(.seasonNumber == $season_number) | .id')
            echo "You Entered:"$season_number "Dleting the "$selected_season_id 
            # Check if the selected season ID is empty (invalid season number)
            
            if [ -z "$selected_season_id" ]; then
                echo "Invalid season number. No season found for the entered number." | tee -a "$LOG_FILE"
                exit 1
            fi
                        
            # List episodes before deleting
            list_episodes "$selected_season_id" "$LOG_FILE" "$JSESSIONID"

            delete_episode_associated_images "$EPISODE_ID" "$LOG_FILE" "$JSESSIONID"
            
            # Delete the episodes associated with the selected season
            delete_episodes "$selected_season_id" "$LOG_FILE" "$JSESSIONID" "$RESPONSE_FILE"

            # Delete the selected season ID after deleting episodes
            delete_season "$selected_season_id" "$LOG_FILE" "$JSESSIONID" "$RESPONSE_FILE"
        fi
    else
        echo "Failed to parse JSON response for series ID $series_id" | tee -a "$LOG_FILE"
    fi
}


list_episodes() {
    local SEASON_ID="$1"
    local LOG_FILE="$2"
    local JSESSIONID="$3"

    # Retrieve episodes associated with the season
    seasonDetailsResponse=$(curl -k -X GET -s /dev/null -H "Content-Type: application/json" -b "$JSESSIONID" "$SEASONID/$SEASON_ID")

    # Check if the response is valid JSON
    if jq -e . >/dev/null 2>&1 <<<"$seasonDetailsResponse"; then
        # Extract episode IDs, titles, and images
        episodeDetails=$(echo "$seasonDetailsResponse" | jq -r '.response[]')

        # Print episode details
        echo "Episodes associated with the Season : $SEASON_ID" | tee -a "$LOG_FILE"
        echo "$episodeDetails" | while IFS= read -r line; do
              episode_id="$line"  # Directly use the current line as episode_id

            # Retrieve episode images
            episodeImagesResponse=$(curl -k -X GET -s /dev/null -H "Content-Type: application/json" -b "$JSESSIONID" "$EPISODEID_IMAGE_LIST/$episode_id")

            # Check if the response is valid JSON
            if jq -e . >/dev/null 2>&1 <<<"$episodeImagesResponse"; then
                # Check if there are images available for the episode
                if [ "$(echo "$episodeImagesResponse" | jq '.response.imageList | length')" -eq 0 ]; then
                    echo "No images found for Episode ID: $episode_id" | tee -a "$LOG_FILE"
                else
                    episode_image_ids=$(echo "$episodeImagesResponse" | jq -r '.response.imageList[].id')
                    
                    # Splitting image IDs into an array
                    IFS=$'\n' read -rd '' -a image_ids_array <<<"$episode_image_ids"
                    
                    # Print episode ID
                    echo "Episode ID: $episode_id" | tee -a "$LOG_FILE"
                    
                    # Print image IDs in order
                    for image_id in "${image_ids_array[@]}"; do
                        echo "Image ID: $image_id" | tee -a "$LOG_FILE"
                        
                        # Delete the image ID
                        episodeImageDelete=$(curl -k -X DELETE -s /dev/null -H "Content-Type: application/json" -b "$JSESSIONID" "$EPISODEID_IMAGE_DELETE/$image_id")
                        echo "Deleting Image ID: $image_id" | tee -a "$LOG_FILE"
                    done
                fi
                echo "" | tee -a "$LOG_FILE"
            else
                echo "Failed to parse JSON response for episode images for episode ID: $episode_id" | tee -a "$LOG_FILE"
            fi
        done
    else
        echo "Failed to parse JSON response for season ID: $SEASON_ID" | tee -a "$LOG_FILE"
    fi
}








# # Function to delete associated images for an episode
# delete_episode_associated_images() {
#     local EPISODE_ID="$1"
#     local LOG_FILE="$2"
#     local JSESSIONID="$3"
    
#     # After deleting episodes, check for associated images and delete them
#     episodeImagesResponse=$(curl -k -X GET -s /dev/null -H "Content-Type: application/json" -b "$JSESSIONID" "$EPISODEID_IMAGE_LIST/$EPISODE_ID")
#     echo $episodeImagesResponse
#     # Check if the response is valid JSON
#     if jq -e . >/dev/null 2>&1 <<<"$episodeImagesResponse"; then

#         # Extract the values from the JSON response
#         status_code=$(echo "$episodeImagesResponse" | jq -r '.httpStatus')

#         # Check if the response array is empty
#         if [[ $(echo "$episodeImagesResponse" | jq '.response.imageList | length') -eq 0 ]]; then
#             echo "No images found for episode ID: $EPISODE_ID" | tee -a "$LOG_FILE"
#         else
#             # Loop through each retrieved image and delete it
#             for image_id in $(echo "$episodeImagesResponse" | jq -r '.response.imageList[].id'); do
#                 echo $image_id
#                 deleteEpisodeImage=$(curl -k -X DELETE -s /dev/null -H "Content-Type: application/json" -b "$JSESSIONID" "$EPISODEID_IMAGE_DELETE/$image_id")
#                 if jq -e . >/dev/null 2>&1 <<<"$deleteEpisodeImage"; then

#                     # Extract the values from the JSON response
#                     status_code=$(echo "$deleteEpisodeImage" | jq -r '.statusCode')
#                     error_message=$(echo "$deleteEpisodeImage" | jq -r '.errorMessage')
#                     statusMessage=$(echo "$deleteEpisodeImage" | jq -r '.statusMessage')

#                     # Check the status code to determine success or failure
#                     if [ "$status_code" == "1" ]; then
#                         echo "Failed to delete image $image_id. Error message: $error_message" | tee -a "$LOG_FILE"
#                     elif [ "$status_code" == "0" ]; then
#                         echo "Status message: $statusMessage" | tee -a "$LOG_FILE"
#                     else
#                         echo "Failed to delete image $image_id. Unknown status code: $status_code" | tee -a "$LOG_FILE"
#                     fi
#                 else
#                     echo "Failed to parse JSON response for image $image_id deletion: $deleteEpisodeImage" | tee -a "$LOG_FILE"
#                 fi
#             done
#         fi
#     else
#         echo "Failed to parse JSON response for images associated with episode ID $EPISODE_ID" | tee -a "$LOG_FILE"
#     fi  
# }


# # Function to delete episodes associated with a season
# delete_episodes() {
#     local SEASON_ID="$1"
#     local LOG_FILE="$2"
#     local JSESSIONID="$3"
#     local RESPONSE_FILE="$4"
    
#     # Retrieve episodes associated with the season
#     seasonDetailsResponse=$(curl -k -X GET -s /dev/null -H "Content-Type: application/json" -b "$JSESSIONID" "$SEASONID/$SEASON_ID")
    
#     # Check if the response is valid JSON
#     if jq -e . >/dev/null 2>&1 <<<"$seasonDetailsResponse"; then

#         # Extract episode IDs
#         episodeIDs=$(echo "$seasonDetailsResponse" | jq -r '.response[]')

#         # Delete each episode
#         for episodeID in $episodeIDs; do

#             # Delete the episode
#             delete_episode_response=$(curl -k -X DELETE -s /dev/null -H "Content-Type: application/json" -b "$JSESSIONID" "$EPISODEID_DELETE_URL/$episodeID")
            
#             # Check if the response is valid JSON
#             if jq -e . >/dev/null 2>&1 <<<"$delete_episode_response"; then

#                 # Extract the values from the JSON response
#                 status_code=$(echo "$delete_episode_response" | jq -r '.statusCode')
#                 statusMessage=$(echo "$delete_episode_response" | jq -r '.statusMessage')
                
#                 # Check if the deletion was successful
#                 if [ "$status_code" == "0" ]; then
#                     echo "Episode $episodeID deleted successfully. Status message: $statusMessage" | tee -a "$LOG_FILE"
#                 else
#                     echo "Failed to delete episode $episodeID. Status message: $statusMessage" | tee -a "$LOG_FILE"
#                     # Record failed response
#                     echo "{\"episodeID\": \"$episodeID\", \"statusMessage\": \"$statusMessage\"}" >> "$RESPONSE_FILE"
#                 fi
#             else
#                 echo "Failed to parse JSON response for episode $episodeID deletion: $delete_episode_response" | tee -a "$LOG_FILE"
#             fi
#         done
#     else
#         echo "Failed to parse JSON response for season ID: $SEASON_ID" | tee -a "$LOG_FILE"
#     fi
# }

# # Function to delete the selected season
# delete_season() {
#     local SEASON_ID="$1"
#     local LOG_FILE="$2"
#     local JSESSIONID="$3"
#     local RESPONSE_FILE="$4"
    
#     # Delete the selected season
#     delete_season_response=$(curl -k -X DELETE -s /dev/null -H "Content-Type: application/json" -b "$JSESSIONID" "$SEASONID_DELETE_URL/$SEASON_ID")
    
#     # Check if the response is valid JSON
#     if jq -e . >/dev/null 2>&1 <<<"$delete_season_response"; then
#         # Extract the values from the JSON response
#         status_code=$(echo "$delete_season_response" | jq -r '.statusCode')
#         statusMessage=$(echo "$delete_season_response" | jq -r '.statusMessage')
        
#         # Check if the deletion was successful
#         if [ "$status_code" == "0" ]; then
#             echo | tee -a $LOG_FILE
#             echo "Season $SEASON_ID deleted successfully. Status message: $statusMessage" | tee -a "$LOG_FILE"
#         else
#             echo "Failed to delete season $SEASON_ID. Status message: $statusMessage" | tee -a "$LOG_FILE"
#             # Record failed response
#             echo "{\"seasonID\": \"$SEASON_ID\", \"statusMessage\": \"$statusMessage\"}" >> "$RESPONSE_FILE"
#         fi
#     else
#         echo "Failed to parse JSON response for season $SEASON_ID deletion: $delete_season_response" | tee -a "$LOG_FILE"
#     fi
# }

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
EPISODEID_IMAGE_LIST="$SERVERURL/rest/multipleimages/ASSET/"
EPISODEID_IMAGE_DELETE="$SERVERURL/rest/multipleimages/delete/"
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

        # Call delete_series function for each series ID
        delete_series "$SERIES_ID" "$LOG_FILE" "$JSESSIONID"
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

    # Call delete_series function for the single series ID
    delete_series "$SERIES_ID" "$LOG_FILE" "$JSESSIONID"
fi
