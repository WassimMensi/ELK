#!/bin/bash

APACHE_LOG_DIR="/usr/local/apache2/logs"
URLS=(
    "/index.html" "/about.html" "/contact.html" "/products.html"
    "/services.html" "/api/v1/users" "/api/v1/products" "/images/logo.png"
    "/css/main.css" "/js/app.js"
)
HTTP_METHODS=("GET" "POST" "PUT" "DELETE")
HTTP_VERSIONS=("HTTP/1.0" "HTTP/1.1" "HTTP/2.0")
STATUS_CODES=(200 200 200 200 200 301 302 304 400 401 403 404 500)
USER_AGENTS=(
    "Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/91.0.4472.124 Safari/537.36"
    "Mozilla/5.0 (Macintosh; Intel Mac OS X 10_15_7) AppleWebKit/605.1.15 (KHTML, like Gecko) Version/14.1.1 Safari/605.1.15"
    "Mozilla/5.0 (X11; Linux x86_64; rv:89.0) Gecko/20100101 Firefox/89.0"
    "Mozilla/5.0 (iPhone; CPU iPhone OS 14_6 like Mac OS X) AppleWebKit/605.1.15 (KHTML, like Gecko) Version/14.0 Mobile/15E148 Safari/604.1"
    "Mozilla/5.0 (compatible; Googlebot/2.1; +http://www.google.com/bot.html)"
)
IPS=(
    "192.168.1.1" "192.168.1.2" "192.168.1.3" "192.168.1.4" "192.168.1.5"
    "10.0.0.1" "10.0.0.2" "172.16.0.1" "8.8.8.8" "8.8.4.4"
)
REFERERS=(
    "-" "https://www.google.com" "https://www.bing.com"
    "https://www.facebook.com" "https://www.twitter.com"
    "https://www.linkedin.com"
)

# Ensure log directory exists
mkdir -p "$APACHE_LOG_DIR"

# Function to generate a random log entry
generate_apache_log() {
    local ip=${IPS[$RANDOM % ${#IPS[@]}]}
    local user="-"
    local auth="-"
    local timestamp=$(date -u +"%d/%b/%Y:%H:%M:%S +0000")
    local method=${HTTP_METHODS[$RANDOM % ${#HTTP_METHODS[@]}]}
    local url=${URLS[$RANDOM % ${#URLS[@]}]}
    local version=${HTTP_VERSIONS[$RANDOM % ${#HTTP_VERSIONS[@]}]}
    local status=${STATUS_CODES[$RANDOM % ${#STATUS_CODES[@]}]}
    local size=$((RANDOM % 10000 + 100))
    local referer=${REFERERS[$RANDOM % ${#REFERERS[@]}]}
    local user_agent=${USER_AGENTS[$RANDOM % ${#USER_AGENTS[@]}]}

    echo "$ip $user $auth [$timestamp] \"$method $url $version\" $status $size \"$referer\" \"$user_agent\""
}

# Main loop to generate logs
echo "Starting Apache log generator..."
while true; do
    # Generate between 1-5 log entries
    num_entries=$((RANDOM % 5 + 1))
    for ((i=0; i<num_entries; i++)); do
        log_entry=$(generate_apache_log)
        echo "$log_entry" >> "$APACHE_LOG_DIR/access.log"
    done

    # Random sleep between 1-3 seconds
    sleep $((RANDOM % 3 + 1))
done
