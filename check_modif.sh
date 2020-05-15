#!/bin/bash
[ ` find /etc/crontab -mmin -1440 ` ] && echo "crontab was modified in the last 24h" | mailx -s "crontab alert" root@roguehost 
