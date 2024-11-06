# Kiểm tra xem PowerShell có đang chạy với quyền admin hay không
If (-Not ([Security.Principal.WindowsPrincipal] [Security.Principal.WindowsIdentity]::GetCurrent()).IsInRole([Security.Principal.WindowsBuiltInRole] "Administrator"))
{
    Write-Warning "Vui lòng chạy PowerShell với quyền Administrator."
    Start-Process powershell -ArgumentList "-NoProfile -ExecutionPolicy Bypass -File `"$PSCommandPath`"" -Verb RunAs
    Exit
}

# Hiển thị menu
function Show-Menu {
    Clear-Host
    Write-Host "=========================" -ForegroundColor Cyan
    Write-Host " Admin Menu" -ForegroundColor Green
    Write-Host "=========================" -ForegroundColor Cyan
    Write-Host "1. Lựa chọn 1 - Ví dụ: Kiểm tra trạng thái dịch vụ"
    Write-Host "2. Lựa chọn 2 - Ví dụ: Khởi động lại máy"
    Write-Host "3. Lựa chọn 3 - Ví dụ: Thoát" 
    Write-Host "=========================" -ForegroundColor Cyan
}

# Thực hiện hành động dựa trên lựa chọn của người dùng
function Process-Choice {
    param (
        [int]$choice
    )

    switch ($choice) {
        1 {
            Write-Host "Lựa chọn 1: Kiểm tra trạng thái dịch vụ..."
            Get-Service | Out-Host
        }
        2 {
            Write-Host "Lựa chọn 2: Khởi động lại máy..."
            Restart-Computer -Force
        }
        3 {
            Write-Host "Thoát chương trình."
            Exit
        }
        default {
            Write-Host "Lựa chọn không hợp lệ. Vui lòng chọn lại." -ForegroundColor Red
        }
    }
}

# Chạy menu chính
do {
    Show-Menu
    $choice = Read-Host "Vui lòng chọn một tùy chọn (1-3)"
    Process-Choice -choice $choice
    Start-Sleep -Seconds 2
} while ($choice -ne 3)
