<#
.SYNOPSIS
  Construit une release Android avec un environnement explicite (A13).

.DESCRIPTION
  N'utilise que la clé de signature existante (android/key.properties).
  Ne crée, ne remplace et ne modifie aucun keystore.

.EXAMPLE
  ./tool/build_release.ps1                       # APK production
  ./tool/build_release.ps1 -Flavor staging       # APK staging
  ./tool/build_release.ps1 -Target appbundle     # AAB production
#>
param(
    [ValidateSet('production', 'staging')]
    [string]$Flavor = 'production',

    [ValidateSet('apk', 'appbundle')]
    [string]$Target = 'apk',

    # Facultatif : URL HTTPS publique remplaçant l'URL du flavor.
    [string]$ApiBaseUrl = '',

    [ValidateRange(0, 2147483647)]
    [int]$BuildNumber = 0
)

$ErrorActionPreference = 'Stop'
Set-Location (Join-Path $PSScriptRoot '..')

$defines = @("--dart-define=API_FLAVOR=$Flavor")
if ($ApiBaseUrl) {
    if (-not $ApiBaseUrl.StartsWith('https://')) {
        throw "ApiBaseUrl doit commencer par https://"
    }
    $defines += "--dart-define=API_BASE_URL=$ApiBaseUrl"
}
if ($BuildNumber -gt 0) { $defines += "--build-number=$BuildNumber" }

flutter build $Target --release @defines
if ($LASTEXITCODE -ne 0) { exit $LASTEXITCODE }
