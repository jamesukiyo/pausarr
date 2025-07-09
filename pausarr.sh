#!/bin/bash
set -euo pipefail
JELLYFIN_API_KEY="${JELLYFIN_API_KEY:-your_jellyfin_api_key_here}"
JELLYFIN_URL="${JELLYFIN_URL:-http://localhost:8096}"
CONTAINERS_TO_PAUSE="${CONTAINERS_TO_PAUSE:-tdarr,sonarr}"  # space or comma separated list
CHECK_INTERVAL="${CHECK_INTERVAL:-30}"

log() {
    echo "[$(date '+%Y-%m-%d %H:%M:%S')] $*" >&2
}

die() {
    log "ERROR: $*"
    exit 1
}

check_deps() {
    command -v docker >/dev/null || die "docker not found"
    command -v curl >/dev/null || die "curl not found"
    command -v jq >/dev/null || die "jq not found"
    [[ "$JELLYFIN_API_KEY" != "your_jellyfin_api_key_here" ]] || die "Set JELLYFIN_API_KEY environment variable"
}

has_active_sessions() {
    local response
    response=$(curl -sf \
        -H "Authorization: MediaBrowser Token=${JELLYFIN_API_KEY}" \
        -H "Content-Type: application/json" \
        "${JELLYFIN_URL}/Sessions" 2>/dev/null) || return 2
    local count
    count=$(echo "$response" | jq '[.[] | select(.IsActive == true)] | length' 2>/dev/null) || return 2
    [[ "$count" -gt 0 ]]
}

get_containers() {
    # convert list to array
    echo "$CONTAINERS_TO_PAUSE" | tr ',' ' ' | tr -s ' '
}

container_status() {
    local container="$1"
    docker inspect --format='{{.State.Status}}' "$container" 2>/dev/null || echo "not_found"
}

pause_containers() {
    local containers
    containers=$(get_containers)

    for container in $containers; do
        local status
        status=$(container_status "$container")

        case "$status" in
            "running")
                log "User connected - Pausing $container"
                docker pause "$container" || log "Failed to pause $container"
                ;;
            "paused")
                log "$container already paused"
                ;;
            "not_found")
                log "Container $container not found"
                ;;
            *)
                log "$container status: $status"
                ;;
        esac
    done
}

unpause_containers() {
    local containers
    containers=$(get_containers)

    for container in $containers; do
        local status
        status=$(container_status "$container")

        case "$status" in
            "paused")
                log "No users connected - Unpausing $container"
                docker unpause "$container" || log "Failed to unpause $container"
                ;;
            "running")
                log "$container already running"
                ;;
            "not_found")
                log "Container $container not found"
                ;;
            *)
                log "$container status: $status"
                ;;
        esac
    done
}

main() {
    check_deps

    local containers
    containers=$(get_containers)
    log "Will manage containers: $containers"

    local prev_sessions=false
    log "Monitoring Jellyfin user sessions every ${CHECK_INTERVAL}s"

    while true; do
        local sessions=false
        if has_active_sessions; then
            sessions=true
        elif [[ $? -eq 2 ]]; then
            log "API error, retrying in ${CHECK_INTERVAL}s"
            sleep "$CHECK_INTERVAL"
            continue
        fi

        if [[ "$sessions" == true && "$prev_sessions" == false ]]; then
            log "User connected to Jellyfin"
            pause_containers
        elif [[ "$sessions" == false && "$prev_sessions" == true ]]; then
            log "All users disconnected from Jellyfin"
            unpause_containers
        fi

        prev_sessions=$sessions
        sleep "$CHECK_INTERVAL"
    done
}

trap 'log "Shutting down"; exit 0' SIGINT SIGTERM
main
