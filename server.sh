#!/bin/bash


RED="\033[0;31m"
NC="\033[0m" 
ACCOUNT="" 

json='[
    {"host": "test.com", "user": "root", "pass": "test123", "mysql_user": "root", "mysql_pass": "test123"},
    {"host": "test1.com", "user": "root", "pass": "test123", "mysql_user": "root", "mysql_pass": "test123"}
]'

for row in $(echo "$json" | jq -c '.[]'); do

WHM_HOST=$(echo "$row" | jq -r '.host')
SSH_USER=$(echo "$row" | jq -r '.user')
BACKUP_DIR="/backup/" 
LOCAL_BASE_DIR="/home/user/Desktop/" 
SSH_PASS=$(echo "$row" | jq -r '.pass') 
MYSQL_USER=$(echo "$row" | jq -r '.mysql_user')
MYSQL_PASS=$(echo "$row" | jq -r '.mysql_pass')
HOST_DIR="$LOCAL_BASE_DIR$WHM_HOST"
    
 if [ -z "$ACCOUNT" ]; then
        # If ACCOUNT is empty, back up all accounts
        usernames=$(sshpass -p "$SSH_PASS" ssh -o StrictHostKeyChecking=no "$SSH_USER@$WHM_HOST" "ls /var/cpanel/users")
    else
        # If ACCOUNT is specified, check if it exists on the server
        if sshpass -p "$SSH_PASS" ssh -o StrictHostKeyChecking=no "$SSH_USER@$WHM_HOST" "ls /var/cpanel/users | grep -w $ACCOUNT" > /dev/null 2>&1; then
            usernames=$ACCOUNT
        else
            echo -e "${RED}Account $ACCOUNT does not exist on $WHM_HOST.${NC}"
            continue
        fi
    fi
mkdir -p "$HOST_DIR"
# پردازش هر حساب
for user in $usernames; do
    echo -e "${RED}Processing account: $user${NC}"
    TIMESTAMP=$(date +"%Y-%m-%d_%H-%M-%S")
    LOCAL_DIR="$HOST_DIR/${user}_$TIMESTAMP"
    mkdir -p "$LOCAL_DIR"
    sshpass -p "$SSH_PASS" ssh -o StrictHostKeyChecking=no $SSH_USER@$WHM_HOST "/scripts/pkgacct $user $BACKUP_DIR"
    sshpass -p "$SSH_PASS" scp -o StrictHostKeyChecking=no "$SSH_USER@$WHM_HOST:$BACKUP_DIR/cpmove-$user.tar.gz" "$LOCAL_DIR/"
    sshpass -p "$SSH_PASS" ssh -o StrictHostKeyChecking=no $SSH_USER@$WHM_HOST "rm -f $BACKUP_DIR/cpmove-$user.tar.gz"

    databases=$(sshpass -p "$SSH_PASS" ssh -o StrictHostKeyChecking=no $SSH_USER@$WHM_HOST "mysql -u$MYSQL_USER -p'$MYSQL_PASS' -e 'SHOW DATABASES;' | grep '^${user}_'")

    for db in $databases; do
        echo "Backing up database: $db"
        sshpass -p "$SSH_PASS" ssh -o StrictHostKeyChecking=no $SSH_USER@$WHM_HOST "mysqldump -u$MYSQL_USER -p'$MYSQL_PASS' $db > $BACKUP_DIR/$db.sql"

        sshpass -p "$SSH_PASS" scp -o StrictHostKeyChecking=no "$SSH_USER@$WHM_HOST:$BACKUP_DIR/$db.sql" "$LOCAL_DIR/"

        sshpass -p "$SSH_PASS" ssh -o StrictHostKeyChecking=no $SSH_USER@$WHM_HOST "rm -f $BACKUP_DIR/$db.sql"
    done

    echo "Backup completed for account: $user. Local path: $LOCAL_DIR"
done

echo -e "${RED}All backups processed.${NC}"

done
