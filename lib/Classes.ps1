# --- Architectural Foundation: Class Definitions ---

<#
.SYNOPSIS
    Base class for all collection providers. Ensuring interface consistency.
#>
class BaseCollector {
    [string]$Name
    [string]$Category
    [bool]$IsEnabled = $true

    BaseCollector([string]$name, [string]$category) {
        $this.Name = $name
        $this.Category = $category
    }

    # Abstract-like method (must be overridden)
    [PSObject] Collect() {
        throw "Method 'Collect' must be implemented in inherited class."
    }

    [void] LogStart() {
        Write-Log -message "[$($this.Name)] Starting collection phase..." -color Cyan -level Info
    }

    [void] LogEnd([long]$ms) {
        Write-Log -message "[$($this.Name)] Completed in $($ms)ms." -color Green -level Info
    }
}

# SIG # Begin signature block
# MIIFiwYJKoZIhvcNAQcCoIIFfDCCBXgCAQExCzAJBgUrDgMCGgUAMGkGCisGAQQB
# gjcCAQSgWzBZMDQGCisGAQQBgjcCAR4wJgIDAQAABBAfzDtgWUsITrck0sYpfvNR
# AgEAAgEAAgEAAgEAAgEAMCEwCQYFKw4DAhoFAAQU9EnW2zh/TgTPJFtp4XslBxhr
# ATWgggMcMIIDGDCCAgCgAwIBAgIQGWEUqQpfT6JPYbwYRk6SXjANBgkqhkiG9w0B
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
# BAGCNwIBFTAjBgkqhkiG9w0BCQQxFgQUlmt34wPQcFgQAa9Y/Rs6nYYXU+wwDQYJ
# KoZIhvcNAQEBBQAEggEAoqg+bkx22BWFhPCEDZdbXg3o1l/LptBr2TujqUOuRTl3
# FuNWT4w3Q717OSUWsADewUNAUsM/ULgiJSFB1gRc+8/7sGuBNEYOMRNqG7AKQUDk
# MrotR+1C7KZaroJrtJf/l9Skogd6uH1gPJf4uV58lKTk3fP5WYL9UEhYDozIXfI8
# v50lNwhQ95uXKtyLsDnsVs2KLZDhtdTUfXnri22HJ2lcBn9v57Dc4t8lVtU8m7Ac
# awJcbR51Mlk5IUa6/gSYXRDAAMY6Gk4EHXb75CGoEJ4ikVXRcSZR496KiPtwO1pX
# Z87ylszHsBXzkF6XCKY+7Q7lQiRIIT6c4e6E1eLRXQ==
# SIG # End signature block
