#Requires -Version 7
param(
    [Alias('Calculate')]
    [Parameter()]
    [switch]$Calc
)

if ($Calc)
{
    $files = Get-Childitem -Directory $PSScriptRoot -Exclude '.git' | Get-ChildItem -Exclude '*.sha*','*.md5','*.txt' -File -Recurse
    $hashes = @('MD5', 'SHA1', 'SHA256', 'SHA512')

    Write-Output "calculating checksums..."

    $checksums = [System.Collections.Concurrent.ConcurrentBag[psobject]]::new()
    $files | ForEach-Object -Parallel {
        $file = $_
        $short = $file.FullName.Replace($using:PSScriptRoot, '.').Replace('.\','').Replace('\','/')
        Write-Output "`e[32m>`e[24;39m $short `e[34m$hash`e[0m`e[0K`e[0F"
        $using:hashes | ForEach-Object {
            $hash = $_
            $cs = $using:checksums
            $fh = Get-FileHash -Path $file.FullName -Algorithm $hash
            $c = [PSCustomObject]@{
                Algorithm = $fh.Algorithm
                Hash = $fh.Hash
                Path = $fh.Path
                Short = $short
            }
            $cs.Add($c)
        }
    }
    $checksums = $checksums | Sort-Object -Property Path

    Write-Output "`e[0K`e[0Nwriting checksums files..."
    $hashes | ForEach-Object {
        $hash = $_
        $checksums | Where-Object { $_.Algorithm -eq $hash } | ForEach-Object { "$($_.Hash.ToLower())  $($_.Short)" } | Out-File "$PSScriptRoot\checksums.$($hash.ToLower())"
    }
}
else
{
    $errors = @{'MD5' = 0; 'SHA1' = 0; 'SHA256' = 0; 'SHA512' = 0}

    Get-ChildItem "$PSScriptRoot\checksums.*" | ForEach-Object {
        $algo = $_.Extension.Replace('.','').ToUpper()
        Get-Content $_.FullName | ForEach-Object -Parallel {
            $hash, $file = $_ -Split '  '
            $path = Join-Path $using:PSScriptRoot $file

            Write-Output "`e[32m✔`e[24;39m $file `e[34m$using:algo`e[0m`e[0K`e[0F"

            $newhash = Get-FileHash -Path $path -Algorithm $using:algo

            if ($newhash.Hash.ToLower() -ne $hash.ToLower())
            {
                ($using:errors).$using:algo = ($using:errors).$using:algo + 1

                Write-Output "`e[31m✖`e[0m $file `e[34m$using:algo`e[0m`e[0K`e[0N"
            }
        }
    }

    $errors = $errors.MD5 + $errors.SHA1 + $errors.SHA256 + $errors.SHA512
    if ($errors -gt 0)
    {
        Write-Output "`e[0K`e[0NWARNING: `e[$(if($errors -gt 0){31}else{32})m$errors`e[0m computed checksums did NOT match"
        exit 1
    }
}

exit


