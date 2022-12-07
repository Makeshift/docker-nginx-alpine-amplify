#!/bin/sh
# Note: This script is a modified version of the entrypoint from nginxinc/docker-nginx-amplify
#
# This script launches the NGINX Amplify Agent.
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
# If NO_AGENT_LOGS is set to 'true', then agent logs will be hidden (useful to hide your API key)

# Variables
agent_conf_file="/etc/amplify-agent/agent.conf"
agent_log_file="/var/log/amplify-agent/agent.log"
nginx_status_conf="/etc/nginx/conf.d/stub_status.conf"
# shellcheck disable=SC2153
api_key="${API_KEY}"
# shellcheck disable=SC2153
amplify_imagename="${AMPLIFY_IMAGENAME}"

if [ -n "${api_key}" ] || [ -n "${amplify_imagename}" ]; then
    echo "updating ${agent_conf_file} ..."

    if [ ! -f "${agent_conf_file}" ] && [ -f "${agent_conf_file}.default" ]; then
        cp -p "${agent_conf_file}.default" "${agent_conf_file}"
    elif [ ! -f "${agent_conf_file}" ] && [ ! -f "${agent_conf_file}.default" ]; then
        echo "${agent_conf_file} does not exist and there's no ${agent_conf_file}.default to use! Exiting."
        exit 1
    fi
    # lol I put so much effort into hiding this key but then the agent prints it anyway. I added an env var to hide the agent logs if needed.
    if [ -n "${api_key}" ]; then
        echo "---> Using api_key = $(echo "${api_key}" | head -c2)$(echo "${api_key}" | sed 's/./*/g' | cut -c 5-)$(echo "${api_key}" | tail -c2)"
        sed -i 's/^api_key =.*/api_key = '"${api_key}"'/' "${agent_conf_file}"
    fi
    if [ -n "${amplify_imagename}" ]; then
        echo "---> Using imagename = ${amplify_imagename}"
        sed -i 's/^amplify_imagename =.*/amplify_imagename = '"${amplify_imagename}"'/' "${agent_conf_file}"
    fi

    # If filesystem is read-only, these will just fail silently
    chmod 644 ${agent_conf_file} >/dev/null 2>&1 || true
    chmod 644 ${nginx_status_conf} >/dev/null 2>&1 || true
fi

if ! grep '^api_key.*=[ ]*[[:alnum:]].*' ${agent_conf_file} >/dev/null 2>&1; then
    echo "No api_key found in ${agent_conf_file}! exiting."
fi

echo "starting amplify-agent ..."
if [[ "$NO_AGENT_LOGS" =~ "true" ]]; then
    sed -ie 's,'"$agent_log_file"',\/dev\/null,g' $agent_conf_file
    agent_log_file="/dev/null"
fi

if ! nginx-amplify-agent.py start --config=/etc/amplify-agent/agent.conf >/proc/1/fd/1 2>&1; then
    echo "Couldn't start the agent, please check output above (if NO_AGENT_LOGS is set, you will need to unset it to see logs)"
    exit 1
else
    echo "Amplify Agent started"
fi
