# Close all works on wsl before running the script as the script will shutdown wsl
#
# Define the path to the VHDX file
# You will need to find the location of the ext4.vhdx to comact
$vdiskPath = "C:\Users\Lorran\AppData\Local\Packages\CanonicalGroupLimited.Ubuntu_79rhkp1fndgsc\LocalState\ext4.vhdx"

# Shut down WSL to ensure no files are in use
wsl --shutdown

# Only is the disk is space Optimize-VHD will work
fsutil sparse setflag $vdiskPath 0

# Optimize the VHDX file
Optimize-VHD -Path $vdiskPath -Mode Full

# Use DiskPart to compact the VHD
$diskPartCommands = @"
select vdisk file "$vdiskPath"
compact vdisk
"@

# Create a temporary script for DiskPart
$diskPartScriptPath = "diskpart-script.txt"
$diskPartCommands | Set-Content -Path $diskPartScriptPath

# Execute DiskPart with the script
diskpart /s $diskPartScriptPath

# Optional: Clean up the DiskPart script
Remove-Item -Path $diskPartScriptPath