#requires -version 7
<#
.SYNOPSIS
  Converts Azure Network Security Group (NSG) security rules in CSV format into an ARM Template Json Output.
.DESCRIPTION
  Takes a CSV containing NSG Security Rules information, converts it to the ARM template Json format, 
  and places the output array into the appropriate location. The result of this is a Json template or 
  parameters file where a NSG Security Rules array will be updated in place.
.PARAMETER CsvFile
  Location of the Csv File that is used as input to the conversion process.
  This csv file should have a header row. Field names should match the Json Structure of a ARM Template NSG Security Rule.
.PARAMETER JsonFile
  Location of the Json file where the output of the conversion will be placed.
.PARAMETER JsonFileType
  Type of file (Parameters, Template) where the output array should be placed. This primarily affects 
  the path to the array variable that should be updated.
  For type 'Parameters' this path is: parameters.networkSecurityGroupSecurityRules
  For type 'Template' this path is: variables.networkSecurityGroupSecurityRules
  For type 'Direct'/Default: this path is the root of the file.
.PARAMETER CsvArraySeparator
  Separator that is used for arrays in the Csv File including ports and address prefixes. Defaults is "|".
.INPUTS
  None
.OUTPUTS
  None
.NOTES
  Version:        1.0
  Author:         Matthew Dupré
  Creation Date:  2020/09/15
  Purpose/Change: Initial script development
.EXAMPLE

#>

#---------------------------------------------------------[Script Parameters]------------------------------------------------------
[CmdletBinding()]
Param (
    [Parameter()]
    [String]
    $CsvFile,

    [Parameter()]
    [String]
    $JsonFile,

    [Parameter()]
    [String]
    [ValidateSet('Parameters', 'Template', 'Direct')]
    $JsonFileType = "Direct",
    
    [Parameter()]
    [String]
    $CsvArraySeparator = "|"
)

function Split-StringObject ([object] $stringObject) {
    if ($stringObject -is [string] -and -not [string]::IsNullOrWhiteSpace($stringObject)) {
        $outputArrayValue = $stringObject.Split($CsvArraySeparator)
        return [array] $outputArrayValue
    }
    else {
        return $null
    }
}

# Read the Input Csv File
$nsgCsvFileObject = Get-Content $CsvFile -Raw | ConvertFrom-Csv

# Process each defined rule
$reshapedSecurityRulesObject = $nsgCsvFileObject | ForEach-Object {

    # Build array values from separated strings
    $sourceAddressPrefixes = [string[]] (Split-StringObject $_.sourceAddressPrefixes)
    $sourceApplicationSecurityGroups = [string[]] (Split-StringObject $_.sourceApplicationSecurityGroups)
    $sourcePortRanges = [string[]] (Split-StringObject $_.sourcePortRanges)
    $destinationAddressPrefixes = [string[]] (Split-StringObject $_.destinationAddressPrefixes)
    $destinationApplicationSecurityGroups = [string[]] (Split-StringObject $_.destinationApplicationSecurityGroups)
    $destinationPortRanges = [string[]] (Split-StringObject $_.destinationPortRanges)

    # Shape the JSON Output for the ARM Files
    [PSCustomObject]@{
        name                                 = [string] $_.name
        description                          = [string] $_.description
        priority                             = [int] $_.priority
        access                               = [string] $_.access
        direction                            = [string] $_.direction
        protocol                             = [string] $_.protocol
        sourceAddressPrefix                  = [string] $_.sourceAddressPrefix
        sourceAddressPrefixes                = $sourceAddressPrefixes
        sourceApplicationSecurityGroups      = $sourceApplicationSecurityGroups
        sourcePortRange                      = [string] $_.sourcePortRange
        sourcePortRanges                     = $sourcePortRanges
        destinationAddressPrefix             = [string] $_.destinationAddressPrefix
        destinationAddressPrefixes           = $destinationAddressPrefixes
        destinationApplicationSecurityGroups = $destinationApplicationSecurityGroups
        destinationPortRange                 = [string] $_.destinationPortRange
        destinationPortRanges                = $destinationPortRanges
    }
}

# Write the output File
switch ($JsonFileType) {
    "Parameters" {
        if (-not (Test-Path -Path $JsonFile -PathType Leaf)) {
            Write-Host "Path $JsonFile Does not exist"
        }
        # Read the contents of the destination file as Json
        $nsgParamsFileData = Get-Content $JsonFile -Raw | ConvertFrom-Json -Depth 100 -NoEnumerate
        # Replace the contents of the networkSecurityGroupSecurityRules Array
        $nsgParamsFileData.parameters.networkSecurityGroupSecurityRules.value = [array] $reshapedSecurityRulesObject
        $nsgParamsJson = ConvertTo-Json -InputObject $nsgParamsFileData -Depth 10
        # Write the Json File
        $nsgParamsJson | Set-Content $JsonFile
    }
    "Template" {
        if (-not (Test-Path -Path $JsonFile -PathType Leaf)) {
            Write-Host "Path $JsonFile Does not exist"
        }
        # Read the contents of the destination file as Json
        $nsgTemplateFileData = Get-Content $JsonFile -Raw | ConvertFrom-Json -Depth 100 -NoEnumerate
        # Replace the contents of the networkSecurityGroupSecurityRules Array
        $nsgTemplateFileData.variables.nsgSecurityRules.baseline = [array] $reshapedSecurityRulesObject
        $nsgTemplateJson = ConvertTo-Json -InputObject $nsgTemplateFileData -Depth 10
        # Write the Json File
        $nsgTemplateJson | Set-Content $JsonFile
    }
    Default {
        # Write the output directly to the output file, replacing all contents
        $nsgJson = ConvertTo-Json -InputObject $reshapedSecurityRulesObject -Depth 10
        $nsgJson | Set-Content $JsonFile
    }
}