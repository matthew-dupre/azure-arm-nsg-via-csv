# azure-arm-nsg-via-csv

## Manage Azure NSG Rules via CSVs

A variation on managing Azure NSGs in CSV files while continuing to use Azure Resource Manager (ARM) Templates as your IaC language.

Constraints:

1. NSGs are applied to subnets, not NICs. (Relevant?)
2. There is a set of _Baseline_ rules that get included in EVERY NSG. For example rules that allow connections to DNS, AD, Patching, etc.
3. Application Security Groups are a convenient tool to reduce the number of IP addresses directly included in NSGs. They are limited to resources in the current VNET.

Files:
template.json - The ARM template that deploys the NSGs.
params-*.json - Parameters files for each NSG (subnet in this case). Folder and filenames would be reflect the complexity of your environment and mirror the naming scheme. (For example a params file per subnet NSG, naming that reflects subscription and region, and folders that group by department).
*.csv - CSV files for each NSG (subnet in this case). This matches the params folder structure.

Workflow:
Modify CSV files with your editor of choice: Notepad, Excel, etc. On commit a GitHub Action is triggered. The action executes the NsgCsvToJson.ps1 script. The script updates the csv, converts it to NSG Json format, and updates the corresponding params file. This params file, in combination with the ARM Template, can then be run in your environment.
The same flow applies to the template.csv file except this file updates the set of baseline rules contained in the template.json file.
