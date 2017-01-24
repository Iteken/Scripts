function DirOwner ($path, $action) {
## Check owner
## else set it
    if ( (Get-Owner -path $path.fullname).Owner.AccountName -like "*$($dir.name)") {
        write-output "$($dir.name) - Owner correct"
        }
    else {write-output "Owner for $($dir.name) is wrong." 
        if ($action -eq "fix") {
        ## fix if told to
            write-output "... Fixing."
            set-owner -path $dir.fullname -account "TOWERSTUDENTS\$($dir.name)"
            }
        } 
    }

function fixshare ($filepath) {
        $folders = get-childitem -Directory $filepath
        foreach ($folder in $folders) {
            dirowner $($folder) fix }
    }


