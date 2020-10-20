# azure-arm-nsg-via-csv #

## Manage Azure NSG Rules via CSVs ##

A variation on managing Azure NSGs in CSV files while continuing to use Azure Resource Manager (ARM) Templates as the IaC language.

### Files ###

* **nsg\template.json** - The ARM template that deploys the NSGs.
* **nsg\params\params-*.json** - Parameters files for each NSG (subnet in this case). Folder and filenames would be reflect the complexity of your environment and mirror the naming scheme. (For example a params file per subnet NSG, naming that reflects subscription and region, and folders that group by department).
* **nsg\csv\*.csv** - CSV files for each NSG (subnet in this case). This matches the params folder structure.

### Workflow (End State) ###

1. Modify CSV files with an editor of choice: Notepad, Excel, VS Code, etc.
2. On commit a GitHub Action is triggered.
3. The action executes the NsgCsvToJson.ps1 script.
4. The script updates the csv, converts it to NSG Json format, and updates the corresponding params file. This params file, in combination with the ARM Template, can then be run in your environment.
5. The same flow applies to the template.csv file except this file updates the set of baseline rules contained in the template.json file.

### Constraints ###

1. There is a set of _Baseline_ rules that get included in EVERY NSG. For example rules that allow connections to DNS, AD, Patching, etc. These rules are captured in the ARM Template [template.json](.\nsg\template.json)
2. Application Security Groups are a convenient tool to reduce the number of IP addresses directly included in NSGs. They are limited to resources in the current VNET. In this example, ASGs are maintained in the NSG Template where they are used. The VNET Name is supplied to standardize naming but is not created for the purposes of this example.
