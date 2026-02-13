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
    param($Obj)

    if ($null -eq $Obj) { return "<em>null</em>" }

    # Handle Error Strings directly
    if ($Obj -is [String] -and $Obj.StartsWith("Error:")) {
        $safeError = [System.Net.WebUtility]::HtmlEncode($Obj)
        return "<div style='color: red; font-weight: bold;'>$safeError</div>"
    }

    # Array Handling
    if ($Obj -is [Array]) {
        if ($Obj.Count -eq 0) { return "<em>Empty Array</em>" }
        
        $firstItem = $Obj | Select-Object -First 1
        
        # Simple Array
        if ($firstItem -is [String] -or $firstItem -is [Int] -or $firstItem -is [Boolean] -or $firstItem -is [DateTime]) {
            $html = "<table><tr><th>Value</th></tr>"
            foreach ($item in $Obj) { 
                $safeItem = [System.Net.WebUtility]::HtmlEncode("$item")
                $html += "<tr><td>$safeItem</td></tr>" 
            }
            $html += "</table>"
            return $html
        }
        
        # Object Array
        $props = $firstItem | Get-Member -MemberType NoteProperty, Property
        if ($null -eq $props) { return "<em>Complex Array</em>" }
        
        $html = "<table><thead><tr>"
        foreach ($prop in $props) { $html += "<th>$($prop.Name)</th>" }
        $html += "</tr></thead><tbody>"
        
        foreach ($item in $Obj) {
            $html += "<tr>"
            foreach ($prop in $props) {
                $val = $item.($prop.Name)
                if ($val -is [Array] -or $val -is [PSCustomObject] -or $val -is [Hashtable]) {
                    # Recursive call for nested complex objects, but limit depth or simplify
                    $json = $val | ConvertTo-Json -Depth 1 -Compress
                    $safeJson = [System.Net.WebUtility]::HtmlEncode($json)
                    $html += "<td><span title='$safeJson' class='complex-data'>[Complex Data]</span></td>"
                }
                else {
                    $safeVal = [System.Net.WebUtility]::HtmlEncode("$val")
                    $html += "<td>$safeVal</td>"
                }
            }
            $html += "</tr>"
        }
        $html += "</tbody></table>"
        return $html
    }
    
    # Single Object Handling
    if ($Obj -is [PSCustomObject] -or $Obj -is [Hashtable]) {
        $props = $Obj | Get-Member -MemberType NoteProperty, Property
        if ($null -eq $props) { return "<em>Empty Object</em>" }

        $html = "<table><thead><tr><th>Property</th><th>Value</th></tr></thead><tbody>"
        foreach ($prop in $props) {
            $name = $prop.Name
            $val = $Obj.$name
            
            $displayVal = if ($val -is [Array]) { 
                # Create a mini-list for arrays
                "<ul>" + ($val | ForEach-Object { "<li>$([System.Net.WebUtility]::HtmlEncode("$_"))</li>" }) + "</ul>"
            } 
            elseif ($val -is [PSCustomObject] -or $val -is [Hashtable]) { 
                # Recursive call for nested objects
                Get-HtmlTable -Obj $val
            } 
            else { 
                [System.Net.WebUtility]::HtmlEncode("$val")
            }
            
            $html += "<tr><td><strong>$name</strong></td><td>$displayVal</td></tr>"
        }
        $html += "</tbody></table>"
        return $html
    }

    return [System.Net.WebUtility]::HtmlEncode("$Obj")
}

<#
    .SYNOPSIS
        Returns the HTML template string.
    #>
function Get-HtmlTemplate {
    return @"
<!DOCTYPE html>
<html lang="en">
<head>
    <meta charset="UTF-8">
    <meta name="viewport" content="width=device-width, initial-scale=1.0">
    <title>System Information Report</title>
    <style>
        body { font-family: 'Segoe UI', Tahoma, Geneva, Verdana, sans-serif; margin: 20px; background-color: #f4f4f4; color: #333; }
        h1 { color: #2c3e50; border-bottom: 2px solid #3498db; padding-bottom: 10px; }
        
        /* Collapsible Styling */
        .collapsible { 
            background-color: #e8f6f3; 
            color: #2980b9; 
            cursor: pointer; 
            padding: 10px; 
            width: 100%; 
            border: none; 
            text-align: left; 
            outline: none; 
            font-size: 1.2em;
            font-weight: bold;
            margin-top: 10px;
            border-left: 5px solid #3498db;
        }
        .active, .collapsible:hover { background-color: #d4e6f1; }
        .collapsible:after { content: '\002B'; color: #2980b9; font-weight: bold; float: right; margin-left: 5px; }
        .active:after { content: "\2212"; }
        
        .content { 
            padding: 0 18px; 
            display: none; 
            overflow: hidden; 
            background-color: #fff; 
            margin-bottom: 10px;
            border: 1px solid #ddd;
            border-top: none;
        }
        
        h3 { color: #16a085; margin-top: 20px; cursor: pointer; }
        table { border-collapse: collapse; width: 100%; margin: 10px 0; background-color: #fff; box-shadow: 0 1px 3px rgba(0,0,0,0.1); }
        th, td { border: 1px solid #ddd; padding: 12px; text-align: left; font-size: 14px; }
        th { background-color: #34495e; color: white; font-weight: 600; }
        tr:nth-child(even) { background-color: #f9f9f9; }
        tr:hover { background-color: #f1f1f1; }
        .timestamp { font-size: 0.9em; color: #7f8c8d; margin-bottom: 20px; }
        .complex-data { font-style: italic; color: #7f8c8d; cursor: help; }
        ul { margin: 0; padding-left: 20px; }
    </style>
</head>
<body>
    <h1>System Information Report</h1>
    <div class="timestamp">Generated: $(Get-Date)</div>
    <!-- BODY_PLACEHOLDER -->

    <script>
        var coll = document.getElementsByClassName("collapsible");
        var i;

        for (i = 0; i < coll.length; i++) {
            coll[i].addEventListener("click", function() {
                this.classList.toggle("active");
                var content = this.nextElementSibling;
                if (content.style.display === "block") {
                    content.style.display = "none";
                } else {
                    content.style.display = "block";
                }
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
    param($InputObject, $OutputPath)

    $htmlTemplate = Get-HtmlTemplate

    # Build Body
    $htmlBody = ""
    $categories = $InputObject | Get-Member -MemberType NoteProperty

    foreach ($cat in $categories) {
        if ($cat.Name -in @("Timestamp", "ExecutionTime")) { continue }

        # Main Category (H2) -> Collapsible Button
        $htmlBody += "<button type='button' class='collapsible'>$($cat.Name)</button>"
        $htmlBody += "<div class='content'>" # Start Main Content Div

        $catData = $InputObject.($cat.Name)

        if ($catData -is [PSCustomObject]) {
            $subCats = $catData | Get-Member -MemberType NoteProperty
            foreach ($sub in $subCats) {
                # Sub Category (H3) -> Collapsible Button
                $htmlBody += "<button type='button' class='collapsible' style='font-size: 1em; background-color: #fdfefe; border-left-color: #16a085;'>$($sub.Name)</button>"
                $htmlBody += "<div class='content'>" # Start Sub Content Div
                
                $subData = $catData.($sub.Name)
                $htmlBody += Get-HtmlTable -Obj $subData
                
                $htmlBody += "</div>" # End Sub Content Div
            }
        }
        else {
            $htmlBody += Get-HtmlTable -Obj $catData
        }
        
        $htmlBody += "</div>" # End Main Content Div
    }

    $finalHtml = $htmlTemplate.Replace("<!-- BODY_PLACEHOLDER -->", $htmlBody)
    $finalHtml | Set-Content -Path $OutputPath -Encoding UTF8
}
