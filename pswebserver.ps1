[CmdletBinding()]
param (
    [Parameter(Mandatory = $false)]
    [string] $ListenPrefix = 'http://localhost:8765/'
)

function HandleGetRequest
{
    param (
        [Parameter(Mandatory = $true)]
        [Net.HttpListenerContext] $Context
    )

    $isExitRequested = $false

    switch ($Context.Request.RawUrl) {
        '/' {
            FillResponse -Response $Context.Response -ResponseBody 'It works'
        }
        '/$$$' {
            Write-Verbose -Message 'Exit'
            $isExitRequested = $true
        }
        Default {
            # TODO: File
            # $content = Get-Content -Raw -LiteralPath 'C:\temp\index.html'
            FillResponse -Response $Context.Response -ResponseBody 'Not found' -StatusCode NotFound
        }
    }

    $isExitRequested
}

function HandlePostRequest
{
    param (
        [Parameter(Mandatory = $true)]
        [Net.HttpListenerContext] $Context
    )

    $isExitRequested = $false

    switch ($Context.Request.RawUrl) {
        '/post' {
            try {
                $reader = [IO.StreamReader]::new($Context.Request.InputStream)
                $requestBody = $reader.ReadToEnd()
            }
            finally {
                $reader.Dispose()
            }
            Write-Verbose -Message ('Request body: {0}' -f $requestBody)
            FillResponse -Response $Context.Response -ResponseBody 'POST data received.'
        }
        Default {
            FillResponse -Response $Context.Response -ResponseBody 'Not found' -StatusCode NotFound
        }
    }

    $isExitRequested
}

function FillResponse
{
    param (
        [Parameter(Mandatory = $true)]
        [Net.HttpListenerResponse] $Response,

        [Parameter(Mandatory = $true)]
        [string] $ResponseBody,

        [Parameter(Mandatory = $false)]
        [Net.HttpStatusCode] $StatusCode = [Net.HttpStatusCode]::OK,

        [Parameter(Mandatory = $false)]
        [string] $ContentType = 'text/plain'  # [System.Web.MimeMapping]::GetMimeMapping()
    )

    $responseBytes = [Text.Encoding]::UTF8.GetBytes($ResponseBody)
    $Response.ContentLength64 = $responseBytes.Length
    $Response.OutputStream.Write($responseBytes, 0, $responseBytes.Length)
    $Response.OutputStream.Close()
    $Response.ContentType = $ContentType
}

try {
    $listener = [Net.HttpListener]::new()
    $listener.Prefixes.Add($ListenPrefix)
    $listener.Start()
    if ($listener.IsListening) {
        Write-Verbose -Message ('Listen on {0}' -f $ListenPrefix)
    }

    # Request handling loop
    while ($listener.IsListening) {
        $context = $listener.GetContext()
        Write-Verbose -Message ("{0}: {1} - {2} => {3}" -f $context.Request.HttpMethod, $context.Request.RawUrl, $Context.Request.UserHostAddress, $Context.Request.Url)
        if ($context.Request.HttpMethod -eq 'GET') {
            if (HandleGetRequest -context $context) { break }
        }
        elseif ($context.Request.HttpMethod -eq 'POST') {
            if (HandlePostRequest -context $context) { break }
        }
    }
}
finally {
    $listener.Dispose()
}
