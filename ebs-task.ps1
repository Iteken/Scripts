## run ebsjob powershell task sequence

import-module activedirectory
import-module sqlps
set-location c:\
. c:\ebs-includes.ps1
ebs-nightlyjob fix
