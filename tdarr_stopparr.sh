#!/bin/bash

set -euo pipefail

JELLYFIN_API_KEY="${JELLYFIN_API_KEY:-your_jellyfin_api_key_here}"
JELLYFIN_URL="${JELLYFIN_URL:-http://localhost:8096}"
TDARR_CONTAINER_NAME="${TDARR_CONTAINER_NAME:-tdarr}"
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

has_active_streams() {
    local response
    response=$(curl -sf \
        -H "Authorization: MediaBrowser Token=${JELLYFIN_API_KEY}" \
        -H "Content-Type: application/json" \
        "${JELLYFIN_URL}/Sessions" 2>/dev/null) || return 2

    local count
    count=$(echo "$response" | jq '[.[] | select(.NowPlayingItem != null)] | length' 2>/dev/null) || return 2

    [[ "$count" -gt 0 ]]
}

container_status() {
    docker inspect --format='{{.State.Status}}' "$TDARR_CONTAINER_NAME" 2>/dev/null || echo "not_found"
}

pause_container() {
    local status
    status=$(container_status)

    case "$status" in
        "running")
            log "Pausing $TDARR_CONTAINER_NAME"
            docker pause "$TDARR_CONTAINER_NAME" || log "Failed to pause container"
            ;;
        "paused")
            log "$TDARR_CONTAINER_NAME already paused"
            ;;
        "not_found")
            log "Container $TDARR_CONTAINER_NAME not found"
            ;;
        *)
            log "$TDARR_CONTAINER_NAME status: $status"
            ;;
    esac
}

unpause_container() {
    local status
    status=$(container_status)

    case "$status" in
        "paused")
            log "Unpausing $TDARR_CONTAINER_NAME"
            docker unpause "$TDARR_CONTAINER_NAME" || log "Failed to unpause container"
            ;;
        "running")
            log "$TDARR_CONTAINER_NAME already running"
            ;;
        "not_found")
            log "Container $TDARR_CONTAINER_NAME not found"
            ;;
        *)
            log "$TDARR_CONTAINER_NAME status: $status"
            ;;
    esac
}

main() {
    check_deps

    local prev_streaming=false
    log "Monitoring Jellyfin streams every ${CHECK_INTERVAL}s"

    while true; do
        local streaming=false

        if has_active_streams; then
            streaming=true
        elif [[ $? -eq 2 ]]; then
            log "API error, retrying in ${CHECK_INTERVAL}s"
            sleep "$CHECK_INTERVAL"
            continue
        fi

        if [[ "$streaming" == true && "$prev_streaming" == false ]]; then
            log "Streaming started"
            pause_container
        elif [[ "$streaming" == false && "$prev_streaming" == true ]]; then
            log "Streaming stopped"
            unpause_container
        fi

        prev_streaming=$streaming
        sleep "$CHECK_INTERVAL"
    done
}

trap 'log "Shutting down"; exit 0' SIGINT SIGTERM
main
