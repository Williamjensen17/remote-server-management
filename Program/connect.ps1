$RAMNeeded = 8          #RAM ammount in GB 
$DiskNeeded = 20        #Disk ammount in GB

$data = Import-Csv .\Serverlist.csv     #Csv location


function GetData {
    param ($Server)

    #Get the values
    $Hostname = Invoke-Command $Server -ScriptBlock{Hostname}
    $OS = Invoke-Command $Server -ScriptBlock{(Get-CimInstance Win32_OperatingSystem).Caption}
    $Processors = Invoke-Command $Server -ScriptBlock{(Get-CimInstance Win32_ComputerSystem).NumberOfLogicalProcessors}
    $RAMCount = Invoke-Command $Server -ScriptBlock{(Get-CimInstance Win32_PhysicalMemory | Measure-Object -Property capacity -Sum).sum /1gb}
    $BootTime = Invoke-Command $Server -ScriptBlock{(Get-CimInstance Win32_OperatingSystem).LastBootUpTime}    

    #Print the balues
    Write-host Hostname: $Hostname
    Write-host OS: $OS
    Write-host Cores: $Processors
    Write-host RAM: $RAMCount GB
    Write-host IP: $Server
    Write-host Last Boot: $BootTime
    Write-host 
    Write-host
    Invoke-Command $Server -ScriptBlock{gwmi win32_logicaldisk | Format-Table DeviceId, MediaType, @{n="Size";e={[math]::Round($_.Size/1GB,2)}},@{n="FreeSpace";e={[math]::Round($_.FreeSpace/1GB,2)}}}
    Return $RAMCount
}


function Control {
    param ($Server, $RAMCount)

    $breaker = "----------------------------------------"

    Write-Host $breaker
    
    $Online = test-connection $Server
    if (!($Online)) {Write-host Connection status: OFFLINE -foregroundcolor red}
    else{Write-host Connection status: Up -foregroundcolor green}

    $DiskSpace = Invoke-Command $Server -ScriptBlock{"{0:N2}" -f ((Get-CimInstance Win32_LogicalDisk -Filter "DeviceID='C:'").FreeSpace / 1GB)}
    if ($DiskSpace -lt $DiskNeeded)  {Write-host Disk is less than $DiskNeeded GB $DiskSpace -foregroundcolor red}
    else {Write-host more than $DiskNeeded GB left $DiskSpace -foregroundcolor green}

    #enough ram
    $RAMCount = Invoke-Command $Server -ScriptBlock{(Get-CimInstance Win32_PhysicalMemory | Measure-Object -Property capacity -Sum).sum /1gb}
    if ($RAMCount -lt $RAMNeeded) {Write-host Ram is less than $RAMNeeded GB $RAMCount -foregroundcolor red}
    else {Write-host more than $RAMNeeded GB left $RAMCount -foregroundcolor green}

    $Spooler = Invoke-Command $Server -Scriptblock{Get-Service -name Spooler | Select-Object Status}
    Write-host Spooler Status: $Spooler.status
    Write-Host $breaker
    Write-Host

    #Status
    
    if (!($Spooler)){Write-Host Server Status: Critical -ForegroundColor Red; Write-Host Windows Feature: Spooler is not running}
    elseif ($RAMCount -lt $RAMNeeded) {Write-Host Server Status: Critical -ForegroundColor Red; Write-Host Not enough RAM}
    elseif ($DiskSpace -lt $DiskNeeded) {Write-Host Server Status: Critical -ForegroundColor Red; Write-Host Not enough Disk}
    elseif ($RAMCount -lt ($RAMNeeded * 1.2)){Write-Host Server Status: Warning -ForegroundColor Yellow; Write-Host Low on RAM}
    elseif ($DiskSpace -lt ($DiskNeeded *1.2)){Write-Host Server Status: Warning -ForegroundColor Yellow; Write-Host Low on Disk}
}   

foreach ($Server in $data) 
{
    try {

        $header = @"
========================================
            $($Server.IP)
========================================
"@


        Write-host $header
        if (!(test-connection $Server.IP)) {Write-host Server Status: OFFLINE -foregroundcolor yellow}
        else {        
            $RAMCount = GetData -Server $Server.IP
            Control -Server $Server.IP -RAMCount $RAMCount
        }

    }
    catch {
        $_;
    } 
}
