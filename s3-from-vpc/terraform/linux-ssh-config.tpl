cat << EOF > ~/.ssh/config

Host dev-node
    HostName ${hostname}
    User ${user}
    IdentityFile ${identityfile}
EOF