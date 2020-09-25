#requires -version 7
<#
.SYNOPSIS
  Converts Azure Network Security Group (NSG) security rules in Json format (ARM Template) into a Csv output format.
.DESCRIPTION
  Takes a Json file NSG Security Rules information, converts it to a Csv format, 
  and writes a file output. The result of this is a Csv file where a NSG Security Rules can be managed in Csv format.
.PARAMETER JsonFile
  Location of the Json file where the output of the conversion will be placed.
.PARAMETER CsvFile
  Location of the Csv File output of this conversion process.
  This csv will have a header row. Arrays such as SourcePorts will be collapsed into a string separated by the ArraySeparator character.
.PARAMETER CsvArraySeparator
  Separator that is used for arrays in the Csv File format including ports and address prefixes. Default is "|".
.PARAMETER JsonFileType
  Type of file (Parameters, Template) where the input array should come from. This primarily affects 
  the path to the array variable that will be queried for NSG Security Rules.
  For type 'Parameters' this path is: parameters.networkSecurityGroupSecurityRules
  For type 'Template' this path is: variables.networkSecurityGroupSecurityRules
  For type 'Direct'/Default: this path is the root of the file.
.PARAMETER ExcludeBaselineRules
  Does not convert (excludes) rules that qualify as baseline rules. In this scenario this helps create ARM Template Parameters files that do not
  repeat the baseline NSG Security Rules that we store in the ARM Template file.
  This filter is currently very simplistic and relies on rules following our naming convention.
  Rules with names that start I-B or O-B represent baseline rules.
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
param (
    [Parameter()]
    [String]
    $JsonFile,

    [Parameter()]
    [String]
    [ValidateSet('Parameters', 'Template', 'Direct')]
    $JsonFileType,

    [Parameter()]
    [String]
    $CsvFile,
    
    [Parameter()]
    [String]
    $CsvArraySeparator = "|",

    [Parameter()]
    [Boolean]
    $ExcludeBaselineRules = $false
)

function Format-ArrayValue ([object] $arrayObject) {
    if ([string]::IsNullOrEmpty($arrayObject) -or $arrayObject -isnot [array]) {
        return $null
    }
    else {
        return $arrayObject | Join-String -Separator $CsvArraySeparator
    }
}

function Format-StringValue ([object] $stringObject) {
    if ([string]::IsNullOrWhiteSpace($stringObject) -or $stringObject -isnot [string]) {
        return $null
    }
    else {
        return $stringObject
    }
}
function Format-ExportASG ([object] $asgDetailsObject ) {
    if ($null -eq $asgDetailsObject -or -not $asgDetailsObject.id) {
        return $null
    }
    else {
        $asgIdValue = $asgDetailsObject.id
         # Azure Resource Ids are segments separated by '/', in this scenario the last segment is the ASG name.
        $asgIdSlashSplit = $asgIdValue.Split("/")
        $asgNameSegment = $asgIdSlashSplit[$asgIdSlashSplit.Length - 1]
        #In our naming scheme - the 8th postion contains the unique ASG Segment: ais-use-pd-cto-net-vnt-01-windows-asg
        $asgUniqueNameSegment = $asgNameSegment.Split("-")[7]
        return $asgUniqueNameSegment
    }
}

$jsonFileContent = Get-Content $JsonFile -Raw | ConvertFrom-Json -Depth 100
switch ($JsonFileType)
{
  "Parameters" {
    $nsgSecurityRulesJson = $jsonFileContent.parameters.networkSecurityGroupSecurityRules.value
  }
  "Template" {
    $nsgSecurityRulesJson = $jsonFileContent.variables.nsgSecurityRules.baseline
  }
  Default {
    $nsgSecurityRulesJson = $jsonFileContent
  }
}

# Select data from the Json input in the structure defined for the Csv Object.
$reshapedSecurityRulesJson = $nsgSecurityRulesJson |  Select-Object  `
@{name = "name"; expression = { Format-StringValue $_.name } },
@{name = "description"; expression = { Format-StringValue $_.description } },
priority,
@{name = "access"; expression = { Format-StringValue $_.access } },
@{name = "direction"; expression = { Format-StringValue $_.direction } },
@{name = "protocol"; expression = { Format-StringValue $_.protocol } },
@{name = "sourceAddressPrefix"; expression = { Format-StringValue $_.sourceAddressPrefix } },
@{name = "sourceAddressPrefixes"; expression = { Format-ArrayValue $_.sourceAddressPrefixes } },
@{name = "sourceApplicationSecurityGroups"; expression = { if ($SourceJsonType -ne 'Direct') { Format-ArrayValue $_.sourceApplicationSecurityGroups } else { Format-ExportASG $_.sourceApplicationSecurityGroups } } },
@{name = "sourcePortRange"; expression = { Format-StringValue $_.sourcePortRange } },
@{name = "sourcePortRanges"; expression = { Format-ArrayValue $_.sourcePortRanges } },
@{name = "destinationAddressPrefix"; expression = { Format-StringValue $_.destinationAddressPrefix } },
@{name = "destinationAddressPrefixes"; expression = { Format-ArrayValue $_.destinationAddressPrefixes } },
@{name = "destinationApplicationSecurityGroups"; expression = { if ($SourceJsonType -ne 'Direct') { Format-ArrayValue $_.destinationApplicationSecurityGroups } else { Format-ExportASG $_.destinationApplicationSecurityGroups } } },
@{name = "destinationPortRange"; expression = { Format-StringValue $_.destinationPortRange } },
@{name = "destinationPortRanges"; expression = { Format-ArrayValue $_.destinationPortRanges } }

if ($ExcludeBaseline) {
    $nsgSecurityRulesCsv = $reshapedSecurityRulesJson | Sort-Object -Property direction, priority | Where-Object -Property name -NotMatch "^(I|O){1}-B" | ConvertTo-Csv -NoTypeInformation -UseQuotes Never
}
else {
    $nsgSecurityRulesCsv = $reshapedSecurityRulesJson | Sort-Object -Property direction, priority | ConvertTo-Csv -NoTypeInformation -UseQuotes Never
}

$nsgSecurityRulesCsv | Set-Content $CsvFile