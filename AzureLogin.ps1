
#region variables
$stringBuilder = New-Object System.Text.StringBuilder
#endregion 

#region Functions - Add your own functions here.  Leave AzureLogin as-is
####Functions#############################################################
function AzureLogin
{
    [cmdletbinding()]
    Param
    (
        [Parameter(Mandatory=$false)]
        [bool] $RunPasswordPrompt = $false,
        [Parameter(Mandatory=$false)]
        [string] $SecurePasswordLocation,
        [Parameter(Mandatory=$false)]
        [string] $LoginName,
        [Parameter(Mandatory=$false)]
        [bool] $AzureForGov = $false,
        [Parameter(Mandatory=$false)]
        [bool] $ConnectToAzureAd = $false
    )

    try 
    {
        $success = $false
        
        if(!($SecurePasswordLocation -match '(\w)[.](\w)') )
        {
            write-host "Encrypted password file ends in a directory, this needs to end in a filename.  Exiting..."
            return false # could make success false
        }
        if($RunPasswordPrompt)
        {
            #if fails return false
            Read-Host -Prompt "Enter your password for $($LoginName)" -assecurestring | convertfrom-securestring | out-file $SecurePasswordLocation
        }
        else 
        {
            #no prompt, does the password file exist
            if(!(Test-Path $SecurePasswordLocation))
            {
                write-host "There isn't a password file in the location you specified $($SecurePasswordLocation)."
                Read-host "Password file not found, Enter your password" -assecurestring | convertfrom-securestring | out-file $SecurePasswordLocation
                #return false if fail 
                if(!(Test-Path -Path $SecurePasswordLocation)){return Write-Host "Path doesn't exist: $($SecurePasswordLocation)"; $false}
            } 
        }
        try 
        {
            $password = Get-Content $SecurePasswordLocation | ConvertTo-SecureString
            $cred = new-object -typename System.Management.Automation.PSCredential -argumentlist $LoginName, $password 
            $success = $true
        }
        catch {$success = $false}
        try 
        {
            if($success)
            {
                #connect AD or Az
                if($ConnectToAzureAd)
                {
                    if($AzureForGov){Connect-AzureAD -Credential $cred -EnvironmentName AzureUSGovernment | Out-Null}
                    else{Connect-AzureAD -Credential $cred | Out-Null}
                    $context = Get-AzureADUser -Top 1
                    if($context){$success = $true}   
                    else{$success = $false}
                }
                else 
                {
                    if($AzureForGov){Connect-AzAccount -Credential $cred -EnvironmentName AzureUSGovernment | Out-Null}
                    else{Connect-AzAccount -Credential $cred | Out-Null}
                    $context = Get-AzContext
                    if($context.Subscription.Name){$success = $true}
                    else{$success = $false}
                }
                if(!($success))
                {
                  # error logging into account or user doesn't have subscription rights, exit
                  $success = $false
                  throw "Failed to login, exiting..."
                  #exit
                }   
            }
        }
        catch{$success = $false} 
    }
    catch {$success = $false}
    return $success
}

function Write-Logging()
{
    param
    (
        [string] $Message,
        [string] $LogFileNameAndPath
    )
    
    try 
    {
        $success = $false
        $dateTime = Get-Date -Format yyyyMMddTHHmmss
        $null = $stringBuilder.Append($dateTime.ToString())
        $null = $stringBuilder.Append( "`t==>>`t")
        $null = $stringBuilder.AppendLine( $Message)
        $stringBuilder.ToString() | Out-File -FilePath $LogFileNameAndPath -Append
        $stringBuilder.Clear()
        $success = $true 
    }
    catch {$success = $false}
    return $success
}
#endregion



####Begin Code - enter your code in the if statement below
#Variables - Add your values for the variables here, you can't leave the values blank
[string]    $LoginName =                   ""           # Azure username, something@something.onmicrosoft.com 
[string]    $SecurePasswordLocation =      ""           # Path and filename for the secure password file c:\Whatever\securePassword.txt
[string]    $LogFileNameAndPath =          ""           # If $enabledLogFile is true, the script will write to a log file in this path.  Include FileName, example c:\whatever\file.log
[bool]      $RunPasswordPrompt =           $true        # Uses Read-Host to prompt the user at the command prompt to enter password.  this will create the text file in $SecurePasswordLocation.
[bool]      $AzureForGovernment =          $false        # Set to $true if running cmdlets against Microsoft azure for government
[bool]      $EnableLogFile =               $false        # If enabled a log file will be written to $LogFileNameAndPath.
[bool]      $ConnectToAzureAd =            $false       # This will connect to Azure-AD and allow you to run commands against Azure Active Directoryusing Connect-AzureRM cmdlets instead of Connect-AzAccount

try 
{
    if($EnableLogFile){Write-Logging -Message "Starting script" -LogFileNameAndPath $LogFileNameAndPath | Out-Null}
    $success = AzureLogin -RunPasswordPrompt $RunPasswordPrompt -SecurePasswordLocation $SecurePasswordLocation -LoginName $LoginName -AzureForGov $AzureForGovernment -ConnectToAzureAd $ConnectToAzureAd
    if($success)
    {
        if($EnableLogFile){Write-Logging -Message "Login Succeeded" -LogFileNameAndPath $LogFileNameAndPath | Out-Null}
        #Login Successful
        Write-Host "Login Succeeded"
 
        if(!($ConnectToAzureAd))
        {
            #Run commands using the Azure Az cmdlets ###########################
        }
        else 
        {
            #Run commands using the AzureAd cmdlets ####################################

        }
    }
    else 
    {
        #Login Failed 
        Write-Host "Login Failed or No Access"
        if($EnableLogFile){Write-Logging -Message "Login Failed or No Access" -LogFileNameAndPath $LogFileNameAndPath | Out-Null}
    }
}
catch 
{
    #Login Failed with Error
    if($EnableLogFile){Write-Logging -Message "Login Failed $_.Exception.Message" -LogFileNameAndPath $LogFileNameAndPath | Out-Null}
    #$_.Exception.Message
}
Write-Logging -Message "Ending Script" -LogFileNameAndPath $LogFileNameAndPath | Out-Null