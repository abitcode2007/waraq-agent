# رفع كل التعديلات إلى GitHub بضغطة واحدة
# الاستخدام: .\push.ps1 "رسالة التعديل"   (الرسالة اختيارية)
$ErrorActionPreference = 'Stop'
Set-Location $PSScriptRoot

$msg = if ($args.Count -gt 0) { $args -join ' ' } else { 'تحديث ' + (Get-Date -Format 'yyyy-MM-dd HH:mm') }

git add -A
if ($LASTEXITCODE) { exit $LASTEXITCODE }

if (git diff --cached --quiet) {
    Write-Host '✔ لا توجد تغييرات للرفع.' -ForegroundColor Green
    exit 0
}

git commit -m $msg
if ($LASTEXITCODE) { exit $LASTEXITCODE }

git push
if ($LASTEXITCODE) { exit $LASTEXITCODE }

Write-Host '✔ تم الرفع — سيحدّث GitHub Pages تلقائياً خلال دقائق.' -ForegroundColor Green
