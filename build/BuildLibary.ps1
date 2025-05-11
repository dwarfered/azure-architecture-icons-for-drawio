$ErrorActionPreference = 'stop'

$zipUrl = 'https://arch-center.azureedge.net/icons/Azure_Public_Service_Icons_V21.zip'
$zipPath = 'Azure_Public_Service_Icons_V21.zip'
$destinationPath = "./tmp/"

Invoke-WebRequest -Uri $zipUrl -OutFile $zipPath
Expand-Archive -Path $zipPath -DestinationPath $destinationPath -Force
Remove-Item $zipPath

function Convert-SvgToMxLibrary {
    param (
        [Parameter(Mandatory)]
        [string]$InputFolder,

        [Parameter(Mandatory)]
        [string]$OutputFile,

        [int]$GeometryWidth = 48,
        [int]$GeometryHeight = 48
    )

    $output = @()
    $output += "<mxlibrary>["

    Get-ChildItem -Path $InputFolder -Filter *.svg | ForEach-Object {
        $file = $_
        $svgContent = Get-Content -Path $file.FullName -Raw
        $encodedSvg = [System.Uri]::EscapeDataString($svgContent)
        $imageUri = "data:image/svg+xml,$encodedSvg"

        # Build mxCell XML
        $xml = @"
<mxGraphModel>
  <root>
    <mxCell id="0"/>
    <mxCell id="1" parent="0"/>
    <mxCell id="2" value="" style="shape=image;verticalLabelPosition=bottom;verticalAlign=top;imageAspect=0;aspect=fixed;image=$imageUri" vertex="1" parent="1">
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
    }

    if ($output.Count -gt 1) {
        $output[-1] = $output[-1].TrimEnd(',')
    }

    $output += "]</mxlibrary>"

    $output -join "`n" | Set-Content -LiteralPath $OutputFile -Encoding UTF8
    Write-Host "Library saved to $OutputFile"
}

$rootFolder = "./tmp/Azure_Public_Service_Icons/Icons"
$subFolders = Get-ChildItem -Path $rootFolder -Directory
$folderNumber = 1
$buildPath = './tmp/Azure_Public_Service_Icons'

foreach ($folder in $subFolders) {
    $prefix = $folderNumber.ToString("D3")
    Write-Host "Reading files in folder:  $($folder.FullName)"
    Convert-SvgToMxLibrary -InputFolder $folder.FullName -OutputFile "$buildPath/$prefix $($folder.Name).xml"
    $folderNumber++
}