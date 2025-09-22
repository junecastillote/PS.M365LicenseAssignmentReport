$Path = [System.IO.Path]::Combine($PSScriptRoot, 'source')
(Get-ChildItem $Path -Filter *.ps1 -Recurse -File).FullName | ForEach-Object {
    . $_
}