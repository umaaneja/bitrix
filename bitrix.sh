#!/bin/bash
LOGS_FILE=$(mktemp /tmp/bitrix-env-XXXXX.log)
RELEASE_FILE=/etc/redhat-release
OS=$(awk '{print $1}' $RELEASE_FILE)
MYSQL_CNF=$HOME/.my.cnf
DEFAULT_SITE=/home/bitrix/www
POOL=0
CONFIGURE_IPTABLES=1
CONFIGURE_FIREWALLD=0
MYVERSION="5.7"     # default mysql version
[[ -z $SILENT ]] && SILENT=0
[[ -z $TEST_REPOSITORY ]] && TEST_REPOSITORY=0

BX_NAME=$(basename $0 | sed -e "s/\.sh$//")
if [[ $BX_NAME == "bitrix-env-crm" || $BX_NAME == "bitrix-env-crm-beta" ]]; then
    BX_PACKAGE="bitrix-env-crm"
    BX_TYPE=crm
else
    BX_PACKAGE="bitrix-env"
    BX_TYPE=general
fi

if [[ $(echo "$BX_NAME" | grep -c beta) -gt 0 ]]; then
    TEST_REPOSITORY=1
fi

bitrix_env_vars(){
MBE0001="Log file path: "
MBE0002="Create management pool after installing $BX_PACKAGE package."
MBE0003="Use silent mode (don't query for information)."
MBE0004="Set server name for management pool creation procedure."
MBE0005="Set root password for MySQL service."
MBE0006="Use alpha/test version of Bitrix Environment."
MBE0007="Use iptables as firewall service daemon (default for Centos 6)"
MBE0008="Use firewalld as firewall service daemon (default for Centos 7 system)"
MBE0009="Examples:"
MBE0010="install $BX_PACKAGE-package and configure management pool:"
MBE0011="install $BX_PACKAGE-package and set mysql root password:"

MBE0012="You have to disable SElinux before installing Bitrix Environment."
MBE0013="You have to reboot the server to disable SELinux"
MBE0014="Do you want to disable SELinux?(Y|n)"
MBE0015="SELinux status changed to disabled in the config file"
MBE0016="Please reboot the system! (cmd: reboot)"

MBE0017="EPEL repository is already configured on the server."
MBE0018="Getting EPEL repository configuration. Please wait."
MBE0019="Error importing the GPG key:"
MBE0020="Error installing the rpm-package:"
MBE0021="EPEL repository has been configured successfully."

MBE0022="Enable main REMI repository"
MBE0023="Disable php 5.6 repository"
MBE0024="Disable php 7.0 repository"
MBE0025="Disable php 7.1 repository"
MBE00251="Disable php 7.2 repository"
MBE00252="Disable php 7.3 repository"
MBE00253="Disable php 7.4 repository"
MBE00254="Disable php 8.0 repository"
MBE00255="Enable php 8.1 repository"


MBE0026="REMI repository is already configured on the server."
MBE0027="Getting REMI repository configuration. Please wait."
MBE0028="Error importing the GPG key:"
MBE0029="Error installing the rpm-package:"
MBE0030="REMI repository has been configured successfully."

MBE0031="Percona repository is already configured on the server."
MBE0032="Error installing the rpm-package:"
MBE0033="Percona repository configuration has been completed."
MBE0034="MariaDB server has been detected. Skipping mariadb-libs uninstallation."
MBE0035="mariadb-libs package has been uninstalled."
MBE0036="MySQL server has been detected. Skipping mysql-libs uninstallation."
MBE0037="mysql-libs package has been uninstalled."

MBE0038="Bitrix repository is already configured on the server."
MBE0039="Getting Bitrix repository configuration. Please wait."
MBE0040="Error importing the GPG key:"
MBE0041="Bitrix repository has been configured."

MBE0042="System update in progress. Please wait."
MBE0043="Error updating the system."

MBE0044="Maximum attempts to set the password has been reached. Exiting."
MBE0045="Enter root password:"
MBE0046="Re-enter root password:"
MBE0047="Sorry, passwords do not match! Please try again."
MBE0048="Sorry, password can't be empty."
MBE0049="MySQL password updated successfully."
MBE0050="MySQL password update failed."
MBE0051="mysql client config file updated:"
MBE0052="Updating MySQL service root password:"
MBE0053="Default mysql client config file not found:"
MBE0054="Empty mysql root password was found, but it does not work."
MBE0055="Temporary mysql root password was found, but it does not work."
MBE0056="Default mysql client config file was found: "
MBE0057="Do you want to update $MYSQL_CNF default config file?(Y|n): "
MBE0058="User has chosen silent mode. Cannot request correct MySQL password."
MBE0059="mysql client config file $MYSQL_CNF updated."
MBE0060="Empty mysql root password was found, you have to change it!"
MBE0061="Temporary mysql root password was found, you have to change it!"
MBE0062="Saved mysql root password was found, you have to change it!"
MBE0063="Saved mysql root password was found, but it does not work."

MBE0064="Do you want to change the root user password for MySQL service?(Y|n) "
MBE0065="Root mysql password test completed"
MBE0066="Root user account has been updated while installing the MySQL service."
MBE0067="You can find password settings in config file: $MYSQL_CNF."
MBE0068="MySQL security configuration has been completed."

MBE0069="This script needs to be run as root to avoid errors."
MBE0070="This script has been tested on CentOS Linux only. Current OS: $OS"

MBE0071="Bitrix Environment for Linux installation script."
MBE0072="Yes will be assumed as a default answer."
MBE0073="Enter 'n' or 'no' for a 'No'. Anything else will be considered a 'Yes'."
MBE0074="This script MUST be run as root, or it will fail."
MBE0075="The script does not support CentOS"
MBE0076="Installing php packages. Please wait."
MBE0077="Installing $BX_PACKAGE package. Please wait."
MBE0078="Installing bx-push-server package. Please wait."
MBE0079="Error installing package:"
MBE0080="iptables modules are disabled in the system. Nothing to do."
MBE0081="Cannot configure firewall on the server. Log file:"
MBE0082="Firewall has been configured."
MBE0083="Cannot create management pool. Log file: "
MBE0084="Management pool has been configured."
MBE0085="Bitrix Environment $BX_PACKAGE has been installed successfully."
MBE0086="Select MySQL version: 5.7 or 8.0 (Version 5.7 is default).
              The option is not working on CentOS 6."

MBE0087="There is no support Percona Server 8.0 for Centos 6. Exit."
}

print(){
    msg=$1
    notice=${2:-0}
    [[ ( $SILENT -eq 0 ) && ( $notice -eq 1 ) ]] && echo -e "${msg}"
    [[ ( $SILENT -eq 0 ) && ( $notice -eq 2 ) ]] && echo -e "\e[1;31m${msg}\e[0m"
    echo "$(date +"%FT%H:%M:%S"): $$ : $msg" >> $LOGS_FILE
}

print_e(){
    msg_e=$1
    print "$msg_e" 2
    print "$MBE0001 $LOGS_FILE" 1
    exit 1
}

help_message(){

    echo "
    Usage: $0 [-h] [-s] [-t] [-p [-H hostname]] [-M mysql_root_password] [-m 5.7|8.0]
         -p - $MBE0002
         -s - $MBE0003
         -H - $MBE0004
         -M - $MBE0005
         -m - $MBE0086
         -t - $MBE0006
         -I - $MBE0007
         -F - $MBE0008
         -h - print help message
    $MBE0009:
         * $MBE0010
         $0 -s -p -H master1
         * $MBE0011
         $0 -s -p -H master1 -M 'password' -m 8.0"
    exit
}

disable_selinux(){
    sestatus_cmd=$(which sestatus 2>/dev/null)
    [[ -z $sestatus_cmd ]] && print "$MBE0012" 1 && return
    [[ -z $(which getenforce 2>/dev/null) ]] && print "$MBE0012" 1 && return
    [[ -z $(which setenforce 2>/dev/null) ]] && print "$MBE0012" 1 && return
    if [[ -n $sestatus_cmd ]]; then
        sestatus=$($sestatus_cmd | awk '{print $3}')
        if [[ -n $sestatus && $sestatus == "enabled" ]]; then
            setenforce 0
            print "$MBE0015" 1
            sed -i "s/^SELINUX=.*/SELINUX=disabled/" /etc/selinux/config
            print "$MBE0016" 1
        fi
    fi
}

configure_epel(){
    if [[ $(yum repolist | grep -c epel/) -eq 0 ]]; then
        print "$MBE0018" 1
        yum -y install epel-release || print_e "$MBE0020 epel-release"
    else
        print "$MBE0017" 1
    fi
    yum -y install yum-utils
    print "$MBE0021" 1
}

configure_remi(){
    if [[ $(yum repolist | grep -c remi/) -eq 0 ]]; then
        print "$MBE0027" 1
        yum -y install https://rpms.remirepo.net/enterprise/remi-release-9.rpm || print_e "$MBE0029 remi-release"
    else
        print "$MBE0026" 1
    fi
    print "$MBE0022" 1
    yum-config-manager --enable remi
    print "$MBE0023" 1
    yum-config-manager --disable remi-php56
    print "$MBE0024" 1
    yum-config-manager --disable remi-php70
    print "$MBE0025" 1
    yum-config-manager --disable remi-php71
    print "$MBE00251" 1
    yum-config-manager --disable remi-php72
    print "$MBE00252" 1
    yum-config-manager --disable remi-php73
    print "$MBE00253" 1
    yum-config-manager --disable remi-php74
    print "$MBE00254" 1
    yum-config-manager --disable remi-php80
    print "$MBE00255" 1
    yum-config-manager --enable remi-php81
    print "$MBE0030" 1
}

configure_percona(){
    if [[ $(yum repolist | grep -c percona/) -eq 0 ]]; then
        print "$MBE0018" 1
        yum -y install https://repo.percona.com/yum/percona-release-latest.noarch.rpm || print_e "$MBE0032 percona-release"
        print "$MBE0033" 1
    else
        print "$MBE0031" 1
    fi
}

configure_bitrix(){
    if [[ $(yum repolist | grep -c bitrix/) -eq 0 ]]; then
        print "$MBE0039" 1
        yum -y install http://repos.1c-bitrix.ru/yum/bitrix-env-release-9.noarch.rpm || print_e "$MBE0041 bitrix-env-release"
    else
        print "$MBE0038" 1
    fi
}

install_packages(){
    print "$MBE0042" 1
    yum -y update || print_e "$MBE0043"
    print "$MBE0076" 1
    yum -y install php php-mysqlnd php-pdo php-gd php-mbstring php-mcrypt php-xml php-pecl-zip php-bcmath php-json php-pecl-redis5 php-opcache php-intl php-soap php-tidy php-pecl-memcache php-pecl-memcached
    print "$MBE0077" 1
    yum -y install $BX_PACKAGE
    print "$MBE0078" 1
    yum -y install bx-push-server
}

configure_mysql(){
    if [[ $MYVERSION == "5.7" ]]; then
        percona_server_version="Percona-Server-server-57"
    else
        percona_server_version="Percona-Server-server-80"
    fi
    if [[ $(rpm -qa | grep -c $percona_server_version) -eq 0 ]]; then
        print "Installing $percona_server_version. Please wait."
        yum -y install $percona_server_version || print_e "$MBE0079 $percona_server_version"
    fi
}

configure_firewall(){
    if [[ $CONFIGURE_IPTABLES -eq 1 ]]; then
        if [[ $(systemctl is-active iptables) != "active" ]]; then
            print "Starting iptables service."
            systemctl start iptables
        fi
        if [[ $(systemctl is-enabled iptables) != "enabled" ]]; then
            print "Enabling iptables service."
            systemctl enable iptables
        fi
        iptables -I INPUT -p tcp --dport 80 -j ACCEPT
        iptables -I INPUT -p tcp --dport 443 -j ACCEPT
        service iptables save || print_e "$MBE0080"
    fi

    if [[ $CONFIGURE_FIREWALLD -eq 1 ]]; then
        if [[ $(systemctl is-active firewalld) != "active" ]]; then
            print "Starting firewalld service."
            systemctl start firewalld
        fi
        if [[ $(systemctl is-enabled firewalld) != "enabled" ]]; then
            print "Enabling firewalld service."
            systemctl enable firewalld
        fi
        firewall-cmd --permanent --add-service=http
        firewall-cmd --permanent --add-service=https
        firewall-cmd --reload
    fi
    print "$MBE0082" 1
}

create_pool(){
    if [[ $POOL -eq 1 ]]; then
        [[ -n $HOSTNAME ]] && hostnamectl set-hostname $HOSTNAME
        /opt/webdir/bin/bx-sites -a create_pool -H $HOSTNAME -P $MYSQL_ROOT_PASSWORD > /dev/null 2>&1
        [[ $? -ne 0 ]] && print_e "$MBE0083 $LOGS_FILE"
        print "$MBE0084" 1
    fi
}

main(){
    bitrix_env_vars

    while getopts "hspH:M:m:tIF" opt; do
        case ${opt} in
            h )
                help_message
                ;;
            s )
                SILENT=1
                ;;
            p )
                POOL=1
                ;;
            H )
                HOSTNAME=$OPTARG
                ;;
            M )
                MYSQL_ROOT_PASSWORD=$OPTARG
                ;;
            m )
                MYVERSION=$OPTARG
                ;;
            t )
                TEST_REPOSITORY=1
                ;;
            I )
                CONFIGURE_IPTABLES=1
                CONFIGURE_FIREWALLD=0
                ;;
            F )
                CONFIGURE_IPTABLES=0
                CONFIGURE_FIREWALLD=1
                ;;
            \? )
                help_message
                ;;
        esac
    done
    shift $((OPTIND -1))

    [[ $EUID -ne 0 ]] && print_e "$MBE0069"
    [[ $OS != "CentOS" ]] && print_e "$MBE0070"

    disable_selinux
    configure_epel
    configure_remi
    configure_percona
    configure_bitrix
    install_packages
    configure_mysql
    configure_firewall
    create_pool

    print "$MBE0085" 1
    exit 0
}

main "$@"
