#Authentication window Script 
    Function Show-OAuthWindow {
    Add-Type -AssemblyName System.Windows.Forms
 
    $form = New-Object -TypeName System.Windows.Forms.Form -Property @{Width=600;Height=800}
    $web  = New-Object -TypeName System.Windows.Forms.WebBrowser -Property @{Width=580;Height=780;Url=($url -f ($Scope -join "%20")) }
    $DocComp  = {
            $Global:uri = $web.Url.AbsoluteUri
            if ($Global:Uri -match "error=[^&]*|code=[^&]*") {$form.Close() }
    }
    $web.ScriptErrorsSuppressed = $true
    $web.Add_DocumentCompleted($DocComp)
    $form.Controls.Add($web)
    $form.Add_Shown({$form.Activate()})
    $form.ShowDialog() | Out-Null
    }
    #endregion


#Connect to target subscription

Connect-AzAccount

$StorageName = Read-Host -Prompt "Enter a name for the storage account"
$ServiceBus = Read-Host -Prompt "Enter a name for the Serivce Bus"

#Deploy The Bulk Template, Excluding un-supported templates, HardCoded Directory
New-AzResourceGroupDeployment -ResourceGroupName BusResource -TemplateFile C:\Users\Oskar\Source\Repos\CrDeMailProject\CrDeMailProject\azuredeploy.json -TemplateParameterFile C:\Users\Oskar\Source\Repos\CrDeMailProject\CrDeMailProject\azuredeploy.parametersProd.json -namespaces_azemployeebusprod_name $ServiceBus  -storageAccounts_employeestorageunqprod_name $StorageName

#Deploy Hardcoded "Employee" table to established storage account
$Storage = Get-AzStorageAccount -ResourceGroupName BusResource -Name $StorageName
$ctx = $Storage.Context
New-AzStorageTable -Name Employee -Context $ctx
$table = (get-AzStorageTable -Name Employee -Context $ctx).CloudTable

Add-AzTableRow `
    -table $table `
    -partitionKey "Tech" `
    -rowKey ("1") -property @{"Admin"=[boolean]0;"EmailAdress"="SomeMail";"Name"="Erik"}

#parameter for connecter authentication
$parameters = @{
	"parameters" = ,@{
	"parameterName"= "token";
	"redirectUrl"= "https://ema1.exp.azure.com/ema/default/authredirect"
	}
}

#Grab Connection resource and set authentication token
$outlookResource = get-azresource -ResourceGroupName BusResource -Name outlook
#Get Authentication Adress
$ConsentResponse = Invoke-AzResourceAction -Action "listConsentLinks" -ResourceId $outlookResource.ResourceId -Parameters $parameters
$url = $ConsentResponse.Value.link
#Activate authentication script 
Show-OAuthWindow -Url $url

#UnManaged
$regex = '(code=)(.*)$'
    $code  = ($uri | Select-string -pattern $regex).Matches[0].Groups[2].Value
    Write-output "Received an accessCode: $code"

if (-Not [string]::IsNullOrEmpty($code)) {
	$parameters = @{ }
	$parameters.Add("code", $code)

Invoke-AzResourceAction -Action "confirmConsentCode" -ResourceId $outlookResource.ResourceId -Parameters $parameters -Force -ErrorAction Ignore
}

$outlookResource = Get-AzResource -ResourceType "Microsoft.Web/connections" -ResourceGroupName BusResource -ResourceName outlook
Write-Host "connection status now: " $outlookResource.Properties.Statuses[0]