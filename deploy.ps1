$resourceGroupName = "rg-chatgpt-01"
$templateFilePath = ".\main.json"
$parametersFilePath = ".\azuredeploy.parameters.json"

New-AzResourceGroup -Name $resourceGroupName -Location "westeurope"
$randomString = $randomString = -join ((97..122) | Get-Random -Count 8 | % { [char]$_ })
$storageAccountName = "mystorageaccount$randomString"

New-AzResourceGroupDeployment -ResourceGroupName $resourceGroupName -TemplateFile $templateFilePath -TemplateParameterFile $parametersFilePath -storageAccountName $storageAccountName