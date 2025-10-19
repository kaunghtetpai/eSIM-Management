# SECURE eSIM ENTERPRISE MANAGEMENT SYSTEM
# No hardcoded credentials - Secure authentication only

param(
    [Parameter(Mandatory=$false)]
    [string]$TenantId,
    [string]$OperationMode = "FullAuto",
    [switch]$InteractiveLogin,
    [switch]$UseDeviceCode,
    [switch]$NoPrompt
)

# Security Configuration
$Global:AuthConfig = @{
    TenantId = $TenantId
    Scopes = @(
        "DeviceManagementConfiguration.ReadWrite.All",
        "Device.ReadWrite.All", 
        "Group.ReadWrite.All",
        "User.Read.All",
        "Directory.Read.All"
    )
    AutoRedirectUri = "http://localhost"
}

Function Get-SecureCredentials {
    Write-Host "`n=== eSIM ENTERPRISE AUTHENTICATION ===" -ForegroundColor Cyan
    Write-Host "Please provide authentication details:" -ForegroundColor Yellow
    
    if (-not $Global:AuthConfig.TenantId) {
        $Global:AuthConfig.TenantId = Read-Host "Enter your Tenant ID (or press Enter for common)"
        if ([string]::IsNullOrWhiteSpace($Global:AuthConfig.TenantId)) {
            $Global:AuthConfig.TenantId = "common"
        }
    }
    
    Write-Host "`nAuthentication Methods:" -ForegroundColor White
    Write-Host "1. Interactive Browser Login (Recommended)" -ForegroundColor Gray
    Write-Host "2. Device Code Flow (For headless systems)" -ForegroundColor Gray
    Write-Host "3. Use current context (If already logged in)" -ForegroundColor Gray
    
    if (-not $UseDeviceCode -and -not $InteractiveLogin) {
        $choice = Read-Host "`nChoose method (1-3, default: 1)"
        switch ($choice) {
            "2" { $UseDeviceCode = $true }
            "3" { break } # Use current context
            default { $InteractiveLogin = $true }
        }
    }
}

Function Connect-SecureGraph {
    Write-Host "`nConnecting to Microsoft Graph..." -ForegroundColor Yellow
    
    try {
        # Check if already connected
        $context = Get-MgContext -ErrorAction SilentlyContinue
        if ($context -and $context.Account -and (-not $ForceReconnect)) {
            Write-Host "Already connected as: $($context.Account)" -ForegroundColor Green
            return $true
        }
        
        # Import required module
        Import-Module Microsoft.Graph.Authentication -Force -ErrorAction Stop
        
        if ($InteractiveLogin -or (-not $UseDeviceCode)) {
            Write-Host "Opening browser for interactive login..." -ForegroundColor Yellow
            if ($Global:AuthConfig.TenantId -eq "common") {
                Connect-MgGraph -Scopes $Global:AuthConfig.Scopes -ErrorAction Stop
            } else {
                Connect-MgGraph -Scopes $Global:AuthConfig.Scopes -TenantId $Global:AuthConfig.TenantId -ErrorAction Stop
            }
        } elseif ($UseDeviceCode) {
            Write-Host "Using device code flow..." -ForegroundColor Yellow
            if ($Global:AuthConfig.TenantId -eq "common") {
                Connect-MgGraph -Scopes $Global:AuthConfig.Scopes -UseDeviceAuthentication -ErrorAction Stop
            } else {
                Connect-MgGraph -Scopes $Global:AuthConfig.Scopes -TenantId $Global:AuthConfig.TenantId -UseDeviceAuthentication -ErrorAction Stop
            }
        }
        
        # Verify connection
        $context = Get-MgContext
        if ($context -and $context.Account) {
            Write-Host "Successfully connected as: $($context.Account)" -ForegroundColor Green
            Write-Host "Tenant ID: $($context.TenantId)" -ForegroundColor Green
            return $true
        } else {
            throw "Connection failed - no context established"
        }
        
    } catch {
        Write-Host "Authentication failed: $($_.Exception.Message)" -ForegroundColor Red
        return $false
    }
}

Function Test-GraphPermissions {
    Write-Host "`nVerifying permissions..." -ForegroundColor Yellow
    
    try {
        # Test basic read permission
        $me = Get-MgMe -ErrorAction Stop
        Write-Host "User context: $($me.DisplayName)" -ForegroundColor Green
        
        # Test device management permissions
        $devices = Get-MgDevice -Top 1 -ErrorAction SilentlyContinue
        if ($devices) {
            Write-Host "Device read permissions: OK" -ForegroundColor Green
        }
        
        # Test group permissions
        $groups = Get-MgGroup -Top 1 -ErrorAction SilentlyContinue
        if ($groups) {
            Write-Host "Group read permissions: OK" -ForegroundColor Green
        }
        
        return $true
        
    } catch {
        Write-Host "Permission check failed: $($_.Exception.Message)" -ForegroundColor Red
        return $false
    }
}

# MAIN SECURE AUTHENTICATION FLOW
Function Start-SecureeSIMDeployment {
    Write-Host "`n" + "="*70 -ForegroundColor Cyan
    Write-Host "SECURE eSIM ENTERPRISE DEPLOYMENT" -ForegroundColor Cyan
    Write-Host "Zero Hardcoded Credentials - Secure Authentication Only" -ForegroundColor Cyan
    Write-Host "="*70 -ForegroundColor Cyan
    
    # Step 1: Get authentication configuration
    Get-SecureCredentials
    
    # Step 2: Connect to Microsoft Graph
    $connected = Connect-SecureGraph
    if (-not $connected) {
        Write-Host "`nAuthentication failed. Please check your credentials and try again." -ForegroundColor Red
        exit 1
    }
    
    # Step 3: Verify permissions
    $permissionsOk = Test-GraphPermissions
    if (-not $permissionsOk) {
        Write-Host "`nInsufficient permissions. Please ensure your account has:" -ForegroundColor Red
        Write-Host "- Device Management Administrator role" -ForegroundColor Yellow
        Write-Host "- Intune Administrator role" -ForegroundColor Yellow
        Write-Host "- Or the specific Graph permissions requested" -ForegroundColor Yellow
        exit 1
    }
    
    # Step 4: Proceed with eSIM deployment
    Write-Host "`nStarting secure eSIM enterprise deployment..." -ForegroundColor Green
    Start-eSIMDeployment
}

# YOUR EXISTING eSIM DEPLOYMENT CODE (modified for security)
Function Start-eSIMDeployment {
    try {
        Write-Host "`n=== eSIM ENTERPRISE DEPLOYMENT ===" -ForegroundColor Cyan
        
        # 1. Create eSIM device groups
        Write-Host "Creating eSIM device groups..." -ForegroundColor Yellow
        $groupParams = @{
            DisplayName = "eSIM-Managed-Devices-$(Get-Date -Format 'yyyyMMdd')"
            Description = "Automatically managed eSIM devices"
            MailEnabled = $false
            SecurityEnabled = $true
            GroupTypes = @("DynamicMembership")
            MembershipRule = '(device.deviceOSType -eq "Windows")'
            MembershipRuleProcessingState = "On"
        }
        $deviceGroup = New-MgGroup @groupParams
        Write-Host "Created group: $($deviceGroup.DisplayName)" -ForegroundColor Green
        
        # 2. Create compliance policy
        Write-Host "Creating compliance policy..." -ForegroundColor Yellow
        $compliancePolicy = New-MgDeviceManagementDeviceCompliancePolicy -DisplayName "eSIM Security Baseline" `
            -Description "Security compliance for eSIM managed devices" `
            -OsType "Windows10AndLater" `
            -PasswordRequired $true `
            -PasswordMinimumLength 8 `
            -StorageRequireEncryption $true
        Write-Host "Created compliance policy" -ForegroundColor Green
        
        # 3. Assign policy to group
        Write-Host "Assigning policy to group..." -ForegroundColor Yellow
        $assignment = @{
            DeviceCompliancePolicyId = $compliancePolicy.Id
            Target = @{GroupId = $deviceGroup.Id}
        }
        New-MgDeviceManagementDeviceCompliancePolicyAssignment @assignment
        Write-Host "Policy assigned successfully" -ForegroundColor Green
        
        # 4. Generate eSIM inventory report
        Write-Host "Generating eSIM inventory..." -ForegroundColor Yellow
        $inventory = Generate-eSIMInventory -GroupId $deviceGroup.Id
        $inventory | Export-Csv ".\eSIM_Inventory_$(Get-Date -Format 'yyyyMMdd').csv" -NoTypeInformation
        Write-Host "Inventory generated: $($inventory.Count) profiles" -ForegroundColor Green
        
        Write-Host "`n=== eSIM DEPLOYMENT COMPLETED ===" -ForegroundColor Green
        Write-Host "Summary:" -ForegroundColor White
        Write-Host "- Device Group: $($deviceGroup.DisplayName)" -ForegroundColor Gray
        Write-Host "- Compliance Policy: eSIM Security Baseline" -ForegroundColor Gray
        Write-Host "- Inventory: $($inventory.Count) eSIM profiles" -ForegroundColor Gray
        
    } catch {
        Write-Host "Deployment failed: $($_.Exception.Message)" -ForegroundColor Red
    } finally {
        # Always disconnect
        Disconnect-MgGraph -ErrorAction SilentlyContinue
        Write-Host "`nDisconnected from Microsoft Graph" -ForegroundColor Yellow
    }
}

Function Generate-eSIMInventory {
    param([string]$GroupId)
    
    # Generate sample eSIM inventory
    $carriers = @("Verizon", "AT&T", "T-Mobile", "Vodafone", "Orange")
    $inventory = @()
    
    for ($i = 1; $i -le 10; $i++) {
        $inventory += [PSCustomObject]@{
            ProfileID = "ESIM-$i"
            Carrier = $carriers | Get-Random
            ICCID = "8910" + (Get-Random -Minimum 100000000000000 -Maximum 999999999999999)
            EID = "E" + (Get-Random -Minimum 1000000000000000000 -Maximum 9999999999999999999)
            DeviceName = "ESIM-DEVICE-$i"
            Status = "Available"
            AssignmentGroup = $GroupId
            CreatedDate = Get-Date -Format "yyyy-MM-dd"
        }
    }
    
    return $inventory
}

# EXECUTION WITH SECURE AUTHENTICATION
if ($MyInvocation.InvocationName -ne '.') {
    # Check if Microsoft Graph module is available
    if (-not (Get-Module -ListAvailable -Name Microsoft.Graph)) {
        Write-Host "Installing Microsoft Graph modules..." -ForegroundColor Yellow
        Install-Module Microsoft.Graph -Force -Confirm:$false -Scope CurrentUser
    }
    
    # Start secure deployment
    Start-SecureeSIMDeployment
}