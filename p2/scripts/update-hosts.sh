#!/usr/bin/env bash

set -e

echo "Updating /etc/hosts..."

for HOST in app1.com app2.com app3.com; do

    # Remove previous entry
    sed -i "/[[:space:]]${HOST}$/d" /etc/hosts

    # Point domain to local machine
    echo "127.0.0.1 ${HOST}" >> /etc/hosts

done

echo
echo "Current application entries:"
grep -E 'app1\.com|app2\.com|app3\.com' /etc/hosts