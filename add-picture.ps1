param (
    [string]$payrollid,
    [string]$userid )

Import-RecipientDataProperty -identity $($userid) -picture -filedata ([Byte[]]$(get-content -path "N:\Human Resources\Staff_Photos\10kb_import\$($payrollid).jpg" -encoding Byte -Readcount 0))


