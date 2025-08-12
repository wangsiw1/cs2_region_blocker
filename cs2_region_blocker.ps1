param (
    # [Parameter(Mandatory=$true)]
    [ValidateSet("add", "remove")]
    [string]$Action
)


$CS2_SERVER_API = "https://api.steampowered.com/ISteamApps/GetSDRConfig/v1?appid=730"
$REGION_LIST = @("hkg", "hkg4")
$RULE_NAME = '^CS2_BLOCK_.*$'


function Show-Help {
    Write-Host "Usage: .\cs2_region_blocker.ps1 -Action <add|remove>"
    Write-Host "Example: .\cs2_region_blocker.ps1 -Action add"
}


function Remove-FirewallRules {
    # Get all existing rules
    $rules = netsh advfirewall firewall show rule name=all
    $matchingRules = New-Object System.Collections.ArrayList

    # Find all rules matching the naming pattern, add to a list
    foreach ($line in $rules) {
        if ($line -match '^Rule Name:\s+(.*)$') {
            $ruleName = $matches[1].Trim()
            if ($ruleName -match $RULE_NAME) {
                $matchingRules.Add($ruleName)
            }
        }
    }

    # For rules in the list, remove them
    foreach ($rule in $matchingRules) {
        Write-Host "Deleting rule: $rule"
        netsh advfirewall firewall delete rule name="$rule"
    }
}


function Add-FirewallRules {
    # Get relay server list from Steam API
    $response = Invoke-WebRequest -Uri $CS2_SERVER_API
    $data = $response.Content | ConvertFrom-Json

    $ip_list = New-Object System.Collections.ArrayList

    # Add ips of relay server in defined region to a list
    foreach ($region in $REGION_LIST) {
        foreach ($relay in $data.pops."$region".relays) {
            $ip_list.Add($relay.ipv4)
        }
    }

    # For each ip, add block rules for TCP/UDP on both inbound and outbound
    foreach ($ip in $ip_list) {
        Write-Host "Adding rules for ip: $ip"
        # Block outbound
        netsh advfirewall firewall add rule name="CS2_BLOCK_OUT_UDP_$ip" dir=out action=block protocol=UDP remoteip=$ip
        netsh advfirewall firewall add rule name="CS2_BLOCK_OUT_TCP_$ip" dir=out action=block protocol=TCP remoteip=$ip
        # Block inbound
        netsh advfirewall firewall add rule name="CS2_BLOCK_IN_UDP_$ip" dir=in action=block protocol=UDP remoteip=$ip
        netsh advfirewall firewall add rule name="CS2_BLOCK_IN_TCP_$ip" dir=in action=block protocol=TCP remoteip=$ip
    }
}


if (-not $Action) {
    Show-Help
    exit
}

switch ($Action) {
    'add'    { Add-FirewallRules }
    'remove' { Remove-FirewallRules }
}
