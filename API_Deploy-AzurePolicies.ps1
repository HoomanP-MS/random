# Import required modules for working with Azure resources
Import-Module Az.Resources

# Define the API endpoint
$listener = New-Object System.Net.HttpListener
$listener.Prefixes.Add("http://localhost:5000/")
$listener.Start()
Write-Host "API is listening on http://localhost:5000/"

# Function to deploy policies
function Invoke-PoliciesDeployment {
    param (
        [string]$tenantId,
        [string]$clientId,
        [string]$clientSecret,
        [string]$policyJson
    )

    # Authenticate to Azure
    $securePassword = ConvertTo-SecureString $clientSecret -AsPlainText -Force
    $credential = New-Object -TypeName System.Management.Automation.PSCredential -ArgumentList $clientId, $securePassword
    Connect-AzAccount -ServicePrincipal -Credential $credential -TenantId $tenantId

    # Convert JSON to PowerShell object
    $policyObject = $policyJson | ConvertFrom-Json

    # Deploy the policy
    foreach ($policy in $policyObject) {
        New-AzPolicyDefinition -Name $policy.Name -Policy $policy.Rule -DisplayName $policy.DisplayName -Description $policy.Description
    }

    Write-Host "Policies deployed successfully to tenant $tenantId"
}

# Main loop to listen for requests
while ($listener.IsListening) {
    $context = $listener.GetContext()
    $request = $context.Request
    $response = $context.Response

    if ($request.HttpMethod -eq "POST" -and $request.Url.LocalPath -eq "/deploy") {
        # Read the request body
        $reader = New-Object System.IO.StreamReader($request.InputStream, $request.ContentEncoding)
        $body = $reader.ReadToEnd()
        $reader.Close()

        # Parse the JSON body
        $requestBody = $body | ConvertFrom-Json

        # Extract parameters
        $tenantIds = $requestBody.tenantIds
        $clientId = $requestBody.clientId
        $clientSecret = $requestBody.clientSecret
        $policyJson = $requestBody.policyJson

        # Deploy policies to each tenant
        foreach ($tenantId in $tenantIds) {
            Invoke-PoliciesDeployment -tenantId $tenantId -clientId $clientId -clientSecret $clientSecret -policyJson $policyJson
        }

        # Send response
        $response.StatusCode = 200
        $response.ContentType = "application/json"
        $responseString = "{""message"":""Policies deployed successfully""}"
        $buffer = [System.Text.Encoding]::UTF8.GetBytes($responseString)
        $response.ContentLength64 = $buffer.Length
        $response.OutputStream.Write($buffer, 0, $buffer.Length)
        $response.Close()
    } else {
        $response.StatusCode = 404
        $response.Close()
    }
}

$listener.Stop()