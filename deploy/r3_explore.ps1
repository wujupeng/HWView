$pw = (Get-Content "C:\Users\DELL\IDEProjects\HWView\deploy\.sshpw" -Raw).Trim()
$plink = "C:\Program Files\PuTTY\plink.exe"
$pscp = "C:\Program Files\PuTTY\pscp.exe"
$target = "debian@192.168.2.110"
$hostkey = "SHA256:C20ScxLx9sNJUXiw0vSsEC2w7aQ1K3J98FHaeJN2q14"

$script = @'
#!/bin/bash
endpoints=(
  "/Cron/Jili/"
  "/Cron/Jili/index"
  "/Cron/"
  "/Cron/Index/"
  "/Cron/Index/index"
  "/Home/"
  "/Home/Index/"
  "/Admin/"
  "/Admin/Index/"
  "/Api/"
  "/Api/Index/"
  "/Cron/Production/"
  "/Cron/Production/lists"
  "/Cron/Product/"
  "/Cron/Product/lists"
  "/Cron/Count/"
  "/Cron/Count/lists"
  "/Cron/Report/"
  "/Cron/Report/lists"
  "/Cron/Stat/"
  "/Cron/Stat/lists"
  "/Cron/Data/"
  "/Cron/Data/lists"
  "/Cron/Output/"
  "/Cron/Output/lists"
  "/Cron/Result/"
  "/Cron/Result/lists"
  "/Cron/Finish/"
  "/Cron/Finish/lists"
  "/Cron/Complete/"
  "/Cron/Complete/lists"
  "/Cron/Store/"
  "/Cron/Store/lists"
  "/Cron/Stock/"
  "/Cron/Stock/lists"
  "/Cron/Warehouse/"
  "/Cron/Warehouse/lists"
  "/Cron/Jili/add"
  "/Cron/Jili/edit"
  "/Cron/Jili/detail"
  "/Cron/Jili/count"
  "/Cron/Jili/stat"
  "/Cron/Jili/total"
  "/Cron/Jili/summary"
  "/Cron/Jili/export"
  "/Cron/Jili/report"
  "/Index/"
  "/Index/index"
)
for ep in "${endpoints[@]}"; do
  url="http://192.168.30.2:86${ep}"
  code=$(curl -s -o /dev/null -w '%{http_code}' "$url" 2>/dev/null)
  size=$(curl -s -o /dev/null -w '%{size_download}' "$url" 2>/dev/null)
  echo "${ep}: HTTP ${code}, ${size} bytes"
done
'@

$script = $script -replace "`r`n", "`n"

$tmpFile = [System.IO.Path]::GetTempFileName()
[System.IO.File]::WriteAllText($tmpFile, $script, [System.Text.UTF8Encoding]::new($false))

& $pscp -pw $pw -batch -hostkey $hostkey $tmpFile "${target}:/tmp/r3_explore.sh"
& $plink -ssh -pw $pw -batch -hostkey $hostkey $target "bash /tmp/r3_explore.sh"

Remove-Item $tmpFile -Force
