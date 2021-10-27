#
# Copyright © 2021 The Kubnernetes Authoers
#
# Licensed under the Apache License, Version 2.0 (the "License");
# you may not use this file except in compliance with the License.
# You may obtain a copy of the License at
#
#     http://www.apache.org/licenses/LICENSE-2.0
#
# Unless required by applicable law or agreed to in writing, software
# distributed under the License is distributed on an "AS IS" BASIS,
# WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
# See the License for the specific language governing permissions and
# limitations under the License.
#

Param (
    [parameter(Mandatory = $true, HelpMessage="Method to install callback, Startup or Shutdown")] [string] $method,
    [parameter(Mandatory = $true, HelpMessage="Script to be invoked")] [string] $methodScript
)

# Reg keys used for a method
$RegPath = "HKLM:\SOFTWARE\Microsoft\Windows\CurrentVersion\Group Policy"
$RegScriptsPath = "$RegPath\Scripts\$method\0"
$RegSmScriptsPath = "$RegPath\State\Machine\Scripts\$method\0"

# Create the path if not exist
$methodPath = "$ENV:systemRoot\System32\GroupPolicy\Machine\Scripts\$method"
if (-not (Test-Path $methodPath)) {
    New-Item -path $methodPath -itemType Directory
}

$items = @("$RegScriptsPath\0", "$RegSmScriptsPath\0")
foreach ($item in $items) {
    if (-not (Test-Path $item)) {
        New-Item -path $item -force
    }
}

$items = @("$RegScriptsPath", "$RegSmScriptsPath")
foreach ($item in $items) {
    New-ItemProperty -path "$item" -name DisplayName -propertyType String -value "Local Group Policy" -force
    New-ItemProperty -path "$item" -name FileSysPath -propertyType String -value "$ENV:systemRoot\System32\GroupPolicy\Machine" -force
    New-ItemProperty -path "$item" -name GPO-ID -propertyType String -value "LocalGPO" -force
    New-ItemProperty -path "$item" -name GPOName -propertyType String -value "Local Group Policy" -force
    New-ItemProperty -path "$item" -name PSScriptOrder -propertyType DWord -value 2 -force
    New-ItemProperty -path "$item" -name SOM-ID -propertyType String -value "Local" -force
}

$BinaryString = "00,00,00,00,00,00,00,00,00,00,00,00,00,00,00,00"
$ExecTime = $BinaryString.Split(',') | ForEach-Object {"0x$_"}
$items = @("$RegScriptsPath\0", "$RegSmScriptsPath\0")
foreach ($item in $items) {
    New-ItemProperty -path "$item" -name Script -propertyType String -value $methodScript -force
    New-ItemProperty -path "$item" -name Parameters -propertyType String -value $method -force
    New-ItemProperty -path "$item" -name IsPowershell -propertyType DWord -value 1 -force
    New-ItemProperty -path "$item" -name ExecTime -propertyType Binary -value ([byte[]]$ExecTime) -force
}
