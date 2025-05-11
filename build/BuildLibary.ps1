$ErrorActionPreference = 'stop'

$zipUrl = 'https://arch-center.azureedge.net/icons/Azure_Public_Service_Icons_V21.zip'
$zipPath = 'Azure_Public_Service_Icons_V21.zip'
$destinationPath = './tmp/'

Invoke-WebRequest -Uri $zipUrl -OutFile $zipPath
Expand-Archive -Path $zipPath -DestinationPath $destinationPath -Force
Remove-Item $zipPath

$combinedOutput = @()

# Function to convert SVGs to mxlibrary format
function Convert-SvgToMxLibrary {
    param (
        [Parameter(Mandatory)]
        [string]$InputFolder,

        [Parameter(Mandatory)]
        [string]$OutputFile,

        [int]$GeometryWidth = 48,
        [int]$GeometryHeight = 48,

        [ref]$GlobalOutput
    )

    $output = @()

    Get-ChildItem -Path $InputFolder -Filter *.svg | ForEach-Object {
        $file = $_
        $svgContent = Get-Content -Path $file.FullName -Raw
        $bytes = [System.Text.Encoding]::UTF8.GetBytes($svgContent)
        $base64 = [Convert]::ToBase64String($bytes)
        $image = "data:image/svg+xml,$base64"

        $xml = @"
<mxGraphModel>
  <root>
    <mxCell id="0"/>
    <mxCell id="1" parent="0"/>
    <mxCell id="2" value="" style="shape=image;verticalLabelPosition=bottom;verticalAlign=top;imageAspect=0;aspect=fixed;image=$image" vertex="1" parent="1">
      <mxGeometry width="$GeometryWidth" height="$GeometryHeight" as="geometry"/>
    </mxCell>
  </root>
</mxGraphModel>
"@

        $flattenedXml = ($xml -replace '\s+', ' ').Trim()
        $flattenedXml = $flattenedXml -replace '>\s+<', '><'
        $escapedXml = $flattenedXml -replace '<', '&lt;' -replace '>', '&gt;'

        $title = "$($file.BaseName)"

        $entry = @{
            xml   = $escapedXml
            w     = $GeometryWidth
            h     = $GeometryHeight
            title = $title
        }

        $json = ($entry | ConvertTo-Json -Compress)
        $output += "  $json,"

        if ($GlobalOutput) {
            $GlobalOutput.Value += "  $json,"
        }
    }

    if ($output.Count -gt 0) {
        $output[-1] = $output[-1].TrimEnd(',')
    }

    $output = @("<mxlibrary>[") + $output + "]</mxlibrary>"
    $output -join "`n" | Set-Content -LiteralPath $OutputFile -Encoding UTF8
    Write-Host "Library saved to $OutputFile"
}

$rootFolder = './tmp/Azure_Public_Service_Icons/Icons'
$buildPath = './tmp/Azure_Public_Service_Icons'
$subFolders = Get-ChildItem -Path $rootFolder -Directory
$folderNumber = 1

foreach ($folder in $subFolders) {
    $prefix = $folderNumber.ToString("D3")
    $outputFile = "$buildPath/$prefix $($folder.Name).xml"
    Write-Host "Reading files in folder: $($folder.FullName)"

    Convert-SvgToMxLibrary -InputFolder $folder.FullName `
                           -OutputFile $outputFile `
                           -GlobalOutput ([ref]$combinedOutput)
    $folderNumber++
}

if ($combinedOutput.Count -gt 0) {
    $combinedOutput[-1] = $combinedOutput[-1].TrimEnd(',')
}
$combinedLibrary = @("<mxlibrary>[") + $combinedOutput + "]</mxlibrary>"
$combinedLibrary -join "`n" | Set-Content -LiteralPath "$buildPath/000 all azure public service icons.xml" -Encoding UTF8
Write-Host "Global library saved to 000 all azure public service icons.xml"