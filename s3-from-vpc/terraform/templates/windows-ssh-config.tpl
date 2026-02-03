Add-Content -Path $env:USERPROFILE\.ssh\config -Value @"

Host dev-node
    HostName ${hostname}
    User ${user}
    IdentityFile ${identityfile}
"@