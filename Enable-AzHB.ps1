[CmdletBinding()]
param (
    [Parameter()]
    [string]$FilePath
)

# create csv result file
$scriptDir = $PSScriptRoot
$resultPath = "$($scriptDir)/result/"
$resultFile = New-Item -Path $resultPath -Name "AHUB-$(get-date -Format ddMMyyyy-hhmmss).csv" -Force 
Write-Host "Result file created: $($resultFile.FullName)"

# Import the csv file
$data = Import-Csv -Path $FilePath

# loop through each row
foreach ($row in $data) {
  # put row's data into object for export to result file
    $rowData = [PSCustomObject]@{
    VmName = $row.VmName
    ResourceGroup = $row.ResourceGroup
    Subscription = $row.Subscription
  }

  # get current sub of the CLI
  $curSub = (Get-AzContext).Subscription.Name
  if ($curSub -ne $row.Subscription) {
    try {
      Set-AzContext -Subscription $row.Subscription  
    }
    catch {
      $rowData | Add-Member -NotePropertyName "Result" -NotePropertyValue "Unable to set CLI subscription to $($row.Subscription)"
      $rowData
      Continue
    }
  }

  # get vm data
  # if failed to get vm then skip to the next row
  try {
    $vmData = Get-AzVM -ResourceGroupName $row.ResourceGroup -Name $row.VmName 
  }
  catch {
    $rowData | Add-Member -NotePropertyName "Result" -NotePropertyValue "VM $($row.VmName) not exist in $($row.ResourceGroup)"
    $rowData
    continue
  }

  # check if vm is windows or not
  if ($vmData.StorageProfile.osDisk.OsType -ne "Windows") {
    $rowData | Add-Member -NotePropertyName "Result" -NotePropertyValue "VM $($row.VmName) OS is $($vmData.StorageProfile.osDisk.OsType)"
    $rowData
    continue
  }

  # if LicenseType Attribute is not defined then set else skip to next row
  if (($vmData.LicenseType -eq '') -or ($vmData.LicenseType -eq $null)) {
    $vmData.LicenseType = "Windows_Server"
    try {
      Update-AzVM -ResourceGroupName $row.ResourceGroup -VM $vmData -ErrorAction Stop
      $rowData | Add-Member -NotePropertyName "Result" -NotePropertyValue $true
      $rowData | Export-Csv -Path $resultFile.FullName -NoTypeInformation -Append -Force
      $rowData
    }
    catch {
      $rowData | Add-Member -NotePropertyName "Result" -NotePropertyValue $false
      $rowData | Export-Csv -Path $resultFile.FullName -NoTypeInformation -Append -Force
      $rowData
    }
  }
  else {
    $rowData | Add-Member -NotePropertyName "Result" -NotePropertyValue $true
    $rowData | Export-Csv -Path $resultFile.FullName -NoTypeInformation -Append -Force
    $rowData
    continue
  }
}
