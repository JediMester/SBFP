# SBFP
SSH brute force and DDoS attack protection

The script does the following:

1. It reads configuration from a file specified by `CONFIG_FILE`.
2. It monitors SSH logs for failed login attempts.
3. When a failed attempt is detected, it checks if the IP is already banned.
4. If not banned, it bans the IP by adding it to the `BAN_LIST_FILE` 
   and it creates dynamic firewalld rules to reject every incoming network traffic from the attacking IP.
5. It includes logging functionality to keep track of events.
6. DDoS attack prevention: with the help of awk it is capable of aggregating IP addresses and block large numbers of attempts.
6. The script can be run as a systemd service.

To make this script configurable as a systemd service:
1. Save it as `/usr/local/bin/ssh_brute_protection.sh`.
2. Create a configuration file at `/etc/ssh_brute_protection.conf` with the following content:
   MAX_ATTEMPTS=3 #default value
   BAN_LIST_FILE=/var/log/banned_ips.txt
   BAN_TIME=3600 # default value in seconds
3. Create a systemd service file at `/etc/systemd/system/ssh-brute-protection.service`:
   [Unit]
   Description=SSH Brute Force Protection
   After=network.target

   [Service]
   ExecStart=/usr/local/bin/ssh_brute_protection.sh
   Restart=always

   [Install]
   WantedBy=multi-user.target
4. Enable and start the service:
   sudo systemctl enable ssh-brute-protection.service
   sudo systemctl start ssh-brute-protection.service
5. Enjoy! :)
