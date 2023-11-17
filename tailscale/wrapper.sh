#!/bin/bash

set -x
set -euo pipefail

if [ "${ENABLE_TAILSCALE-}" = true ]; then
    echo "Enabling Tailscale"
    TAILSCALE_APP_NAME="${TAILSCALE_APP_NAME:-${FLY_APP_NAME}-${FLY_REGION}}-${FLY_ALLOC_ID:0:8}"
    /tailscale/tailscaled --state=/var/lib/tailscale/tailscaled.state --socket=/var/run/tailscale/tailscaled.sock &
    /tailscale/tailscale up --authkey=${TAILSCALE_AUTHKEY} --hostname="${TAILSCALE_APP_NAME}" --accept-routes=true
fi

export ERL_CRASH_DUMP=/tmp/erl_crash.dump

function upload_crash_dump_to_s3 {
    EXIT_CODE=${?:-0}

    bucket=$ERL_CRASH_DUMP_S3_BUCKET
    s3Key=$ERL_CRASH_DUMP_S3_KEY
    s3Secret=$ERL_CRASH_DUMP_S3_SECRET
    s3Host=$ERL_CRASH_DUMP_S3_HOST
    s3Port=$ERL_CRASH_DUMP_S3_PORT

    filePath=${ERL_CRASH_DUMP_FOLDER:-tmp}/$(date +%s)_${ERL_CRASH_DUMP_FILE_NAME:-erl_crash.dump}

    if [ -f "${ERL_CRASH_DUMP_FOLDER:-tmp}/${ERL_CRASH_DUMP_FILE_NAME:-erl_crash.dump}" ]; then
        mv ${ERL_CRASH_DUMP_FOLDER:-tmp}/${ERL_CRASH_DUMP_FILE_NAME:-erl_crash.dump} $filePath

        resource="/${bucket}${filePath}"

        contentType="application/octet-stream"
        dateValue=$(date -R)
        stringToSign="PUT\n\n${contentType}\n${dateValue}\n${resource}"

        signature=$(echo -en ${stringToSign} | openssl sha1 -hmac ${s3Secret} -binary | base64)

        if [ "${S3_USE_HTTPS:-}" = true ]; then
            protocol="https"
        else
            protocol="http"
        fi

        curl -v -X PUT -T "${filePath}" \
            -H "Host: ${s3Host}" \
            -H "Date: ${dateValue}" \
            -H "Content-Type: ${contentType}" \
            -H "Authorization: AWS ${s3Key}:${signature}" \
            ${protocol}://${s3Host}:${s3Port}${resource}
    fi

    exit "$EXIT_CODE"
}

if [ "${ENABLE_ERL_CRASH_DUMP-}" = true ]; then
    trap upload_crash_dump_to_s3 SIGINT SIGTERM SIGKILL EXIT
fi

echo "Starting Realtime"

if [ "${AWS_EXECUTION_ENV:=none}" = "AWS_ECS_FARGATE" ]; then
    echo "Running migrations"
    sudo -E -u nobody /app/bin/migrate
fi

sudo -E -u nobody /app/bin/server
