$ErrorActionPreference = "Stop"
$pw = (Get-Content "C:\Users\DELL\IDEProjects\HWView\deploy\.sshpw" -Raw).Trim()
$plink = "C:\Program Files\PuTTY\plink.exe"
$target = "debian@192.168.2.110"
$baseDir = "C:\Users\DELL\IDEProjects\HWView"

# Step 1: Cache host key
Write-Host "=== Caching host key ==="
$psi = New-Object System.Diagnostics.ProcessStartInfo
$psi.FileName = $plink
$psi.Arguments = "-ssh -pw $pw $target exit"
$psi.UseShellExecute = $false
$psi.RedirectStandardInput = $true
$psi.RedirectStandardOutput = $true
$psi.RedirectStandardError = $true
$p = [System.Diagnostics.Process]::Start($psi)
Start-Sleep -Milliseconds 500
if (-not $p.HasExited) {
    $p.StandardInput.WriteLine("y")
    $p.WaitForExit(5000)
}
Write-Host "Host key cache exit: $($p.ExitCode)"

# Step 2: Test connection with batch mode
Write-Host "=== Testing SSH (batch mode) ==="
$psi2 = New-Object System.Diagnostics.ProcessStartInfo
$psi2.FileName = $plink
$psi2.Arguments = "-ssh -pw $pw -batch $target `"whoami && uname -a && cat /etc/os-release | head -3`""
$psi2.UseShellExecute = $false
$psi2.RedirectStandardOutput = $true
$psi2.RedirectStandardError = $true
$p2 = [System.Diagnostics.Process]::Start($psi2)
$p2.WaitForExit(15000)
Write-Host "STDOUT: $($p2.StandardOutput.ReadToEnd())"
Write-Host "STDERR: $($p2.StandardError.ReadToEnd())"
Write-Host "ExitCode: $($p2.ExitCode)"
