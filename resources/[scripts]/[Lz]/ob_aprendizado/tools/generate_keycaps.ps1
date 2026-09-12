Add-Type -AssemblyName System.Drawing

$output = Resolve-Path -LiteralPath (Join-Path $PSScriptRoot '..\web\assets')

function New-RoundedRectanglePath {
    param([System.Drawing.RectangleF]$Rectangle, [float]$Radius)

    $path = [System.Drawing.Drawing2D.GraphicsPath]::new()
    $path.AddArc($Rectangle.X, $Rectangle.Y, $Radius, $Radius, 180, 90)
    $path.AddArc($Rectangle.Right - $Radius, $Rectangle.Y, $Radius, $Radius, 270, 90)
    $path.AddArc($Rectangle.Right - $Radius, $Rectangle.Bottom - $Radius, $Radius, $Radius, 0, 90)
    $path.AddArc($Rectangle.X, $Rectangle.Bottom - $Radius, $Radius, $Radius, 90, 90)
    $path.CloseFigure()
    return $path
}

function New-Keycap {
    param(
        [string]$Name,
        [string]$Label,
        [int]$Width = 128,
        [int]$Height = 128
    )

    $bitmap = [System.Drawing.Bitmap]::new($Width, $Height, [System.Drawing.Imaging.PixelFormat]::Format32bppArgb)
    $graphics = [System.Drawing.Graphics]::FromImage($bitmap)
    $graphics.SmoothingMode = [System.Drawing.Drawing2D.SmoothingMode]::AntiAlias
    $graphics.TextRenderingHint = [System.Drawing.Text.TextRenderingHint]::AntiAliasGridFit

    $rectangle = [System.Drawing.RectangleF]::new(3, 3, $Width - 6, $Height - 6)
    $path = New-RoundedRectanglePath -Rectangle $rectangle -Radius 16
    $fill = [System.Drawing.SolidBrush]::new([System.Drawing.Color]::FromArgb(238, 8, 10, 14))
    $border = [System.Drawing.Pen]::new([System.Drawing.Color]::FromArgb(230, 202, 184, 132), 2)
    $innerBorder = [System.Drawing.Pen]::new([System.Drawing.Color]::FromArgb(100, 183, 118, 245), 1)

    $graphics.FillPath($fill, $path)
    $graphics.DrawPath($border, $path)
    $graphics.DrawRectangle($innerBorder, 10, 10, $Width - 20, $Height - 20)

    $fontSize = if ($Label.Length -gt 2) { [math]::Round($Height * 0.3) } else { [math]::Round($Height * 0.58) }
    $font = [System.Drawing.Font]::new('Arial', $fontSize, [System.Drawing.FontStyle]::Bold, [System.Drawing.GraphicsUnit]::Pixel)
    $textBrush = [System.Drawing.SolidBrush]::new([System.Drawing.Color]::FromArgb(255, 242, 235, 214))
    $format = [System.Drawing.StringFormat]::new()
    $format.Alignment = [System.Drawing.StringAlignment]::Center
    $format.LineAlignment = [System.Drawing.StringAlignment]::Center
    $graphics.DrawString($Label, $font, $textBrush, $rectangle, $format)

    $bitmap.Save((Join-Path $output $Name), [System.Drawing.Imaging.ImageFormat]::Png)
    $format.Dispose()
    $textBrush.Dispose()
    $font.Dispose()
    $innerBorder.Dispose()
    $border.Dispose()
    $fill.Dispose()
    $path.Dispose()
    $graphics.Dispose()
    $bitmap.Dispose()
}

New-Keycap -Name 'key-x.png' -Label 'X'
New-Keycap -Name 'key-h.png' -Label 'H'
New-Keycap -Name 'key-e.png' -Label 'E'
New-Keycap -Name 'key-q.png' -Label 'Q'
New-Keycap -Name 'key-r.png' -Label 'R'
New-Keycap -Name 'key-f.png' -Label 'F'
New-Keycap -Name 'key-space.png' -Label 'ESPACO' -Width 200 -Height 112
