#!/bin/bash
# Monitors route changes and sets the correct SA via setkey

us-east-1-via-45() {
    setkey -c << EOF
    spdupdate 10.142.24.0/21 10.142.32.0/21 any -P out ipsec esp/tunnel/10.142.31.7-54.240.217.162/require;
    spdupdate 10.142.32.0/21 10.142.24.0/21 any -P in  ipsec esp/tunnel/54.240.217.162-10.142.31.7/require;
EOF
}

us-east-1-via-41() {
    setkey -c << EOF
    spdupdate 10.142.24.0/21 10.142.32.0/21 any -P out ipsec esp/tunnel/10.142.31.7-54.240.217.164/require;
    spdupdate 10.142.32.0/21 10.142.24.0/21 any -P in  ipsec esp/tunnel/54.240.217.164-10.142.31.7/require;
EOF
}

declare -a actions
actions[0]="10.142.32.0/21 169.254.255.45 169.254.255.41 us-east-1-via-45 us-east-1-via-41"
#actions[1]="10.142.88.0/21 169.254.88.45 169.254.88.41 foo bar"

while :; do
    ip monitor | \
    while read net via gw rest; do
        if [ "$via" != "via" ]; then
            continue
        fi

        for action in "${actions[@]}"; do

            data=($action)
            network=${data[0]}
            gw1=${data[1]}
            gw2=${data[2]}
            cmd1=${data[3]}
            cmd2=${data[4]}

            if [ "$net" = "$network" ]; then
                logger "aws-routemon: route change, new gw: $gw for $network"

                if [ "$gw" = "$gw1" ]; then
                    $cmd1
                elif [ "$gw" = "$gw2" ]; then
                    $cmd2
                else
                    echo "unknown gw"
                fi
            fi
        done
    done

    sleep 1
done
