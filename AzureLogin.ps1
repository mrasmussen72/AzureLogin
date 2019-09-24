
#region variables
$stringBuilder = New-Object System.Text.StringBuilder                   # Logging
$global:passwordLocation = ""                                           # Used for cleanup

#Variables - Change values below
[string]    $LoginName =                                ""              # Azure username, something@something.onmicrosoft.com 
[bool]      $AzureForGovernment =                       $true           # Set to $true if running cmdlets against Microsoft Azure for Government
[bool]      $ConnectToAzureAz =                         $true           # Set to $true to run Az cmdlets 
[bool]      $ConnectToAzureAd =                         $false          # Set to $true to run Azure-AD cmdlets.
[bool]      $ResetPassword =                            $true           # Prompts for your password, overwriting the current file
[bool]      $CleanUp =                                  $true           # Deletes the Secure String file that allows for successful logins without entering password.  Uses a secure string written to a file

# Writing to Azure variables.  Leave default if not writting to Azure.
[string]    $StorageAccountName =                       ""              # Storage account name to write to
[string]    $ResourceGroupName =                        ""              # Resource group name of the storage account
[string]    $Container =                                ""              # Container to write to
[bool]      $WriteToAzure =                             $false           # Set to $true to write to Azure.  If $true, you need to have the other writing to Azure variable set

#endregion 

#region Functions - Add your own functions here.  Leave AzureLogin as-is
####Functions#############################################################
function AzureAuthentication
{
    [cmdletbinding()]
    Param
    (
        [Parameter(Mandatory=$false)]
        [string] $LoginName,
        [Parameter(Mandatory=$false)]
        [bool] $AzureForGov = $false,
        [Parameter(Mandatory=$false)]
        [bool] $ConnectToAzureAz = $false,
        [Parameter(Mandatory=$false)]
        [bool] $ConnectToAzureAd = $false
    )

    try 
    {
        $success = $false

        if($LoginName.Length -le 0){throw "You must provide a login name"}
        $SecurePasswordLocation = (($env:TEMP) + "\" + $LoginName + ".txt")
        #password file
        if($ResetPassword)
        {
            try {
                $global:passwordLocation = $SecurePasswordLocation
                Read-Host -Prompt "Enter your password for $($LoginName)" -assecurestring | convertfrom-securestring | out-file $SecurePasswordLocation
            }
            catch {
                #log error
                throw ("Failed to remote SecurePasswordLocation" + $_.Exception.Message.ToString())
            }
        }
        else 
        {
            if((!(Test-Path -Path $SecurePasswordLocation)))
            {
                Read-Host -Prompt "Enter your password for $($LoginName)" -assecurestring | convertfrom-securestring | out-file $SecurePasswordLocation
                $global:passwordLocation = $SecurePasswordLocation
            }   
        }

        #Credential object
        try 
        {
            #Change this so we don't create a file.
            $password = Get-Content $SecurePasswordLocation | ConvertTo-SecureString
            $cred = new-object -typename System.Management.Automation.PSCredential -argumentlist $LoginName, $password 
            $success = $true
        }
        catch {$success = $false}

        #Run the command
        if($success)
        {
            #Connect AD
            if($ConnectToAzureAd)
            {
                if($AzureForGov){Connect-AzureAD -Credential $cred -EnvironmentName AzureUSGovernment | Out-Null}
                else{Connect-AzureAD -Credential $cred | Out-Null}
                $context = Get-AzureADUser -Top 1
                if($context){$success = $true}   
                else{$success = $false}
            }
            #Connect Az
            if($ConnectToAzureAz) 
            {
                
                try {
                    if($AzureForGov){Connect-AzAccount -Credential $cred -EnvironmentName AzureUSGovernment | Out-Null}
                    else{Connect-AzAccount -Credential $cred} # | Out-Null}
                    $context = Get-AzContext
                    if($context.Account.Id -eq $cred.UserName){$success = $true}
                    else{$success = $false}
               }
                catch {$success = $false}
            }
            if(!($success))
            {
                # error logging into account or user doesn't have subscription rights, exit
                $success = $false
                throw "$($cred.UserName) Failed to login, exiting..."
                #exit
            }   
        }
    }
    catch {throw}
    return $success
}

function WriteLoggingToAzure()
{
    param(
    [string] $StorageAccountName,
    [string] $ResourceGroupName,
    [string] $BlobName,
    [string] $FileName,
    [string] $Container,
    $Context
    )

    $success = $false
    try {
        $storageAccountKey = (Get-AzStorageAccountKey -Name $StorageAccountName -ResourceGroupName $ResourceGroupName).Value[0]
        $storageContext = New-AzStorageContext -StorageAccountName $StorageAccountName -StorageAccountKey $storageAccountKey
        #write blob to Azure - option to append blobs?
        $results = (Set-AzStorageBlobContent -Container $Container -Context $storageContext -File $FileName -BlobType "Block" -Verbose -Force ).Name 
    }
    catch {$success = $false}
    if($results){$success = $true}
    return $success
}

function Write-Logging()
{
    param
    (
        [string]    $Message,
        [bool]      $WriteToAzure,
        [bool]      $WriteLocally,
        [bool]      $EndOfMessage,
        [string]    $Container,
        [string]    $BlobType = "Block",
        [string]    $StorageAccountName,
        [string]    $ResourceGroupName,
        [string]    $AzureLoginName,
        $StorageContext
    )
    
    try 
    {
        $success = $false
        $dateTime = Get-Date -Format yyyyMMddTHHmmss
        if($AzureLoginName.Length -le 0){$AzureLoginName='NoUserName'}
        $blobName = ($AzureLoginName + "-" + $dateTime + ".log")

        #Create string
        $stringBuilder.Append($dateTime.ToString()) | Out-Null
        $stringBuilder.Append( "`t==>>`t") | Out-Null
        $stringBuilder.AppendLine( $Message) | Out-Null

        if($EndOfMessage)
        {
            #Write data
            $LocalLogFileNameAndPath = (($env:TEMP) + "\" + $blobName)
            $stringBuilder.ToString() | Out-File -FilePath $LocalLogFileNameAndPath -Append -Force
            $success = $true
            
            if($WriteToAzure)
            {
                $tempFile = (($env:TEMP) + "\" + $blobName)                     # directory, no / at the end
                #$stringBuilderAzure.ToString() | Out-File $tempFile -Force     # Write the azure data locally?
                $success = WriteLoggingToAzure -StorageAccountName $StorageAccountName -ResourceGroupName $ResourceGroupName -BlobName $BlobName -Context $StorageContext -FileName $tempFile -Container $Container
            }
            $stringBuilder.Clear()
        }
        $success = $true
    }
    catch {$success = $false; throw}
    return $success
} 
#endregion

#region Untility Functions
function CleanUp
{
    try {Remove-Item -Path $global:passwordLocation}catch{}
}

function LoggingHelper
{
    param(
        [string]$Message,
        [bool]$EndOfMessage
    )

    if(!(Write-Logging -Message $Message -WriteToAzure $WriteToAzure -EndOfMessage $EndOfMessage -AzureLogin $LoginName -StorageAccountName $StorageAccountName `
    -ResourceGroupName $ResourceGroupName -Container $Container -WriteLocally $EndOfMessage))
    {
        #Logging returned false
        Write-Host "Failed to log codetrace"
    }
}
#endregion

#Begin Code
try 
{
    LoggingHelper -Message "Starting Script" -EndOfMessage $false
    Write-Host "Starting Script"
    $success = AzureAuthentication -LoginName $LoginName -AzureForGov $AzureForGovernment -ConnectToAzureAd $ConnectToAzureAd -ConnectToAzureAz $ConnectToAzureAz
    if($success)
    {
        #Login Successful
        LoggingHelper -Message "Login Succeeded" -EndOfMessage $false
        Write-Host "Login Succeeded"
        
        #Az cmdlets 
        if($ConnectToAzureAz)
        {#Run Azure Az cmdlets here#######################################################################################################################################################
            
     
            
        }#End of your code################################################################################################################################################################

        #Azure AD cmdlets
        if($ConnectToAzureAd)
        {#Run AzureAd cmdlets here#######################################################################################################################################################
            

            
        }#End of your code################################################################################################################################################################
    }
    else 
    {
        #Login Failed 
        Write-Host "Login Failed or No Access"
        LoggingHelper -Message "Login Failed or No Access" -EndOfMessage $false
    }
}
catch{LoggingHelper -Message "Login Failed (try resetting your password file by setting `$ResetPassword = `$true) $_.Exception.Message"; Write-Host "Login failed"}
if($CleanUp){CleanUp}
LoggingHelper -Message "Ending Script" -EndOfMessage $true
Write-Host "Ending Script"