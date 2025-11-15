#!/bin/bash

########################
### helper functions ###
########################

# $1 = error message
# $2 = Option Num
error_exit() {
    log_and_echo "ERROR" "$1" "$2"

    exit 1
}

# $1 = Log Level
# $2 = message
# $3 = Option Num
log_and_echo() {
    printf -v date '%(%Y-%m-%d %H:%M:%S)T'
    echo -e "$date\t$1\t$2\tRunning Option: $3" >> easyrsa_ynsjk.log
    echo -e "$date\t$1\t$2"
}

########################
### Opiton Functions ###
########################

generate_certificate_and_key() {
    log_and_echo "INFO" "Reading local_dest from ./script.conf" "0"
    local_dest_path=$(cat script.conf | grep local_dest | awk '{print $2}' | tr -d '\n')
    log_and_echo "INFO" "Got value ($local_dest_path) from ./script.conf" "0"

    read -p "Copy certificate and key to $local_dest_path ? (y/n): " handler_local
    log_and_echo "INFO" "Got value ($handler_local) for copy local from user" "0"

    # ask if certs need to be copied to remote via scp
    read -p "Copy certificate and key to remote server? (y/n): " handler_remote
    log_and_echo "INFO" "Got value ($handler_remote) for copy remote from user" "0"

    # get base file name
    read -p "Base-name of the cert and key file that will be generated: " file_base_name
    log_and_echo "INFO" "Got value ($file_base_name) for file base name from user" "0"

    # check if cert is present
    log_and_echo "INFO" "Checking if certificate with name $file_base_name.crt already exists" "0"
    if [ -e ./pki/issued/$file_base_name.crt ]; then
        error_exit "Certificate $file_base_name.crt exists. First, run option 2 of this script b4 generating a new one" "0"
    fi
    log_and_echo "INFO" "Certificate does not exist... continue" "0"

    log_and_echo "INFO" "Checking if key with name $file_base_name.key already exists" "0"
    # check if key exists
    if [ -e ./pki/private/$file_base_name.key ]; then
        error_exit "Key $file_base_name.key exists. First, run option 2 of this script b4 generating a new one" "0"
    fi
    log_and_echo "INFO" "Key does not exist... continue" "0"

    log_and_echo "INFO" "Getting SAN" "0"
    # get SAN Field
    echo -e "\n"
    echo -e "Please provide a SAN (Subject Alternative Name) string!\nThe san string can be multivalue (comma-separated)"
    echo -e "Here are some examples\n"
    echo "-------------------------"
    echo "single value:"
    echo -e "DNS:primary.example.net"
    echo ""
    echo "multi value:"
    echo "DNS:primary.example.net,IP:192.168.1.1"
    echo -e "-------------------------\n"
    read -p "" san

    # get validity time
    echo ""
    read -p "How many days should the certificate be valid? (ideal would be 365): " cert_valid_days
    log_and_echo "INFO" "Got value ($cert_valid_days) for certificate validity period in days from user" "0"
    
    # exec command
    log_and_echo "INFO" "Trying to generate certificate and key" "0"
    bash easyrsa --san=$san --days=$cert_valid_days build-server-full $file_base_name nopass || error_exit "Error generating certificate and key" "0"
    log_and_echo "INFO" "Certificate and key successfully generated!" "0"

    if [ $handler_local == "y" ]; then
        copy_crt_and_key_to_local_dir $file_base_name $local_dest_path
    fi

    if [ $handler_remote == "y" ]; then
        copy_crt_and_key_to_remote_server $file_base_name
    fi
}

delete_cert_and_key_local_path() {
    # get base file name
    read -p "Base-name of the cert and key file: " file_base_name
    log_and_echo "INFO" "Got value ($file_base_name) for file base name from user" "1"

    log_and_echo "INFO" "Reading local_dest from ./script.conf" "1"
    local_dest_path=$(cat script.conf | grep local_dest | awk '{print $2}' | tr -d '\n')
    log_and_echo "INFO" "Got value ($local_dest_path) from ./script.conf" "1"

    log_and_echo "INFO" "Trying to delete $local_dest_path$file_base_name.key" "1"
    rm $local_dest_path$file_base_name.key || error_exit "Could not delete key in path ($local_dest_path)" "1"
    log_and_echo "INFO" "Successfully deleted key!" "1"

    log_and_echo "INFO" "Trying to delete $local_dest_path$file_base_name.crt" "1"
    rm $local_dest_path$file_base_name.crt || error_exit "Could not delete crt in path ($local_dest_path)" "1"
    log_and_echo "INFO" "Successfully deleted certificate!" "1"
}

delete_cert_and_key_in_pki() {
    read -p "What is the base name of the cert and key file?: " name
    log_and_echo "INFO" "Got value ($name) for file base name from user" "2"

    # check, if cert exists
    log_and_echo "INFO" "Checking if certificate with name $name.crt already exists" "2"
    if [ -e ./pki/issued/$name.crt ]; then
        log_and_echo "INFO" "found certificate" "2"
    else
        error_exit "Key does not exist!" "2"
    fi

    # check, if key exists
    log_and_echo "INFO" "Checking if key with name $name.key already exists" "2"
    if [ -e ./pki/private/$name.key ]; then
        log_and_echo "INFO" "found key" "2"
    else
        error_exit "Key does not exist!" "2"
    fi

    log_and_echo "INFO" "Trying to revoke $name" "2"
    bash easyrsa revoke $name
    log_and_echo "INFO" "Successfully revoked $name (Certificate and Key)" "2"
}

# $1 = file_base_name
copy_crt_and_key_to_local_dir() {
    log_and_echo "INFO" "Reading local_dest from ./script.conf" "3"
    local_dest_path=$(cat script.conf | grep local_dest | awk '{print $2}' | tr -d '\n')
    log_and_echo "INFO" "Got value ($local_dest_path) from ./script.conf" "3"

    log_and_echo "INFO" "Trying to copy certificate and key to $local_dest_path" "3"

    cp pki/issued/$1.crt $local_dest_path || error_exit "Could not copy certificate ($1.crt) to path ($local_dest_path)" "3"
    cp pki/private/$1.key $local_dest_path || error_exit "Could not copy key ($1.key) to path ($local_dest_path)" "3"

    log_and_echo "INFO" "Copied certificate and key to $local_dest_path." "3"
}

# $1 == file_base_name
copy_crt_and_key_to_remote_server() {

    log_and_echo "INFO" "Reading scp_user from ./script.conf" "4"
    scp_user=$(cat script.conf | grep scp_user | awk '{print $2}' | tr -d '\n')
    log_and_echo "INFO" "Got value ($scp_user) from ./script.conf" "4"

    log_and_echo "INFO" "Reading scp_dest_dir from ./script.conf" "4"
    scp_dest_path=$(cat script.conf | grep scp_dest_dir | awk '{print $2}' | tr -d '\n')
    log_and_echo "INFO" "Got value ($scp_dest_path) from ./script.conf" "4"

    read -s -p "Password for user $scp_user: " scp_pass
    echo ""
    read -s -p "repeat password: " scp_pass_1
    echo ""

    if [ $scp_pass != $scp_pass_1 ]; then
        error_exit "Passwords dont match... Try again" "4"
    fi
    log_and_echo "INFO" "Successfully got password from user" "4"

    read -p "Hostname or IP of the remote host: " scp_host
    log_and_echo "INFO" "Got value ($scp_host) for destination host from user" "4"

    # put cert
    log_and_echo "INFO" "Trying to copy certificate to remote server" "4"
    sshpass -p "$scp_pass" scp pki/issued/$1.crt $scp_user@$scp_host:$scp_dest_path || error_exit "Error copying certificate to remote server" "4"
    log_and_echo "INFO" "Successfully copied certificate to remote server" "4"

    # put key
    log_and_echo "INFO" "Trying to copy key to remote server" "4"
    sshpass -p "$scp_pass" scp pki/private/$1.key $scp_user@$scp_host:$scp_dest_path || error_exit "Error copying key to remote server" "4"
    log_and_echo "INFO" "Successfully copied certificate to remote server" "4"
}

list_cert_expire_date() {
    echo ""
    for cert in $(ls pki/issued);
    do
        enddate=$(cat pki/issued/$cert | openssl x509 -noout -enddate)
        log_and_echo "INFO" "Zertifikat $cert: $enddate" "5"
    done;
}

############
### MAIN ###
############
local_dest_path=$(cat script.conf | grep local_dest | awk '{print $2}' | tr -d '\n')

echo "###################"
echo "##### Options #####"
echo "###################"
echo ""
echo "0: Generate web-certificate and key for server"
echo "1: Delete certificate and key from $local_dest_path"
echo "2: Delete certificate and key from local PKI"
echo "3: Copy existing certificate to $local_dest_path"
echo "4: Copy existing certificate to remote server"
echo "5: List expiry date of all certificates in PKI"

read -p "Option to execute: " opt

case $opt in
    0)
        generate_certificate_and_key
    ;;
    1)
        delete_cert_and_key_local_path
    ;;
    2)
        delete_cert_and_key_in_pki
    ;;
    3)
        read -p "Base-name of the cert and key file: " file_base_name
        log_and_echo "INFO" "Got value ($file_base_name) for file base name from user" "3"
        
        copy_crt_and_key_to_local_dir $file_base_name
    ;;
    4)
        read -p "Base-name of the cert and key file: " file_base_name
        log_and_echo "INFO" "Got value ($file_base_name) for file base name from user" "4"
        
        copy_crt_and_key_to_remote_server $file_base_name
    ;;
    5)
        list_cert_expire_date
    ;;
    *)
        error_exit "Option ($opt) is not valid" "-"
    ;;
esac

log_and_echo "SUCCESS" "Script finished without error!" "-"
exit 0