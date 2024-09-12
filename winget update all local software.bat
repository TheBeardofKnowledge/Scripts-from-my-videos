winget update --all --include-unknown --accept-source-agreements --accept-package-agreements --silent --verbose
PAUSE
::to exclude a package use
::winget pin add --name "Micron Storage Executive" --blocking
::to remove a package from pin use
::winget pin remove --name "Micron Storage Executive"