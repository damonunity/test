# DamonVN_Activate.ps1
# Script kích hoạt Windows cho người dùng Việt Nam
# Tác giả: Dựa trên Microsoft Activation Scripts (MAS)
# Cảnh báo: Sử dụng script này để kích hoạt Windows mà không có giấy phép hợp lệ là bất hợp pháp.
# Vui lòng mua key bản quyền từ Microsoft hoặc nhà bán lẻ uy tín.

Write-Host "DamonVN Activation Script - Kích hoạt Windows" -ForegroundColor Green
Write-Host "Cảnh báo: Việc sử dụng script này có thể vi phạm điều khoản của Microsoft." -ForegroundColor Yellow

# Liên kết khắc phục sự cố
$troubleshoot = 'https://massgrave.dev/troubleshoot'

# Kiểm tra PowerShell Language Mode
if ($ExecutionContext.SessionState.LanguageMode.value__ -ne 0) {
    Write-Host "Lỗi: PowerShell không chạy ở chế độ Full Language Mode." -ForegroundColor Red
    Write-Host "Hướng dẫn khắc phục: https://gravesoft.dev/fix_powershell" -ForegroundColor White -BackgroundColor Blue
    return
}

# Hàm kiểm tra phần mềm diệt virus
function Check3rdAV {
    $avList = Get-CimInstance -Namespace root\SecurityCenter2 -Class AntiVirusProduct | Where-Object { $_.displayName -notlike '*windows*' } | Select-Object -ExpandProperty displayName
    if ($avList) {
        Write-Host "Cảnh báo: Phần mềm diệt virus có thể chặn script - $($avList -join ', ')" -ForegroundColor DarkRed -BackgroundColor White
    }
}

# Thiết lập giao thức TLS 1.2
[Net.ServicePointManager]::SecurityProtocol = [Net.SecurityProtocolType]::Tls12

# Danh sách URL tải script MAS
$URLs = @(
    'https://raw.githubusercontent.com/massgravel/Microsoft-Activation-Scripts/4e702068bea2cd5372904389ac687c75bc13223f/MAS/All-In-One-Version-KL/MAS_AIO.cmd',
    'https://dev.azure.com/massgrave/Microsoft-Activation-Scripts/_apis/git/repositories/Microsoft-Activation-Scripts/items?path=/MAS/All-In-One-Version-KL/MAS_AIO.cmd&versionType=Commit&version=4e702068bea2cd5372904389ac687c75bc13223f',
    'https://git.activated.win/massgrave/Microsoft-Activation-Scripts/raw/commit/4e702068bea2cd5372904389ac687c75bc13223f/MAS/All-In-One-Version-KL/MAS_AIO.cmd'
)

# Thử tải script MAS
$response = $null
foreach ($URL in $URLs | Sort-Object { Get-Random }) {
    try {
        Write-Host "Đang tải script từ $URL..." -ForegroundColor Cyan
        $response = Invoke-WebRequest -Uri $URL -UseBasicParsing
        break
    } catch {
        Write-Host "Không thể tải từ $URL, thử URL tiếp theo..." -ForegroundColor Yellow
    }
}

if (-not $response) {
    Check3rdAV
    Write-Host "Lỗi: Không thể tải script MAS, đang dừng!" -ForegroundColor Red
    Write-Host "Hướng dẫn khắc phục: $troubleshoot" -ForegroundColor White -BackgroundColor Blue
    return
}

# Kiểm tra hash SHA256
$releaseHash = '000DB2C899D009AFAFC19CF04A9BF5381F5520CB21395A29B0DB57483FA7A909'
$stream = New-Object IO.MemoryStream
$writer = New-Object IO.StreamWriter $stream
$writer.Write($response)
$writer.Flush()
$stream.Position = 0
$hash = [BitConverter]::ToString([Security.Cryptography.SHA256]::Create().ComputeHash($stream)) -replace '-'
if ($hash -ne $releaseHash) {
    Write-Host "Lỗi: Hash không khớp ($hash), script có thể bị sửa đổi!" -ForegroundColor Red
    Write-Host "Báo cáo vấn đề tại: $troubleshoot" -ForegroundColor White -BackgroundColor Blue
    return
}

# Kiểm tra registry AutoRun
$paths = "HKCU:\SOFTWARE\Microsoft\Command Processor", "HKLM:\SOFTWARE\Microsoft\Command Processor"
foreach ($path in $paths) {
    if (Get-ItemProperty -Path $path -Name "Autorun" -ErrorAction SilentlyContinue) {
        Write-Host "Cảnh báo: Tìm thấy registry AutoRun, CMD có thể lỗi!" -ForegroundColor Yellow
        Write-Host "Sửa bằng lệnh: Remove-ItemProperty -Path '$path' -Name 'Autorun'" -ForegroundColor Cyan
    }
}

# Tạo file CMD tạm
$rand = [Guid]::NewGuid().Guid
$isAdmin = [bool]([Security.Principal.WindowsIdentity]::GetCurrent().Groups -match 'S-1-5-32-544')
$tempPath = if ($isAdmin) { "$env:SystemRoot\Temp" } else { "$env:USERPROFILE\AppData\Local\Temp" }
$FilePath = "$tempPath\DamonVN_$rand.cmd"
Set-Content -Path $FilePath -Value "@::: $rand `r`n$response" -ErrorAction Stop
if (-not (Test-Path $FilePath)) {
    Check3rdAV
    Write-Host "Lỗi: Không thể tạo file tạm, đang dừng!" -ForegroundColor Red
    Write-Host "Hướng dẫn khắc phục: $troubleshoot" -ForegroundColor White -BackgroundColor Blue
    return
}

# Kiểm tra CMD
$env:ComSpec = "$env:SystemRoot\system32\cmd.exe"
$chkcmd = & $env:ComSpec /c "echo CMD is working"
if ($chkcmd -notcontains "CMD is working") {
    Write-Host "Lỗi: cmd.exe không hoạt động!" -ForegroundColor Red
    Write-Host "Báo cáo vấn đề tại: $troubleshoot" -ForegroundColor White -BackgroundColor Blue
    return
}

# Chạy script MAS
Write-Host "Đang kích hoạt Windows..." -ForegroundColor Green
Start-Process -FilePath $env:ComSpec -ArgumentList "/c """"$FilePath"" $args""" -Wait

# Dọn dẹp
Write-Host "Đang dọn dẹp file tạm..." -ForegroundColor Green
Remove-Item "$tempPath\DamonVN*.cmd" -ErrorAction SilentlyContinue

# Thông báo hoàn tất
Write-Host "Hoàn tất! Kiểm tra trạng thái kích hoạt trong Cài đặt > Hệ thống > Kích hoạt." -ForegroundColor Green
Write-Host "Lưu ý: Hãy mua key bản quyền để tuân thủ pháp luật." -ForegroundColor Yellow
