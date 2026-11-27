param([string]$ResDir = (Join-Path $PSScriptRoot '..\android\app\src\main\res'))

Add-Type -AssemblyName System.Drawing

$green = [System.Drawing.Color]::FromArgb(255, 18, 59, 52)
$white = [System.Drawing.Color]::FromArgb(255, 255, 255, 255)
$png = [System.Drawing.Imaging.ImageFormat]::Png

$densities = @(
  @{ name='mdpi'; size=48; fg=108 },
  @{ name='hdpi'; size=72; fg=162 },
  @{ name='xhdpi'; size=96; fg=216 },
  @{ name='xxhdpi'; size=144; fg=324 },
  @{ name='xxxhdpi'; size=192; fg=432 }
)

function New-Icon([int]$size, [bool]$transparent, [bool]$round) {
  $bmp = New-Object System.Drawing.Bitmap($size, $size)
  $g = [System.Drawing.Graphics]::FromImage($bmp)
  $g.SmoothingMode = [System.Drawing.Drawing2D.SmoothingMode]::HighQuality
  $g.TextRenderingHint = [System.Drawing.Text.TextRenderingHint]::AntiAliasGridFit
  if ($transparent) { $g.Clear([System.Drawing.Color]::Transparent) } else { $g.Clear($green) }

  if (-not $transparent -and $round) {
    $brush = New-Object System.Drawing.SolidBrush($green)
    $g.FillEllipse($brush, 0, 0, $size - 1, $size - 1)
    $brush.Dispose()
  }

  $fontSize = [Math]::Max(8, [int]($size * 0.46))
  $font = New-Object System.Drawing.Font('Arial', $fontSize, [System.Drawing.FontStyle]::Bold, [System.Drawing.GraphicsUnit]::Pixel)
  $sf = New-Object System.Drawing.StringFormat
  $sf.Alignment = [System.Drawing.StringAlignment]::Center
  $sf.LineAlignment = [System.Drawing.StringAlignment]::Center
  $sf.FormatFlags = $sf.FormatFlags -bor [System.Drawing.StringFormatFlags]::DirectionRightToLeft
  $brush = New-Object System.Drawing.SolidBrush($white)
  $rect = New-Object System.Drawing.RectangleF(0, 0, $size, $size)
  $word = [string][char]0x0648 + [char]0x0631 + [char]0x0642
  $g.DrawString($word, $font, $brush, $rect, $sf)

  $brush.Dispose()
  $sf.Dispose()
  $font.Dispose()
  $g.Dispose()
  return $bmp
}

foreach ($d in $densities) {
  $dir = Join-Path $ResDir ('mipmap-' + $d.name)
  New-Item -ItemType Directory -Force -Path $dir | Out-Null

  $square = New-Icon $d.size $false $false
  $out = Join-Path $dir 'ic_launcher.png'
  $square.Save($out, $png)
  $square.Dispose()

  $circle = New-Icon $d.size $false $true
  $out = Join-Path $dir 'ic_launcher_round.png'
  $circle.Save($out, $png)
  $circle.Dispose()

  $fg = New-Icon $d.fg $true $false
  $out = Join-Path $dir 'ic_launcher_foreground.png'
  $fg.Save($out, $png)
  $fg.Dispose()
}

$bgFile = Join-Path $ResDir 'values\ic_launcher_background.xml'
$bg = '<?xml version="1.0" encoding="utf-8"?>' + [Environment]::NewLine +
      '<resources>' + [Environment]::NewLine +
      '    <color name="ic_launcher_background">#123B34</color>' + [Environment]::NewLine +
      '</resources>'
Set-Content -Path $bgFile -Value $bg -Encoding utf8

Write-Host 'Android icons generated.'
