function Send-MailMessageByGraph {
    [CmdletBinding()]
    param (
        [parameter(Mandatory)]
        [string]$From,

        [parameter()]
        [string[]]$To,

        [parameter()]
        [string[]]$CC,

        [parameter()]
        [string[]]$BCC,

        [parameter(Mandatory)]
        [string]$Subject,

        [parameter(Mandatory)]
        [string]$Body,

        [parameter()]
        [string[]]$Attachment
    )

    if (!$To -and !$CC -and !$BCC) {
        SayError "At least one To, Cc, or Bcc recipient is required."
        return $null
    }

    function ConvertRecipientsToJSON {
        param(
            [Parameter(Mandatory)]
            [string[]]
            $Recipients
        )
        $jsonRecipients = @()
        $Recipients | ForEach-Object {
            $jsonRecipients += @{EmailAddress = @{Address = $_ } }
        }
        return $jsonRecipients
    }

    $mailBody = @{
        message = @{
            subject                = $Subject
            body                   = @{
                content     = $Body
                contentType = "HTML"
            }
            internetMessageHeaders = @(
                @{
                    name  = "X-Mailer"
                    value = "PsGraphMail by june.castillote@gmail.com"
                }
            )
            attachments            = @()
        }
    }

    # To recipients
    if ($To) {
        $mailBody.message += @{
            toRecipients = @(
                $(ConvertRecipientsToJSON $To)
            )
        }
    }

    # Cc recipients
    if ($CC) {
        $mailBody.message += @{
            ccRecipients = @(
                $(ConvertRecipientsToJSON $CC)
            )
        }
    }

    # BCC recipients
    if ($BCC) {
        $mailBody.message += @{
            bccRecipients = @(
                $(ConvertRecipientsToJSON $BCC)
            )
        }
    }

    if ($Attachment) {
        foreach ($file in $Attachment) {
            try {
                $filename = (Resolve-Path $file -ErrorAction STOP).Path

                if ($PSVersionTable.PSEdition -eq 'Core') {
                    $fileByte = $([convert]::ToBase64String((Get-Content $filename -AsByteStream)))
                }
                else {
                    $fileByte = $([convert]::ToBase64String((Get-Content $filename -Raw -Encoding byte)))
                }

                $mailBody.message.attachments += @{
                    "@odata.type"  = "#microsoft.graph.fileAttachment"
                    "name"         = $(Split-Path $filename -Leaf)
                    "contentBytes" = $fileByte
                }
            }
            catch {
                "Attachment: $($_.Exception.Message)" | Out-Default
            }
        }
    }

    try {
        Send-MgUserMail -UserId $From -BodyParameter $mailBody -ErrorAction Stop
    }
    catch {
        SayError "Send email failed: $($_.Exception.Message)"
    }
}