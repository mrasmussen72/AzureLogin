
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
        [bool] $AzureForGov = $false
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
        catch 
        {
            $success = $false
        }


        try 
        {
            if($success)
            {
                if($AzureForGov){Connect-AzAccount -Credential $cred -EnvironmentName AzureUSGovernment | Out-Null}
                else{Connect-AzAccount -Credential $cred | Out-Null}
                $DoesUserHaveAccess = Get-AzSubscription 
                if(!($DoesUserHaveAccess))
                {
                    # error logging into account or user doesn't have subscription rights, exit
                    $success = $false
                    throw "Failed to login, exiting..."
                    #exit
                }
                else{$success = $true}  
            }
        }
        catch 
        {
            #$_.Exception.Message
            $success = $false 
        } 
    }
    catch 
    {
        $_.Exception.Message | Out-Null
        $success = $false    
    }
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
[string]    $LoginName =                   ""       #Azure username, something@something.onmicrosoft.com 
[string]    $SecurePasswordLocation =      ""       #Path and filename for the secure password file c:\Whatever\securePassword.txt
[bool]      $RunPasswordPrompt =           $false   #Uses Read-Host to prompt the user at the command prompt to enter password.  this will create the text file in $SecurePasswordLocation.
[bool]      $AzureForGovernment =          $true    #set to $true if running cmdlets against Microsoft azure for government
[string]    $LogFileNameAndPath =           ""      # If $enabledLogFile is true, the script will write to a log file in this path.  Include FileName, example c:\whatever\file.log
[bool]      $EnableLogFile =               $true    # If enabled a log file will be written to $LogFileNameAndPath.

try 
{
    if($EnableLogFile){Write-Logging -Message "Starting script" -LogFileNameAndPath $LogFileNameAndPath | Out-Null}
    if($AzureForGovernment){$success = AzureLogin -RunPasswordPrompt $RunPasswordPrompt -SecurePasswordLocation $SecurePasswordLocation -LoginName $LoginName -AzureForGov $AzureForGovernment}
    else {$success = AzureLogin -RunPasswordPrompt $RunPasswordPrompt -SecurePasswordLocation $SecurePasswordLocation -LoginName $LoginName}

    if($success)
    {
        if($EnableLogFile){Write-Logging -Message "Login Succeeded" -LogFileNameAndPath $LogFileNameAndPath | Out-Null}
        #Login Successful
        Write-Host "Login Succeeded"
        #Add your Azure cmdlets here ###########################################
        #Get-AzVM


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