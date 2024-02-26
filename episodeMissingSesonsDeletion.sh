#!/bin/bash

# Function to renew the cookie
renew_cookie() {
    echo "Renewing cookie..."
    login_response=$(curl -i -k -c "maui.cookie" -b "maui.cookie" -X POST -s "$LOGIN_URL?j_username=$username&j_password=$password")
    JSESSIONID="JSESSIONID=$(echo "$login_response" | grep -oP 'JSESSIONID=\K[^;]+')"
    if [[ -z "$JSESSIONID" ]]; then
        echo "Login failed. Unable to obtain JSESSIONID. Exiting..."
        exit 1
    fi
    echo "Cookie renewed successfully."
}

# Check if jq is installed, if not, install it
if ! [ -x "$(command -v jq)" ]; then
  echo 'jq is not installed, installing...'
  sudo apt update
  sudo apt install -y jq
fi

SERVERURL="https://10.72.1.47:4446/maui"
SERIESALL="$SERVERURL/rest/series/all"
LOGIN_URL="$SERVERURL/j_spring_security_check"
SERIESID="$SERVERURL/rest/season/search/"
SEASONID="$SERVERURL/rest/season/list-episodes/"
SEASONID_DELETE_URL="$SERVERURL/rest/season/delete/"
SERIESID_DELETE_URL="$SERVERURL/rest/series/delete/"

# Set credentials
username="dishadm1"
password="Dish@4321"

# Log file path
LOG_FILE="maui_SeasionDeletion_log_$(date '+%Y-%m-%d').log"

# Authenticate to obtain cookies
login_response=$(curl -i -k -c "maui.cookie" -b "maui.cookie" -X POST -s "$LOGIN_URL?j_username=$username&j_password=$password")

# Extract JSESSIONID from login response and set it as a delete cookie
JSESSIONID="JSESSIONID=$(echo "$login_response" | grep -oP 'JSESSIONID=\K[^;]+')"

# Check if login was successful
if [[ -z "$JSESSIONID" ]]; then
    echo "Login failed. Unable to obtain JSESSIONID."
    exit 1
fi

# Function to check if it's time to renew the cookie (every 10 minutes)
should_renew_cookie() {
    current_minute=$(date '+%M')
    if [ "$(($current_minute % 10))" -eq 0 ]; then
        return 0
    else
        return 1
    fi
}

# Check if seriesIds.txt exists
if [ ! -f "seriesIds.txt" ]; then
    # Send a GET request to find all the Series and save the response to a file
    seriesAllResponse=$(curl -k -X GET -s -o seriesAllResponse.json -H "Content-Type: application/json" -b "$JSESSIONID" "$SERIESALL")

    # Check if the response is valid JSON
    if jq -e . seriesAllResponse.json >/dev/null 2>&1; then

        # Extract the series IDs from the response and save to a text file
        jq -r '.response[].id' seriesAllResponse.json > seriesIds.txt

        echo "Series IDs saved to seriesIds.txt"
        echo >> "$LOG_FILE"
    else
        echo "Failed to parse JSON response for series. Exiting..."
        exit 1
    fi
fi

# Counter to keep track of series IDs processed
series_count=0

# Loop through each retrieved series ID
while IFS= read -r series_id; do
    ((series_count++))
    echo "Series ID: $series_id" >> "$LOG_FILE"

    # Send a GET request to obtain the seasons for the current series ID
    seriesResponse=$(curl -k -X GET -s /dev/null -H "Content-Type: application/json" -b "$JSESSIONID" "$SERIESID/$series_id")

    # Check if the response is valid JSON
    if jq -e . >/dev/null 2>&1 <<<"$seriesResponse"; then
        # Extract the values from the JSON response
        status_code=$(echo "$seriesResponse" | jq -r '.httpStatus')

        # Check if the response array is empty
        if [[ $(echo "$seriesResponse" | jq '.response | length') -eq 0 ]]; then
            echo "No seasons found for series ID: $series_id" >> "$LOG_FILE"
        else
            # Echo asset ID and requested ID before outputting the status message
            echo "Seasons listed successfully for series ID: $series_id :: $status_code" >> "$LOG_FILE"
            
            # Loop through each retrieved Season ID and its corresponding extId and Details them together
            for season_id in $(echo "$seriesResponse" | jq -r '.response[].id'); do
                # Now, curl the response for the current season ID
                seasonDetailsResponse=$(curl -k -X GET -s /dev/null -H "Content-Type: application/json" -b "$JSESSIONID" "$SEASONID/$season_id")

                # Check if the response is valid JSON
                if jq -e . >/dev/null 2>&1 <<<"$seasonDetailsResponse"; then
                    # Extract episode IDs from the response
                    episodeIDs=$(echo "$seasonDetailsResponse" | jq -r '.response[]')

                    # If there are no episodes, delete the season
                    if [ -z "$episodeIDs" ]; then
                        echo "No episodes found for season $season_id. Deleting the season..." >> "$LOG_FILE"
                        # Now, delete the season ID
                        deleteSeason=$(curl -k -X DELETE -s /dev/null -H "Content-Type: application/json" -b "$JSESSIONID" "$SEASONID_DELETE_URL/$season_id")
                        # Check if the response is valid JSON
                        if jq -e . >/dev/null 2>&1 <<<"$deleteSeason"; then
                            # Extract the values from the JSON response
                            status_code=$(echo "$deleteSeason" | jq -r '.statusCode')
                            error_message=$(echo "$deleteSeason" | jq -r '.errorMessage')
                            statusMessage=$(echo "$deleteSeason" | jq -r '.statusMessage')

                            # Check the status code to determine success or failure
                            if [ "$status_code" == "1" ]; then
                                echo "Failed to delete season $season_id. Error message: $error_message" >> "$LOG_FILE"
                            elif [ "$status_code" == "0" ]; then
                                echo "Season $season_id deleted successfully.  Status message: $statusMessage" >> "$LOG_FILE"
                            else
                                echo "Failed to delete season $season_id. Unknown status code: $status_code" >> "$LOG_FILE"
                            fi
                        else
                            echo "Failed to parse JSON response for season $season_id deletion: $deleteSeason" >> "$LOG_FILE"
                        fi
                    else
                        echo "Episode are found for season $season_id. Skipping deletion of season." >> "$LOG_FILE"
                    fi
                else
                    echo "Failed to parse JSON response for season ID: $season_id" >> "$LOG_FILE"
                fi
            done
        fi
        echo >> "$LOG_FILE"
    else
        echo "Failed to parse JSON response for series ID $series_id. Response:" >> "$LOG_FILE"
        echo "$seriesResponse" >> "$LOG_FILE"
    fi
    
    # Append the completed series ID with date and time to completedSeriesIds.txt
    echo "$series_id" >> completedSeriesIds-$(date '+%Y-%m-%d').txt

    # Remove the checked series ID from seriesIds.txt
    grep -v "$series_id" seriesIds.txt > remainingSeriesIds.txt
    mv remainingSeriesIds.txt seriesIds.txt

    # After every 20 series IDs, sleep for a while
    if ((series_count % 20 == 0)); then
        echo "Sleeping for a 10 sec..."
        sleep 10  # Sleep for 10 seconds, adjust as needed
    fi

    # Check if it's time to renew the cookie (every 10 minutes)
    if should_renew_cookie; then
        renew_cookie
    fi

done < seriesIds.txt
