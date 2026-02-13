<#
.SYNOPSIS
    HTML Reporting Module
.DESCRIPTION
    Contains functions for generating HTML reports and tables.
#>

<#
.SYNOPSIS
    Generates an HTML table from an object.
#>
function Get-HtmlTable {
    [CmdletBinding()]
    param(
        [Parameter(Mandatory = $false)]
        $obj
    )

    if ($null -eq $obj) { return "<em>null</em>" }

    # Handle Error Strings directly
    if ($obj -is [string] -and $obj.StartsWith("Error:")) {
        $safeError = [System.Net.WebUtility]::HtmlEncode($obj)
        return "<div style='color: red; font-weight: bold;'>$safeError</div>"
    }

    # Array Handling
    if ($obj -is [array]) {
        if ($obj.Count -eq 0) { return "<em>Empty Array</em>" }
        
        $firstItem = $obj | Select-Object -First 1
        
        # Simple Array
        if ($firstItem -is [string] -or $firstItem -is [int] -or $firstItem -is [bool] -or $firstItem -is [datetime]) {
            $htmlContainer = "<table><tr><th>Value</th></tr>"
            foreach ($item in $obj) { 
                $safeItem = [System.Net.WebUtility]::HtmlEncode("$item")
                $htmlContainer += "<tr><td>$safeItem</td></tr>" 
            }
            $htmlContainer += "</table>"
            return $htmlContainer
        }
        
        # Object Array
        $properties = $firstItem | Get-Member -MemberType NoteProperty, Property
        if ($null -eq $properties) { return "<em>Complex Array</em>" }
        
        $htmlContainer = "<table><thead><tr>"
        foreach ($prop in $properties) {
            $safePropName = [System.Net.WebUtility]::HtmlEncode($prop.Name)
            $htmlContainer += "<th>$safePropName</th>"
        }
        $htmlContainer += "</tr></thead><tbody>"
        
        foreach ($item in $obj) {
            $htmlContainer += "<tr>"
            foreach ($prop in $properties) {
                $val = $item.($prop.Name)
                if ($val -is [array] -or $val -is [PSCustomObject] -or $val -is [hashtable]) {
                    # Recursive call for nested complex objects, but limit depth or simplify
                    $json = $val | ConvertTo-Json -Depth 1 -Compress
                    $safeJson = [System.Net.WebUtility]::HtmlEncode($json)
                    $htmlContainer += "<td><span title='$safeJson' class='complex-data'>[Complex Data]</span></td>"
                }
                else {
                    $safeVal = [System.Net.WebUtility]::HtmlEncode("$val")
                    $htmlContainer += "<td>$safeVal</td>"
                }
            }
            $htmlContainer += "</tr>"
        }
        $htmlContainer += "</tbody></table>"
        return $htmlContainer
    }
    
    # Single Object Handling
    if ($obj -is [PSCustomObject] -or $obj -is [hashtable]) {
        $properties = $obj | Get-Member -MemberType NoteProperty, Property
        if ($null -eq $properties) { return "<em>Empty Object</em>" }

        $htmlContainer = "<table><thead><tr><th>Property</th><th>Value</th></tr></thead><tbody>"
        foreach ($prop in $properties) {
            $name = $prop.Name
            $val = $obj.$name
            $safeName = [System.Net.WebUtility]::HtmlEncode($name)
            
            $displayValue = if ($val -is [array]) { 
                # Create a mini-list for arrays
                "<ul>" + ($val | ForEach-Object { "<li>$([System.Net.WebUtility]::HtmlEncode("$_"))</li>" }) + "</ul>"
            } 
            elseif ($val -is [PSCustomObject] -or $val -is [hashtable]) { 
                # Recursive call for nested objects
                Get-HtmlTable -obj $val
            } 
            else { 
                [System.Net.WebUtility]::HtmlEncode("$val")
            }
            
            $htmlContainer += "<tr><td><strong>$safeName</strong></td><td>$displayValue</td></tr>"
        }
        $htmlContainer += "</tbody></table>"
        return $htmlContainer
    }

    return [System.Net.WebUtility]::HtmlEncode("$obj")
}

<#
.SYNOPSIS
    Returns the HTML template string.
#>
function Get-HtmlTemplate {
    [CmdletBinding()]
    param()

    return @"
<!DOCTYPE html>
<html lang="en">
<head>
    <meta charset="UTF-8">
    <meta name="viewport" content="width=device-width, initial-scale=1.0">
    <title>System Information Report</title>
    <!-- Use Modern Sans-Serif Font -->
    <link href="https://fonts.googleapis.com/css2?family=Inter:wght@400;600;700&display=swap" rel="stylesheet">
    <style>
        :root {
            --primary: #2563eb;
            --primary-dark: #1e40af;
            --secondary: #64748b;
            --bg: #f8fafc;
            --card-bg: #ffffff;
            --text-main: #1e293b;
            --text-muted: #64748b;
            --border: #e2e8f0;
            --accent: #10b981;
        }

        body { 
            font-family: 'Inter', system-ui, -apple-system, sans-serif; 
            margin: 0; 
            padding: 40px; 
            background-color: var(--bg); 
            color: var(--text-main);
            line-height: 1.5;
        }

        .container { max-width: 1200px; margin: 0 auto; }

        .header {
            margin-bottom: 40px;
            padding-bottom: 20px;
            border-bottom: 2px solid var(--border);
        }

        h1 { font-size: 2.25rem; font-weight: 700; color: var(--text-main); margin-bottom: 8px; letter-spacing: -0.025em; }
        
        .timestamp { font-size: 0.875rem; color: var(--text-muted); font-weight: 500; }

        /* Collapsible Styling (Premium Dashboard Style) */
        .collapsible { 
            background-color: var(--card-bg); 
            color: var(--text-main); 
            cursor: pointer; 
            padding: 18px 24px; 
            width: 100%; 
            border: 1px solid var(--border); 
            text-align: left; 
            outline: none; 
            font-size: 1.1rem;
            font-weight: 600;
            margin-top: 12px;
            border-radius: 8px;
            display: flex;
            justify-content: space-between;
            align-items: center;
            transition: all 0.2s cubic-bezier(0.4, 0, 0.2, 1);
            box-shadow: 0 1px 2px rgba(0,0,0,0.05);
        }

        .collapsible:hover { background-color: #f1f5f9; border-color: var(--primary); }
        .active { border-color: var(--primary); border-bottom-left-radius: 0; border-bottom-right-radius: 0; background-color: #f1f5f9; }

        .collapsible:after { 
            content: '\002B'; 
            color: var(--secondary); 
            font-size: 1.5rem;
            transition: transform 0.2s ease;
        }
        .active:after { content: "\2212"; transform: rotate(180deg); }
        
        .content { 
            padding: 24px; 
            display: none; 
            background-color: var(--card-bg); 
            border: 1px solid var(--border);
            border-top: none;
            border-bottom-left-radius: 8px;
            border-bottom-right-radius: 8px;
            box-shadow: 0 4px 6px -1px rgba(0, 0, 0, 0.1);
        }
        
        table { border-collapse: separate; border-spacing: 0; width: 100%; margin: 10px 0; overflow: hidden; border-radius: 8px; border: 1px solid var(--border); }
        th, td { padding: 12px 16px; text-align: left; border-bottom: 1px solid var(--border); font-size: 0.925rem; }
        th { background-color: #f8fafc; font-weight: 600; color: var(--secondary); text-transform: uppercase; font-size: 0.75rem; letter-spacing: 0.05em; }
        tr:last-child td { border-bottom: none; }
        tr:hover td { background-color: #f8fafc; }
        
        .complex-data { color: var(--primary); font-weight: 500; text-decoration: underline dotted; cursor: help; }
        ul { margin: 0; padding-left: 20px; }
        li { margin-bottom: 4px; }

        .status-pill { padding: 2px 8px; border-radius: 12px; font-size: 0.75rem; font-weight: 600; }
        .status-ok { background-color: #d1fae5; color: #065f46; }
        .status-error { background-color: #fee2e2; color: #991b1b; }
    </style>
</head>
<body>
    <div class="container">
        <div class="header">
            <h1>System Information Report</h1>
            <div class="timestamp">Generated: $(Get-Date -Format 'yyyy-MM-dd HH:mm:ss K')</div>
            <div class="timestamp">Collector Engine: Antigravity v2.0 (Premium)</div>
        </div>
        <!-- BODY_PLACEHOLDER -->
    </div>

    <script>
        var coll = document.getElementsByClassName("collapsible");
        for (var i = 0; i < coll.length; i++) {
            coll[i].addEventListener("click", function() {
                this.classList.toggle("active");
                var content = this.nextElementSibling;
                content.style.display = (content.style.display === "block") ? "none" : "block";
            });
        }
    </script>
</body>
</html>
"@
}

<#
.SYNOPSIS
    Converts the audit report object to an HTML file.
#>
function ConvertTo-HtmlReport {
    [CmdletBinding(SupportsShouldProcess = $true)]
    param(
        [Parameter(Mandatory = $true)]
        $inputObject,
        
        [Parameter(Mandatory = $true)]
        [string]$outputPath
    )

    $htmlTemplate = Get-HtmlTemplate

    # Build Body
    $htmlBody = ""
    $categories = $inputObject | Get-Member -MemberType NoteProperty

    foreach ($cat in $categories) {
        if ($cat.Name -in @("Timestamp", "ExecutionTime")) { continue }
        $safeCatName = [System.Net.WebUtility]::HtmlEncode($cat.Name)

        # Main Category (H2) -> Collapsible Button
        $htmlBody += "<button type='button' class='collapsible'>$safeCatName</button>"
        $htmlBody += "<div class='content'>" # Start Main Content Div

        $categoryData = $inputObject.($cat.Name)

        if ($categoryData -is [PSCustomObject]) {
            $subCategories = $categoryData | Get-Member -MemberType NoteProperty
            foreach ($sub in $subCategories) {
                $safeSubName = [System.Net.WebUtility]::HtmlEncode($sub.Name)
                # Sub Category (H3) -> Collapsible Button
                $htmlBody += "<button type='button' class='collapsible' style='font-size: 1em; background-color: #fdfefe; border-left-color: #16a085;'>$safeSubName</button>"
                $htmlBody += "<div class='content'>" # Start Sub Content Div
                
                $subData = $categoryData.($sub.Name)
                $htmlBody += Get-HtmlTable -obj $subData
                
                $htmlBody += "</div>" # End Sub Content Div
            }
        }
        else {
            $htmlBody += Get-HtmlTable -obj $categoryData
        }
        
        $htmlBody += "</div>" # End Main Content Div
    }

    $finalHtml = $htmlTemplate.Replace("<!-- BODY_PLACEHOLDER -->", $htmlBody)
    
    if ($PSCmdlet.ShouldProcess($outputPath, "Save HTML Report")) {
        $finalHtml | Set-Content -Path $outputPath -Encoding UTF8
    }
}

# SIG # Begin signature block
# MIIFiwYJKoZIhvcNAQcCoIIFfDCCBXgCAQExCzAJBgUrDgMCGgUAMGkGCisGAQQB
# gjcCAQSgWzBZMDQGCisGAQQBgjcCAR4wJgIDAQAABBAfzDtgWUsITrck0sYpfvNR
# AgEAAgEAAgEAAgEAAgEAMCEwCQYFKw4DAhoFAAQUcXnuUJT2yPkAtq/SYFpktwN1
# LlugggMcMIIDGDCCAgCgAwIBAgIQGWEUqQpfT6JPYbwYRk6SXjANBgkqhkiG9w0B
# AQsFADAkMSIwIAYDVQQDDBlDb2xsZWN0b3ItSW50ZXJuYWwtU2lnbmVyMB4XDTI2
# MDIxMzE2MzExMloXDTI3MDIxMzE2NTExMlowJDEiMCAGA1UEAwwZQ29sbGVjdG9y
# LUludGVybmFsLVNpZ25lcjCCASIwDQYJKoZIhvcNAQEBBQADggEPADCCAQoCggEB
# ANvUNS+3ZOqv6/Wjx4K6mUvzpMqoAAToxWCryus4grdBQG7zH2M/2en1b750HzGs
# Xhr2macyH+9rVzsYHYF5llyxw08XQ6X36vMbJEVoR+5KOf/zJrA2c480Rdc2m1BH
# BDNkhKC7/P4pCaYYi+sxe68Ind6KYjIIL8wRMFRy77FZRiL3iUINYK3yMEnSrkfK
# DVtAM26Urogj/zfmozn05f3q9nk7wnlSAzBFgYrqZ0LAClDEiqrN5W2S2Tz465uN
# jkLiBJ3R+fJf6duLybme+A6uqmmVRTukL8/uUB19fJw7lx1OfmIBoJQ0p6myy8hS
# Wz/kgKl2drA3emG4e6BpckECAwEAAaNGMEQwDgYDVR0PAQH/BAQDAgeAMBMGA1Ud
# JQQMMAoGCCsGAQUFBwMDMB0GA1UdDgQWBBTAAzQigManKpFUSzB+/+hZM7g9AjAN
# BgkqhkiG9w0BAQsFAAOCAQEAA9jrmfv21FtuqvRvy4gz7aUuHI/o0dtaia/3QYKI
# Q04YkCTVMP63j/d2ISNM1Xwn8qnRBr93jO0hI+lpf9ELW2hnJwyaHqhJzQsBvBM6
# CowvqaPa+S9+9Hc7sY2aVGWcSXJwXcqy6pzkOHuzPouTk0hfsekRRivafQYH5Xeh
# Ui7+fQmPLrZmLQPOLx8mAMaLsPUYDAE8j99aa2ulg6KZYO7F0zy0Veqjs+8pSIIE
# V0H2+ApOKEbZP4NWUeaFq9vycZwURZPjYrNSckbJ5M9jTANbNaMs2ZAEZ+HrpPSt
# wvUWonVftmZpq3dJ2ClpXnDwUz/yYEJ1dzUT9YDZDDbOVzGCAdkwggHVAgEBMDgw
# JDEiMCAGA1UEAwwZQ29sbGVjdG9yLUludGVybmFsLVNpZ25lcgIQGWEUqQpfT6JP
# YbwYRk6SXjAJBgUrDgMCGgUAoHgwGAYKKwYBBAGCNwIBDDEKMAigAoAAoQKAADAZ
# BgkqhkiG9w0BCQMxDAYKKwYBBAGCNwIBBDAcBgorBgEEAYI3AgELMQ4wDAYKKwYB
# BAGCNwIBFTAjBgkqhkiG9w0BCQQxFgQUO5L7b7jzqbP7LYqijUIZdUqG15owDQYJ
# KoZIhvcNAQEBBQAEggEAkoGwIpOeGWG/YpwZHegxLRudw+Mzohvzir89/0Yk+Yz5
# PBeaPtia2SSlmzIn+KULCtwYoh8fEHgOaYs0jq0mW99be2HYiLEz9oh8aOLNmtCH
# U3QOuhFbHEDixMn7qjJJ6FaVpHYPKNWDArIHgeM7eKR4MygaHpEXG2qu5Yp1SybS
# BdHi4DuXaTEBBBPva5iI4oAefFj1A85/5ZUNHH2iaCazeLGG48dPAqhWJkIf2s/f
# tioqRHj/OSeL2LYcLc0PFd2wOY49jopTh15PKnXf+2cLt6+CgtHGVsYohIFb0/xS
# 1XoNIxz969mu5ZPYbAIA31eRBHeU1PJKKFXoHfiKiA==
# SIG # End signature block
