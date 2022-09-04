#!/bin/sh

# This script copied from https://github.com/Makeshift/nginx-amplify-agent-v1.7.0-5/blob/master/packages/install-source.sh
#   just in case a vengeful God decides to do to that copy of the repo the same as they did to the original.
# Yes, I could have rewritten it to not need an expect script, but I'm lazy.

pip_url="https://bootstrap.pypa.io/get-pip.py"
agent_url="https://github.com/nginxinc/nginx-amplify-agent"
agent_conf_path="/etc/amplify-agent"
agent_conf_file="${agent_conf_path}/agent.conf"
nginx_conf_file="/etc/nginx/nginx.conf"

set -e

install_warn1 () {
    echo "The script will install git, python, python-dev, wget and possibly some other"
    echo "additional packages unless already found on this system."
    echo ""
    printf "Continue (y/n)? "
    read line
    test "${line}" = "y" -o "${line}" = "Y" || \
        exit 1
    echo ""
}

check_packages () {
    printf 'Checking if python 2.6 or 2.7 exists ... '
    for version in '2.7' '2.6'
    do
        # checks for python2.7, python2, python, etc
        major=`echo $version | sed 's/\(.\).*/\1/'`
        for py_command in "python${version}" "python${major}" 'python'
        do
            # checks if it's a valid command
            if ! command -V "${py_command}" >/dev/null 2>&1; then
                py_command=''
            # checks what python version it runs
            elif [ "$(${py_command} -c 'import sys; print(".".join(map(str, sys.version_info[:2])))' 2>&1)" != "${version}" ]; then
                py_command=''
            else
                break 2
            fi
        done
    done

    if [ -n "${py_command}" ]; then
        found_python='yes'
        echo 'yes'
    else
        found_python='no'
        echo 'no'
    fi

    for i in git wget curl gcc
    do
        printf "Checking if ${i} exists ... "
        if command -V ${i} >/dev/null 2>&1; then
            eval "found_${i}='yes'"
            echo 'yes'
        else
            eval "found_${i}='no'"
            echo 'no'
        fi
    done

    printf 'Checking if python-dev exists ... '
    if [ "${found_python}" = 'no' ]; then
        found_python_dev='no'
        echo 'no'
    elif [ ! -e "$(${py_command} -c 'from distutils import sysconfig as s; print(s.get_config_vars()["INCLUDEPY"])' 2>&1)" ]; then
        found_python_dev='no'
        echo 'no'
    else
        found_python_dev='yes'
        echo 'yes'
    fi

    echo
}

# Detect the user for the agent to use
detect_amplify_user() {
    if [ -f "${agent_conf_file}" ]; then
        amplify_user=`grep -v '#' ${agent_conf_file} | \
                      grep -A 5 -i '\[.*nginx.*\]' | \
                      grep -i 'user.*=' | \
                      awk -F= '{print $2}' | \
                      sed 's/ //g' | \
                      head -1`

        nginx_conf_file=`grep -A 5 -i '\[.*nginx.*\]' ${agent_conf_file} | \
                         grep -i 'configfile.*=' | \
                         awk -F= '{print $2}' | \
                         sed 's/ //g' | \
                         head -1`
    fi

    if [ -f "${nginx_conf_file}" ]; then
        nginx_user=`grep 'user[[:space:]]' ${nginx_conf_file} | \
                    grep -v '[#].*user.*;' | \
                    grep -v '_user' | \
                    sed -n -e 's/.*\(user[[:space:]][[:space:]]*[^;]*\);.*/\1/p' | \
                    awk '{ print $2 }' | head -1`
    fi

    if [ -z "${amplify_user}" ]; then
        test -n "${nginx_user}" && \
        amplify_user=${nginx_user} || \
        amplify_user="nginx"
    fi
}

printf "\n --- This script will install the NGINX Amplify Agent from source ---\n\n"

# Detect root
if [ "`id -u`" = "0" ]; then
    sudo_cmd=""
else
    if command -V sudo >/dev/null 2>&1; then
        sudo_cmd="sudo "
        echo "HEADS UP - will use sudo, you need to be in sudoers(5)"
        echo ""
    else
        echo "Started as non-root, sudo not found, exiting."
        exit 1
    fi
fi

if [ -n "$API_KEY" ]; then
    api_key=$API_KEY
else
    echo " What's your API key? Please check the docs and the UI."
    echo ""
    printf " Enter your API key: "
    read api_key
    echo ""
fi

if uname -m | grep "_64" >/dev/null 2>&1; then
    arch64="yes"
else
    arch64="no"
fi

printf " Please select your OS: \n\n"
echo " 1. FreeBSD 10, 11"
echo " 2. SLES 12"
echo " 3. Alpine 3.7"
echo " 4. Fedora 24, 26"
echo " 5. Other"
echo ""
printf " ==> "

read line
line=`echo $line | sed 's/^\(.\).*/\1/'`

echo ""

case $line in
    # FreeBSD 10
    1)
        os="freebsd"

        install_warn1
        check_packages

        test "${found_python}" = "no" && ${sudo_cmd} pkg install python
        test "${found_git}" = "no" && ${sudo_cmd} pkg install git
        test "${found_wget}" = "no" -a "${found_curl}" = "no" &&  ${sudo_cmd} dnf -y install wget
        ;;
    # SLES 12
    2)
        os="sles12"

        install_warn1
        check_packages

        test "${found_python}" = "no" && ${sudo_cmd} zypper install python
        test "${found_python_dev}" = "no" && ${sudo_cmd} zypper install python-dev
        test "${found_git}" = "no" && ${sudo_cmd} zypper install git
        test "${found_wget}" = "no" -a "${found_curl}" = "no" &&  ${sudo_cmd} dnf -y install wget
        ;;
    # Alpine 3.7
    3)
        os="alpine37"

        install_warn1
        check_packages

        test "${found_python}" = "no" && ${sudo_cmd} apk add --no-cache python && py_command="python"
        test "${found_python_dev}" = "no" && ${sudo_cmd} apk add --no-cache python-dev
        test "${found_git}" = "no" && ${sudo_cmd} apk add --no-cache git
        ${sudo_cmd} apk add --no-cache util-linux procps
        test "${found_wget}" = "no" -a "${found_curl}" = "no" &&  ${sudo_cmd} dnf -y install wget
        test "${found_gcc}" = "no" && ${sudo_cmd} apk add --no-cache gcc musl-dev linux-headers
        ;;
    # Fedora 24
    4)
        os="fedora"

        install_warn1
        check_packages

        test "${found_python}" = "no" && ${sudo_cmd} dnf -y install python && py_command="python2.7"
        test "${found_python_dev}" = "no" && ${sudo_cmd} dnf -y install python-devel
        test "${found_git}" = "no" && ${sudo_cmd} dnf -y install git
        test "${found_wget}" = "no" -a "${found_curl}" = "no" &&  ${sudo_cmd} dnf -y install wget
        test "${found_gcc}" = "no" && ${sudo_cmd} dnf -y install gcc redhat-rpm-config procps
        ;;
    5)
        echo "Before continuing with this installation script, please make sure that"
        echo "the following extra packages are installed on your system: git, python 2.6 or 2.7,"
        echo "python-dev, wget and gcc. Please install them manually if needed."
        echo ""
        printf "Continue (y/n)? "
        read line
        echo ""
        test "${line}" = "y" -o "${line}" = "Y" || \
            exit 1

        check_packages
        ;;
    *)
        echo "Unrecognized option, exiting."
        echo ""
        exit 1
esac

if command -V curl >/dev/null 2>&1; then
    downloader="curl -fs -O"
else
    if command -V wget >/dev/null 2>&1; then
        downloader="wget -q --no-check-certificate"
    else
        echo "no curl or wget found, exiting."
        exit 1
    fi
fi

# Set up Python stuff
rm -f get-pip.py
${downloader} ${pip_url}
${py_command} get-pip.py --ignore-installed --user
~/.local/bin/pip install setuptools --upgrade --user

# Clone the Amplify Agent repo
${sudo_cmd} rm -rf nginx-amplify-agent
git clone ${agent_url}

# Install the Amplify Agent
cd nginx-amplify-agent

if [ "${os}" = "fedora" -a "${arch64}" = "yes" ]; then
    echo '[install]' > setup.cfg
    echo 'install-purelib=$base/lib64/python' >> setup.cfg
fi

if [ "${os}" = "freebsd" ]; then
    rel=`uname -r | sed 's/^\(.[^.]*\)\..*/\1/'`
    test "${rel}" = "11" && \
	opt='-std=c99'

    grep -v gevent packages/nginx-amplify-agent/requirements.txt > packages/nginx-amplify-agent/req-nogevent.txt
    grep gevent packages/nginx-amplify-agent/requirements.txt > packages/nginx-amplify-agent/req-gevent.txt

    ~/.local/bin/pip install --upgrade --target=amplify --no-compile -r packages/nginx-amplify-agent/req-nogevent.txt
    CFLAGS=${opt} ~/.local/bin/pip install --upgrade --target=amplify --no-compile -r packages/nginx-amplify-agent/req-gevent.txt
else
    ~/.local/bin/pip install --upgrade --target=amplify --no-compile -r packages/nginx-amplify-agent/requirements.txt
fi

if [ "${os}" = "fedora" -a "${arch64}" = "yes" ]; then
    rm setup.cfg
    export PYTHONPATH=/usr/lib64/python/
fi

${sudo_cmd} cp packages/nginx-amplify-agent/setup.py .
${sudo_cmd} ${py_command} setup.py install
${sudo_cmd} cp nginx-amplify-agent.py /usr/bin
${sudo_cmd} chown root /usr/bin/nginx-amplify-agent.py

# Generate new config file for the agent
${sudo_cmd} rm -f ${agent_conf_file}
${sudo_cmd} sh -c "sed -e 's/api_key.*$/api_key = $api_key/' ${agent_conf_file}.default > ${agent_conf_file}"
${sudo_cmd} chmod 644 ${agent_conf_file}

detect_amplify_user

if ! grep ${amplify_user} /etc/passwd >/dev/null 2>&1; then
    if [ "${os}" = "freebsd" ]; then
        ${sudo_cmd} pw user add ${amplify_user}
    elif [ "${os}" = "alpine37" ]; then
        ${sudo_cmd} adduser -D -S -h /var/cache/nginx -s /sbin/nologin ${amplify_user}
    else
        ${sudo_cmd} useradd ${amplify_user}
    fi
fi

${sudo_cmd} chown ${amplify_user} ${agent_conf_path} >/dev/null 2>&1
${sudo_cmd} chown ${amplify_user} ${agent_conf_file} >/dev/null 2>&1

# Create directories for the agent in /var/log and /var/run
${sudo_cmd} mkdir -p /var/log/amplify-agent
${sudo_cmd} chmod 755 /var/log/amplify-agent
${sudo_cmd} chown ${amplify_user} /var/log/amplify-agent

${sudo_cmd} mkdir -p /var/run/amplify-agent
${sudo_cmd} chmod 755 /var/run/amplify-agent
${sudo_cmd} chown ${amplify_user} /var/run/amplify-agent

echo ""
echo " --- Finished successfully! --- "
echo ""
echo " To start the Amplify Agent use:"
echo ""
echo " # sudo -u ${amplify_user} ${py_command} /usr/bin/nginx-amplify-agent.py start \ "
echo "                   --config=/etc/amplify-agent/agent.conf \ "
echo "                   --pid=/var/run/amplify-agent/amplify-agent.pid"
echo ""
echo " To stop the Amplify Agent use:"
echo ""
echo " # sudo -u ${amplify_user} ${py_command} /usr/bin/nginx-amplify-agent.py stop \ "
echo "                   --config=/etc/amplify-agent/agent.conf \ "
echo "                   --pid=/var/run/amplify-agent/amplify-agent.pid"
echo ""

exit 0
