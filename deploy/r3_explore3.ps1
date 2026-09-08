$pw = (Get-Content "C:\Users\DELL\IDEProjects\HWView\deploy\.sshpw" -Raw).Trim()
$plink = "C:\Program Files\PuTTY\plink.exe"
$pscp = "C:\Program Files\PuTTY\pscp.exe"
$target = "debian@192.168.2.110"
$hostkey = "SHA256:C20ScxLx9sNJUXiw0vSsEC2w7aQ1K3J98FHaeJN2q14"

$script = @'
#!/bin/bash
endpoints=(
  "/Cron/Jili/savePackInfo"
  "/Cron/Jili/print_wei"
  "/Cron/Jili/scan"
  "/Cron/Jili/pack"
  "/Cron/Jili/box"
  "/Cron/Jili/save"
  "/Cron/Jili/data"
  "/Cron/Jili/list"
  "/Cron/Jili/all"
  "/Cron/Jili/history"
  "/Cron/Jili/log"
  "/Cron/Jili/records"
  "/Cron/Jili/packinfo"
  "/Cron/Jili/boxinfo"
  "/Cron/Jili/scanlog"
  "/Cron/Jili/packlog"
  "/Cron/Jili/boxlog"
  "/Cron/Jili/success"
  "/Cron/Jili/done"
  "/Cron/Baozhuang/lists"
  "/Cron/Baozhuang/"
  "/Cron/Dabao/lists"
  "/Cron/Dabao/"
  "/Cron/Ruku/lists"
  "/Cron/Ruku/"
  "/Cron/Chuku/lists"
  "/Cron/Chuku/"
  "/Cron/Kucun/lists"
  "/Cron/Kucun/"
  "/Cron/Shengchan/lists"
  "/Cron/Shengchan/"
  "/Cron/Chanliang/lists"
  "/Cron/Chanliang/"
  "/Cron/Zhuangxiang/lists"
  "/Cron/Zhuangxiang/"
  "/Cron/Rewu/lists"
  "/Cron/Rewu/"
  "/Cron/Gongdan/lists"
  "/Cron/Gongdan/"
  "/Cron/Bianma/lists"
  "/Cron/Bianma/"
  "/Cron/Tiaoma/lists"
  "/Cron/Tiaoma/"
  "/Cron/Jili/lists/type/1"
  "/Cron/Jili/lists/type/0"
  "/Cron/Jili/lists/op/初打"
  "/Cron/Jili/lists/op/print"
  "/Cron/Jili/lists/action/scan"
  "/Cron/Jili/lists/status/1"
  "/Cron/Jili/lists/is_rework/0"
  "/Cron/Jili/lists/is_rework/2"
)
for ep in "${endpoints[@]}"; do
  url="http://192.168.30.2:86${ep}"
  code=$(curl -s -o /dev/null -w '%{http_code}' "$url" 2>/dev/null)
  size=$(curl -s -o /dev/null -w '%{size_download}' "$url" 2>/dev/null)
  if [ "$code" != "404" ] && [ "$code" != "302" ]; then
    echo "*** FOUND: ${ep}: HTTP ${code}, ${size} bytes ***"
  fi
done
echo "--- Done ---"
'@

$script = $script -replace "`r`n", "`n"

$tmpFile = [System.IO.Path]::GetTempFileName()
[System.IO.File]::WriteAllText($tmpFile, $script, [System.Text.UTF8Encoding]::new($false))

& $pscp -pw $pw -batch -hostkey $hostkey $tmpFile "${target}:/tmp/r3_explore3.sh"
& $plink -ssh -pw $pw -batch -hostkey $hostkey $target "bash /tmp/r3_explore3.sh"

Remove-Item $tmpFile -Force