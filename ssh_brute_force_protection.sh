#!/bin/bash

# ssh_brute_protection.sh

# Configuration file
CONFIG_FILE="/etc/ssh_brute_protection.conf"
source "$CONFIG_FILE"

# Checking if the script is run by root user
if [[ $EUID -ne 0 ]]; then
   echo "This script must be run as root" 
   exit 1
fi

# Function to read configuration
#function read_config() {
#    while IFS='=' read -r key value; do
#        declare "$key"="$value"
#    done < "$CONFIG_FILE"
#}

# Function to log events
log_event() {
    echo "$(date '+%Y-%m-%d %H:%M:%S') $1" >> /var/log/ssh_brute_protection.log
}

# Function to check if IP is banned
is_banned() {
    local ip=$1
    grep -q "^$ip$" "$BAN_LIST_FILE" && return 0 || return 1
}

# Function to ban IP
ban_ip() {
    local ip=$1
    echo "$ip" >> "$BAN_LIST_FILE"
    firewall-cmd --zone=public --add-rich-rule="rule family='ipv4' source address='$ip' reject" --permanent
    firewall-cmd --reload
    log_event "IP $ip banned"
}

# Function to unban IP
unban_ip() {
    local ip=$1
    sed -i "/^$ip$/d" "$BAN_LIST_FILE"
    firewall-cmd --zone=public --remove-rich-rule="rule family='ipv4' source address='$ip' reject" --permanent
    firewall-cmd --reload
    log_event "IP $ip unbanned"
}

# Main function
main() {
    # Initialize variables
    #BAN_LIST_FILE="/var/log/banned_ips.txt"
    #MAX_ATTEMPTS=${MAX_ATTEMPTS:-3}
    #BAN_TIME=${BAN_TIME:-3600}
    
    # Check if config file exists
    if [ ! -f "$CONFIG_FILE" ]; then
        echo "Configuration file not found. Exiting."
        exit 1
    fi
    
    # Read configuration
    #read_config
    
    # Check if firewalld is installed, if not install it
    if ! command -v firewall-cmd &> /dev/null; then
        if [ -x "$(command -v yum)" ]; then
            yum install -y firewalld
        elif [ -x "$(command -v apt-get)" ]; then
            apt-get install -y firewalld
        else
            echo "Error: firewalld installation method not found."
            exit 1
        fi
        systemctl start firewalld
        systemctl enable firewalld
    fi
    
    # Check if BAN_LIST_FILE exists, create if not
    if [ ! -f "$BAN_LIST_FILE" ]; then
        touch "$BAN_LIST_FILE"
    fi
    
    # Start SSH monitoring
    while true; do
        # Check SSH logs for failed login attempts
        grep "Failed password for invalid user" /var/log/auth.log | awk '{print $(NF-3)}' | sort | uniq -c | awk -v max_attempts="$MAX_ATTEMPTS" '$1 > max_attempts {print $2}' | while read -r ip; do
            
            # Check if IP is already banned
            if ! is_banned "$ip"; then
                ban_ip "$ip"
                
                # Schedule unban
                (sleep "$BAN_TIME"; unban_ip "$ip") &
            fi
        done
        
        sleep 60
    done
}

# Run main function
main



#This script does the following:

#1. It reads configuration from a file specified by `CONFIG_FILE`.
#2. It monitors SSH logs for failed login attempts.
#3. When a failed attempt is detected, it checks if the IP is already banned.
#4. If not banned, it bans the IP by adding it to the `BAN_LIST_FILE` 
#   and it creates dynamic firewalld rules to reject every incoming network traffic from the attacking IP.
#5. It includes logging functionality to keep track of events.
#6. DDoS attack prevention: with the help of awk it is capable of aggregating IP addresses and block large numbers of attempts.
#6. The script can be run as a systemd service.

#To make this script configurable as a systemd service:

#1. Save it as `/usr/local/bin/ssh_brute_protection.sh`.
#2. Create a configuration file at `/etc/ssh_brute_protection.conf` with the following content:
#   MAX_ATTEMPTS=3 #default value
#   BAN_LIST_FILE=/var/log/banned_ips.txt
#   BAN_TIME=3600 # default value in seconds

#3. Create a systemd service file at `/etc/systemd/system/ssh-brute-protection.service`:
#   [Unit]
#   Description=SSH Brute Force Protection
#   After=network.target
#
#   [Service]
#   ExecStart=/usr/local/bin/ssh_brute_protection.sh
#   Restart=always
#
#   [Install]
#   WantedBy=multi-user.target

#4. Enable and start the service:
#   sudo systemctl enable ssh-brute-protection.service
#   sudo systemctl start ssh-brute-protection.service

#This implementation provides a basic framework for preventing SSH brute force attacks. You may want to enhance it by adding more sophisticated logging, rate limiting, and additional configuration options based on your specific needs.