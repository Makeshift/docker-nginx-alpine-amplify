#!/bin/sh
# Note: This script not written by Makeshift, was stolen from nginxinc/docker-nginx-amplify with minor modifications
#
# This script launches nginx and the NGINX Amplify Agent.
#
# Unless already baked in the image, a real API_KEY is required for the
# NGINX Amplify Agent to be able to connect to the backend.
#
# If AMPLIFY_IMAGENAME is set, the script will use it to generate
# the 'imagename' to put in the /etc/amplify-agent/agent.conf
#
# If several instances use the same imagename, the metrics will
# be aggregated into a single object in Amplify. Otherwise NGINX Amplify
# will create separate objects for monitoring (an object per instance).
#

# Variables
agent_conf_file="/etc/amplify-agent/agent.conf"
agent_log_file="/var/log/amplify-agent/agent.log"
nginx_status_conf="/etc/nginx/conf.d/stub_status.conf"
api_key=""
amplify_imagename=""

# Launch nginx
echo "starting nginx ..."
nginx -g "daemon off;" >/proc/1/fd/1 2>&1 &

nginx_pid=$!

test -n "${API_KEY}" &&
    api_key=${API_KEY}

test -n "${AMPLIFY_IMAGENAME}" &&
    amplify_imagename=${AMPLIFY_IMAGENAME}

if [ -n "${api_key}" -o -n "${amplify_imagename}" ]; then
    echo "updating ${agent_conf_file} ..."

    if [ ! -f "${agent_conf_file}" ]; then
        test -f "${agent_conf_file}.default" &&
            cp -p "${agent_conf_file}.default" "${agent_conf_file}" ||
            {
                echo "no ${agent_conf_file}.default found! exiting."
                exit 1
            }
    fi
    # lol I put so much effort into hiding this key but then the agent prints it anyway. I added an env var to hide the agent logs if needed.
    test -n "${api_key}" &&
        echo " ---> Using api_key = ${api_key:0:2}$(echo "${api_key}" | sed 's/./*/g' | cut -c 5-)${api_key: -2}" &&
        sh -c "sed -i.old -e 's/api_key.*$/api_key = $api_key/' \
	${agent_conf_file}"

    test -n "${amplify_imagename}" &&
        echo " ---> Using imagename = ${amplify_imagename}" &&
        sh -c "sed -i.old -e 's/imagename.*$/imagename = $amplify_imagename/' \
	${agent_conf_file}"

    test -f "${agent_conf_file}" &&
        chmod 644 ${agent_conf_file} &&
        chown nginx ${agent_conf_file} >/dev/null 2>&1

    test -f "${nginx_status_conf}" &&
        chmod 644 ${nginx_status_conf} &&
        chown nginx ${nginx_status_conf} >/dev/null 2>&1
fi

if ! grep '^api_key.*=[ ]*[[:alnum:]].*' ${agent_conf_file} >/dev/null 2>&1; then
    echo "No api_key found in ${agent_conf_file}! exiting."
fi

echo "starting amplify-agent ..."
if [[ "$NO_AGENT_LOGS" =~ "true" ]]; then
    sed -ie 's,'"$agent_log_file"',\/dev\/null,g' $agent_conf_file
    agent_log_file="/dev/null"
fi
nginx-amplify-agent.py start --config=/etc/amplify-agent/agent.conf >/proc/1/fd/1 2>&1

if [ $? != 0 ]; then
    echo "Couldn't start the agent, please check output above (if NO_AGENT_LOGS is set, you will need to unset it to see logs)"
    exit 1
else
    echo "Amplify Agent & Nginx started"
fi

wait ${nginx_pid}

echo "nginx master process has stopped, exiting."
