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

print() {
    local msg=$1
    local notice=${2:-0}
    if [[ $SILENT -eq 0 && $notice -eq 1 ]]; then
        echo -e "${msg}"
    elif [[ $SILENT -eq 0 && $notice -eq 2 ]]; then
        echo -e "\e[1;31m${msg}\e[0m"
    fi
    echo "$(date +"%FT%H:%M:%S") : $$ : $msg" >> "$LOGS_FILE"
}

print_e() {
    local msg_e=$1
    print "$msg_e" 2
    print "$MBE0001 $LOGS_FILE" 1
    exit 1
}

help_message() {
    cat << EOF
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
         $0 -s -p -H master1 -M 'password' -m 8.0
EOF
    exit
}

disable_selinux() {
    local sestatus_cmd=$(command -v sestatus 2>/dev/null)
    [[ -z $sestatus_cmd ]] && return 0

    local sestatus=$($sestatus_cmd | awk -F':' '/SELinux status:/{print $2}' | sed -e "s/\s\+//g")
    local seconfigs="/etc/selinux/config /etc/sysconfig/selinux"
    
    if [[ $sestatus != "disabled" ]]; then
        print "$MBE0012" 1
        print "$MBE0013"
        read -r -p "$MBE0014 " DISABLE
        [[ -z $DISABLE ]] && DISABLE=y
        [[ $(echo $DISABLE | grep -wci "y") -eq 0 ]] && print_e "Exit."
        for seconfig in $seconfigs; do
            [[ -f $seconfig ]] && \
                sed -i "s/SELINUX=\(enforcing\|permissive\)/SELINUX=disabled/" $seconfig && \
                print "$MBE0015 $seconfig." 1
        done
        print "$MBE0016" 1
        exit
    fi
}


configure_epel() {
    EPEL=$(dnf list installed | grep -c 'epel-release')
    if [[ $EPEL -gt 0 ]]; then
        print "$MBE0017" 1
        return 0
    fi

    print "$MBE0018" 1

    # Determine CentOS version
    if [[ $VER -eq 8 ]]; then
        LINK="https://dl.fedoraproject.org/pub/epel/epel-release-latest-8.noarch.rpm"
        GPGK="https://dl.fedoraproject.org/pub/epel/RPM-GPG-KEY-EPEL-8"
    elif [[ $VER -eq 9 ]]; then
        LINK="https://dl.fedoraproject.org/pub/epel/epel-release-latest-9.noarch.rpm"
        GPGK="https://dl.fedoraproject.org/pub/epel/RPM-GPG-KEY-EPEL-9"
    else
        print_e "Unsupported CentOS version $VER detected."
    fi

    dnf install -y "$LINK" >>"$LOGS_FILE" 2>&1 || \
        print_e "$MBE0020 $LINK"

    rpm --import "$GPGK" >>"$LOGS_FILE" 2>&1 || \
        print_e "$MBE0019 $GPGK"

    dnf config-manager --set-enabled PowerTools >>"$LOGS_FILE" 2>&1 || \
        print_e "$MBE0079 EPEL"

    print "$MBE0021" 1
}

configure_epel_delete() {
    EPEL=$(rpm -qa | grep -c 'epel-release')
    if [[ $EPEL -gt 0 ]]; then
        print "$MBE0017" 1
        return 0
    fi

    print "$MBE0018" 1

    # Determine CentOS version
    if [[ $VER -eq 6 ]]; then
        LINK="https://dl.fedoraproject.org/pub/epel/epel-release-latest-6.noarch.rpm"
        GPGK="https://dl.fedoraproject.org/pub/epel/RPM-GPG-KEY-EPEL-6"
    elif [[ $VER -eq 7 ]]; then
        LINK="https://dl.fedoraproject.org/pub/epel/epel-release-latest-7.noarch.rpm"
        GPGK="https://dl.fedoraproject.org/pub/epel/RPM-GPG-KEY-EPEL-7"
    elif [[ $VER -eq 8 ]]; then
        LINK="https://dl.fedoraproject.org/pub/epel/epel-release-latest-8.noarch.rpm"
        GPGK="https://dl.fedoraproject.org/pub/epel/RPM-GPG-KEY-EPEL-8"
    else
        print_e "Unsupported CentOS version $VER detected."
    fi

    rpm --import "$GPGK" >>"$LOGS_FILE" 2>&1 || \
        print_e "$MBE0019 $GPGK"
    rpm -Uvh "$LINK" >>"$LOGS_FILE" 2>&1 || \
        print_e "$MBE0020 $LINK"

    yum clean all >/dev/null 2>&1
    yum install -y yum-fastestmirror >/dev/null 2>&1

    print "$MBE0021" 1
}

pre_php() {
    print "$MBE0022"

    # Enable remi repository
    sed -i -e '/\[remi\]/,/^\[/s/enabled=0/enabled=1/' /etc/yum.repos.d/remi.repo

    # Disable older PHP versions in remi repository
    sed -i -e '/\[remi-php56\]/,/^\[/s/enabled=1/enabled=0/' /etc/yum.repos.d/remi.repo
    sed -i -e '/\[remi-php70\]/,/^\[/s/enabled=1/enabled=0/' /etc/yum.repos.d/remi.repo
    sed -i -e '/\[remi-php71\]/,/^\[/s/enabled=1/enabled=0/' /etc/yum.repos.d/remi.repo
    sed -i -e '/\[remi-php72\]/,/^\[/s/enabled=1/enabled=0/' /etc/yum.repos.d/remi.repo
    sed -i -e '/\[remi-php73\]/,/^\[/s/enabled=1/enabled=0/' /etc/yum.repos.d/remi.repo
    sed -i -e '/\[remi-php74\]/,/^\[/s/enabled=1/enabled=0/' /etc/yum.repos.d/remi.repo
    sed -i -e '/\[remi-php80\]/,/^\[/s/enabled=1/enabled=0/' /etc/yum.repos.d/remi.repo
    sed -i -e '/\[remi-php81\]/,/^\[/s/enabled=1/enabled=0/' /etc/yum.repos.d/remi.repo

    # Enable PHP 8.1 in remi-php81 repository
    sed -i -e '/\[remi-php81\]/,/^\[/s/enabled=0/enabled=1/' /etc/yum.repos.d/remi-php81.repo

    # Remove php-pecl-xhprof if needed
    if [[ $is_xhprof -gt 0 ]]; then
        yum -y remove php-pecl-xhprof
    fi

    print "PHP repository configuration completed." 1
}

configure_remi() {
    REMI=$(dnf list installed | grep -c 'remi-release')
    if [[ $REMI -gt 0 ]]; then
        print "$MBE0026" 1
        return 0
    fi

    print "$MBE0027" 1

    # Determine CentOS version and set repository URLs
    if [[ $VER -eq 8 ]]; then
        LINK="https://rpms.remirepo.net/enterprise/remi-release-8.rpm"
        GPGK="https://rpms.remirepo.net/RPM-GPG-KEY-remi"
    elif [[ $VER -eq 9 ]]; then
        LINK="https://rpms.remirepo.net/enterprise/remi-release-9.rpm"
        GPGK="https://rpms.remirepo.net/RPM-GPG-KEY-remi"
    else
        print_e "Unsupported CentOS version $VER detected."
    fi

    dnf install -y "$LINK" >>"$LOGS_FILE" 2>&1 || \
        print_e "$MBE0029 $LINK"

    rpm --import "$GPGK" >>"$LOGS_FILE" 2>&1 || \
        print_e "$MBE0028 $GPGK"

    dnf config-manager --set-enabled remi >>"$LOGS_FILE" 2>&1 || \
        print_e "$MBE0079 Remi"

    print "$MBE0030" 1
}



configure_percona() {
    REPOTEST=$(rpm -qa | grep -c 'percona-release')
    if [[ $REPOTEST -gt 0 ]]; then
        print "$MBE0031" 1
        return 0
    fi

    print "Configuring Percona repository." 1

    LINK="http://repo.percona.com/release/percona-release-latest.noarch.rpm"
    rpm -Uvh "$LINK" >>"$LOGS_FILE" 2>&1 || \
        print_e "$MBE0032 $LINK"

    yum -y --nogpg update percona-release >>"$LOGS_FILE" 2>&1
    which percona-release >>"$LOGS_FILE" 2>&1

    print "$MBE0033" 1

    if [[ $MYVERSION == "8.0" || $MYVERSION == "80" ]]; then
        percona-release enable ps-80 release >>"$LOGS_FILE" 2>&1
    else
        percona-release setup -y ps57 >>"$LOGS_FILE" 2>&1
    fi
}



configure_nodejs() {
  curl --silent --location https://rpm.nodesource.com/setup_current.x | bash - >/dev/null 2>&1
  dnf install -y nodejs >>"$LOGS_FILE" 2>&1 || \
    print_e "$MBE0079 nodejs"
}

prepare_percona_install() {
    INSTALLED_PACKAGES=$(rpm -qa)

    # Remove MariaDB packages if installed
    if [[ $(echo "$INSTALLED_PACKAGES" | grep -c "mariadb") -gt 0 ]]; then
        MARIADB_PACKAGES=$(echo "$INSTALLED_PACKAGES" | grep "mariadb")
        if [[ $(echo "$MARIADB_PACKAGES" | grep -vc "mariadb-libs") -gt 0 ]]; then
            print "$MBE0034"
        else
            yum -y remove mariadb-libs >/dev/null 2>&1
            print "$MBE0035"
        fi
    fi

    # Remove MySQL packages if installed
    if [[ $(echo "$INSTALLED_PACKAGES" | grep -c "mysql") -gt 0 ]]; then
        MYSQL_PACKAGES=$(echo "$INSTALLED_PACKAGES" | grep "mysql-libs")
        if [[ $(echo "$MYSQL_PACKAGES" | grep -vc "mysql-libs") -gt 0 ]]; then
            print "$MBE0036"
        else
            yum -y remove mysql-libs >/dev/null 2>&1
            print "$MBE0037"
        fi
    fi
}

configure_exclude() {
    if [[ $(grep -c "exclude" /etc/yum.conf) -gt 0 ]]; then
        sed -i \
            's/^exclude=.\+/exclude=ansible1.9,mysql,mariadb,mariadb-*,Percona-XtraDB-*,Percona-*-55,Percona-*-56,Percona-*-51,Percona-*-50/' \
            /etc/yum.conf
    else
        echo 'exclude=ansible1.9,mysql,mariadb,mariadb-*,Percona-XtraDB-*,Percona-*-55,Percona-*-56,Percona-*-51,Percona-*-50' >> /etc/yum.conf
    fi

    if [[ $(grep -v '^$\|^#' /etc/yum.conf | grep -c "installonly_limit") -eq 0 ]]; then
        echo "installonly_limit=3" >> /etc/yum.conf
    else
        if [[ $(grep -v '^$\|^#' /etc/yum.conf | grep -c "installonly_limit=5") -gt 0 ]]; then
            sed -i "s/installonly_limit=5/installonly_limit=3/" /etc/yum.conf
        fi
    fi
}

test_bitrix() {
    if [[ $TEST_REPOSITORY -eq 1 ]]; then
        REPO=yum-beta 
        REPONAME=bitrix-beta
    elif [[ $TEST_REPOSITORY -eq 2 ]]; then
        REPO=yum-testing
        REPONAME=bitrix-testing
    else
        REPO=yum
        REPONAME=bitrix
    fi

    IS_BITRIX_REPO=$(yum repolist enabled | grep "^$REPONAME" -c)
    if [[ $IS_BITRIX_REPO -gt 0 ]]; then
        print "$MBE0038" 1

        REPO_INSTALLED=$(grep -v '^$\|^#' /etc/yum.repos.d/bitrix.repo | awk -F'=' '/baseurl=/{print $2}' | awk -F'/' '{print $4}')

        if [[ "$REPO_INSTALLED" != "$REPO" ]]; then
            print "$MBE0038" 1
            return 1
        fi
    fi

    return 0
}

configure_bitrix() {
  test_bitrix || return 1

  print "$MBE0039" 1

  # Use dnf for key import and repository configuration
  sudo dnf config-manager --add-repo https://repo.bitrix.info/$REPO/el/$VER >> "$LOGS_FILE" 2>&1 || \
    print_e "$MBE0079 Bitrix repo"

  print "$MBE0041" 1
}

configure_bitrix_old() {
    test_bitrix || return 1

    print "$MBE0039" 1

    # Import Bitrix GPG key
    GPGK="https://repo.bitrix.info/yum/RPM-GPG-KEY-BitrixEnv"
    rpm --import "$GPGK" >> "$LOGS_FILE" 2>&1 || \
        print_e "$MBE0040 $GPGK"

    # Configure Bitrix repository
    REPOF=/etc/yum.repos.d/bitrix.repo
    echo "[$REPONAME]" > "$REPOF"
    echo "name=\$OS \$releasever - \$basearch" >> "$REPOF"
    echo "failovermethod=priority" >> "$REPOF"
    echo "baseurl=https://repo.bitrix.info/$REPO/el/$VER/\$basearch" >> "$REPOF"
    echo "enabled=1" >> "$REPOF"
    echo "gpgcheck=1" >> "$REPOF"
    echo "gpgkey=$GPGK" >> "$REPOF"

    print "$MBE0041" 1
}

yum_update() {
  print "$MBE0042" 1
  dnf upgrade --refresh -y >>"$LOGS_FILE" 2>&1 || \
    print_e "$MBE0043"
}




ask_for_password() {
    MYSQL_ROOTPW=
    limit=5
    until [[ -n "$MYSQL_ROOTPW" ]]; do
        password_check=

        if [[ $limit -eq 0 ]]; then
            print "$MBE0044"
            return 1
        fi
        limit=$(( $limit - 1 ))

        read -s -r -p "$MBE0045" MYSQL_ROOTPW
        echo
        read -s -r -p "$MBE0046" password_check
        echo

        if [[ ( -n "$MYSQL_ROOTPW" ) && ( "$MYSQL_ROOTPW" = "$password_check" ) ]]; then
            :
        else
            [[ "$MYSQL_ROOTPW" != "$password_check" ]] && \
                print "$MBE0047"

            [[ -z "$MYSQL_ROOTPW" ]] && \
                print "$MBE0048"
            MYSQL_ROOTPW=
        fi
    done
}

update_mysql_rootpw() {
    esc_pass=$(basic_single_escape "$MYSQL_ROOTPW")
    
    if [[ $MYSQL_UNI_VERSION -ge 57 ]]; then
        my_query "ALTER USER 'root'@'localhost' IDENTIFIED BY '$esc_pass';" \
            "$mysql_update_config"
        my_query_rtn=$?
    else
        my_query \
            "UPDATE mysql.user SET Password=PASSWORD('$esc_pass') WHERE User='root'; FLUSH PRIVILEGES;" \
            "$mysql_update_config"
        my_query_rtn=$?
    fi

    if [[ $my_query_rtn -eq 0 ]]; then
        log_to_file "$MBE0048"
        print "$MBE0049" 1
        rm -f "$mysql_update_config"
    else
        log_to_file "$MBE0050"
        rm -f "$mysql_update_config"
        return 1
    fi

    my_config
    log_to_file "$MBE0051 $MYSQL_CNF"
    print "$MBE0051 $MYSQL_CNF" 1
}

configure_mysql_passwords() {
    [[ -z $MYSQL_VERSION ]] && get_mysql_package

    my_start

    log_to_file "$MBE0052 $MYSQL_VERSION($MYSQL_UNI_VERSION)"

    ASK_USER_FOR_PASSWORD=0

    if [[ ! -f $MYSQL_CNF ]]; then
        log_to_file "$MBE0053 $MYSQL_CNF"

        if [[ $MYSQL_UNI_VERSION -ge 57 ]]; then
            MYSQL_LOG_FILE=/var/log/mysqld.log
            MYSQL_ROOTPW=$(grep 'temporary password' $MYSQL_LOG_FILE | awk '{print $NF}')
            MYSQL_ROOTPW_TYPE=temporary
        else
            MYSQL_ROOTPW=
            MYSQL_ROOTPW_TYPE=empty
        fi

        local my_temp=$MYSQL_CNF.temp
        my_config "$my_temp"
        my_query "status;" "$my_temp"
        my_query_rtn=$?

        if [[ $my_query_rtn -gt 0 ]]; then
            if [[ $MYSQL_ROOTPW_TYPE == "temporary" ]]; then
                log_to_file "$MBE0055"
            else
                log_to_file "$MBE0054"
            fi
            ASK_USER_FOR_PASSWORD=1
            mysql_update_config=
        else
            ASK_USER_FOR_PASSWORD=2
            mysql_update_config=$my_temp
        fi

    else
        MYSQL_ROOTPW_TYPE=saved
        log_to_file "$MBE0056 $MYSQL_CNF"

        my_query "status;"
        my_query_rtn=$?

        if [[ $my_query_rtn -gt 0 ]]; then
            log_to_file "$MBE0063"
            ASK_USER_FOR_PASSWORD=1
            mysql_update_config=
        else
            test_empty_password=$(grep -v '^$\|^#' $MYSQL_CNF | grep password | awk -F'=' '{print $2}' | sed -e "s/^\s\+//;s/\s\+$//")
            if [[ ( -z $test_empty_password ) || ( $test_empty_password == '""' ) || ( $test_empty_password == "''" ) ]]; then
                ASK_USER_FOR_PASSWORD=2
                cp -f $MYSQL_CNF $MYSQL_CNF.temp
                mysql_update_config=$MYSQL_CNF.temp
            fi
        fi
    fi

    if [[ $ASK_USER_FOR_PASSWORD -eq 1 ]]; then
        if [[ $MYSQL_ROOTPW_TYPE == "temporary" ]]; then
            log_to_file "$MBE0055"
            [[ $SILENT -eq 0 ]] && print "$MBE0055" 2
        else
            log_to_file "$MBE0054"
            [[ $SILENT -eq 0 ]] && print "$MBE0054" 2
        fi

        if [[ $SILENT -eq 0 ]]; then
            read -r -p "$MBE0057" user_answer
            [[ $(echo "$user_answer" | grep -wci "\(No\|n\)" ) -gt 0 ]] && return 1

            ask_for_password
            [[ $? -gt 0 ]] && return 2
        else
            if [[ -n "$MYPASSWORD" ]]; then
                MYSQL_ROOTPW="${MYPASSWORD}"
            else
                log_to_file "$MBE0058"
                return 1
            fi
        fi

        my_config
        print "$MBE0059" 1

    elif [[ $ASK_USER_FOR_PASSWORD -eq 2 ]]; then
        log_to_file "$MBE0063"

        if [[ $SILENT -eq 0 ]]; then
            read -r -p "$MBE0064" user_answer
            [[ $(echo "$user_answer" | grep -wci "\(No\|n\)" ) -gt 0 ]] && return 1

            ask_for_password
            [[ $? -gt 0 ]] && return 2
        else
            if [[ -n "$MYPASSWORD" ]]; then
                MYSQL_ROOTPW="${MYPASSWORD}"
            else
                MYSQL_ROOTPW="$(randpw)"
            fi
        fi

        update_mysql_rootpw

    else
        log_to_file "$MBE0065"

        if [[ -n "${MYPASSWORD}" ]]; then
            MYSQL_ROOTPW="${MYPASSWORD}"
            update_mysql_rootpw
        else
            if [[ ( $SILENT -eq 0 ) && ( $MYSQL_UNI_VERSION -ge 57 ) ]]; then
                print "$MBE0066" 1
                print "$MBE0067" 2
            fi
        fi
    fi

    my_additional_security
    log_to_file "$MBE0068"
    print "$MBE0068" 1
}

os_version(){
    RELEASE_FILE="/etc/os-release"
    IS_CENTOS=$(grep -c 'CentOS' $RELEASE_FILE)
    IS_X86_64=$(uname -p | grep -wc 'x86_64')

    if [[ $IS_CENTOS -gt 0 ]]; then
        VER=$(grep 'VERSION_ID' $RELEASE_FILE | awk -F '"' '{print $2}' | awk -F '.' '{print $1}')
    else
        print_e "Unsupported OS. This script is designed for CentOS."
    fi

    if [[ $BX_PACKAGE == "bitrix-env-crm" ]]; then
        [[ $VER -eq 7 || $VER -eq 8 || $VER -eq 9 ]] || \
            print_e "$MBE0075 $VER."
    else
        [[ $VER -eq 7 || $VER -eq 8 || $VER -eq 9 ]] || \
            print_e "$MBE0075 $VER."
    fi

    if [[ $IS_X86_64 -eq 0 ]]; then
        print_e "Unsupported architecture. This script requires x86_64 architecture."
    fi
}

bitrix_env_vars

# Check if running as root
if [[ $EUID -ne 0 ]]; then
    print_e "$MBE0069"
fi

# Check if the operating system is CentOS
if [[ ! -f /etc/os-release ]] || ! grep -qi 'centos' /etc/os-release; then
    print_e "$MBE0070"
fi

os_version

while getopts ":H:M:m:sptIFh" opt; do
    case $opt in
        "H") HOSTIDENT="${OPTARG}" ;;
        "M") MYPASSWORD="${OPTARG}" ;;
        "m") 
            MYVERSION="${OPTARG}"
            if [[ $VER == "6" && (  $MYVERSION == '8.0' || $MYVERSION == '80' ) ]]; then
                print_e "$MBE0087"
            fi
            ;;
        "s") SILENT=1 ;;
        "p") POOL=1 ;;
        "t") TEST_REPOSITORY=2 ;;
        "I") CONFIGURE_IPTABLES=1 ; CONFIGURE_FIREWALLD=0 ;;
        "F") CONFIGURE_IPTABLES=0 ; CONFIGURE_FIREWALLD=1 ;;
        "h") help_message;;
        *)  help_message;;
    esac
done

if [[ $SILENT -eq 0 ]]; then
    print "====================================================================" 2
    print "$MBE0071" 2
    print "$MBE0072" 2
    print "$MBE0073" 2
    print "$MBE0074" 2
    print "====================================================================" 2

    ASK_USER=1
else
    ASK_USER=0
fi

disable_selinux

configure_exclude

yum_update

configure_epel
configure_remi
pre_php
configure_percona
configure_nodejs
configure_bitrix

prepare_percona_install

yum_update

print "$MBE0076" 1


dnf -y install php php-mysqlnd php-pecl-apcu php-opcache >> "$LOGS_FILE" 2>&1 || \
    { print_e "$MBE0079 php-packages"; exit 1; }



# Install additional packages if BX_PACKAGE is "bitrix-env-crm"
if [[ $BX_PACKAGE == "bitrix-env-crm" ]]; then
    print "$MBE0078" 1
    dnf -y install redis >> "$LOGS_FILE" 2>&1 || \
        { print_e "$MBE0079 redis"; exit 1; }
    dnf -y install bx-push-server >> "$LOGS_FILE" 2>&1 || \
        { print_e "$MBE0079 bx-push-server"; exit 1; }
fi

# Install the main BX_PACKAGE
print "$MBE0077" 1
dnf -y install $BX_PACKAGE >> "$LOGS_FILE" 2>&1 || \
    { print_e "$MBE0079 $BX_PACKAGE"; exit 1; }

# Source bitrix_utils.sh script
. /opt/webdir/bin/bitrix_utils.sh || exit 1

configure_mysql_passwords

update_crypto_key

configure_firewall_daemon "$CONFIGURE_IPTABLES" "$CONFIGURE_FIREWALLD"
configure_firewall_daemon_rtn=$?

if [[ $configure_firewall_daemon_rtn -eq 255 ]]; then
    if [[ $BX_PACKAGE == "bitrix-env-crm" || $POOL -gt 0 ]]; then
        print "$MBE0080" 2
    else
        print_e "$MBE0080"
    fi
elif [[ $configure_firewall_daemon_rtn -gt 0 ]]; then
    if [[ $BX_PACKAGE == "bitrix-env-crm" || $POOL -gt 0 ]]; then
        print "$MBE0081 $LOGS_FILE" 2
    else
        print_e "$MBE0081 $LOGS_FILE"
    fi
fi

print "$MBE0082" 1

if [[ $BX_PACKAGE == "bitrix-env-crm" || $POOL -gt 0 ]]; then
    generate_ansible_inventory $ASK_USER "$BX_TYPE" "$HOSTIDENT" || \
        { print_e "$MBE0083 $LOGS_FILE"; exit 1; }
    print "$MBE0084" 1

    if [[ $BX_PACKAGE == "bitrix-env-crm" ]]; then
        generate_push
    fi
fi

print "$MBE0085" 1

[[ $TEST_REPOSITORY -eq 0 ]] && rm -f "$LOGS_FILE"
