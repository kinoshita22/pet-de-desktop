<#
    autostart.ps1 — liga, desliga e consulta a inicializacao automatica no login.

    Faz parte de "Como Aumentar Seu Caramelo". A entrada e um **atalho na pasta Inicializar
    do usuario atual**: nada de registro, nada para toda a maquina, nada que peca
    privilegio de administrador. Remover o atalho a mao desliga o recurso.

    O jogo so chama este helper depois de uma acao explicita de quem joga. Ele nunca e
    chamado na abertura, nem durante os testes.

    Saida: uma unica linha, "OK|detalhe" ou "ERR|motivo".
    Para -Action Status, o detalhe e "enabled" ou "disabled".
#>

param(
    [Parameter(Mandatory = $true)]
    [ValidateSet('Enable', 'Disable', 'Status')]
    [string]$Action,

    [Parameter(Mandatory = $false)]
    [string]$Target = ''
)

$ErrorActionPreference = 'Stop'

$startup = [Environment]::GetFolderPath('Startup')
if ([string]::IsNullOrWhiteSpace($startup)) {
    Write-Output 'ERR|pasta Inicializar do usuario nao encontrada.'
    exit 1
}

$shortcut = Join-Path $startup 'Como Aumentar Seu Caramelo.lnk'

switch ($Action) {
    'Status' {
        if (Test-Path -LiteralPath $shortcut) {
            Write-Output 'OK|enabled'
        }
        else {
            Write-Output 'OK|disabled'
        }
        exit 0
    }

    'Disable' {
        if (Test-Path -LiteralPath $shortcut) {
            Remove-Item -LiteralPath $shortcut -Force
        }
        if (Test-Path -LiteralPath $shortcut) {
            Write-Output 'ERR|nao foi possivel remover o atalho de inicializacao.'
            exit 1
        }
        Write-Output 'OK|disabled'
        exit 0
    }

    'Enable' {
        if ([string]::IsNullOrWhiteSpace($Target) -or -not (Test-Path -LiteralPath $Target -PathType Leaf)) {
            Write-Output 'ERR|executavel do jogo nao encontrado; use a versao exportada.'
            exit 1
        }
        if ([System.IO.Path]::GetExtension($Target).ToLowerInvariant() -ne '.exe') {
            Write-Output 'ERR|o alvo do atalho precisa ser um executavel.'
            exit 1
        }
        try {
            $shell = New-Object -ComObject WScript.Shell
            $link = $shell.CreateShortcut($shortcut)
            $link.TargetPath = $Target
            $link.WorkingDirectory = Split-Path -Parent $Target
            $link.Description = 'Como Aumentar Seu Caramelo'
            $link.Save()
        }
        catch {
            Write-Output "ERR|nao foi possivel criar o atalho: $($_.Exception.Message)"
            exit 1
        }
        if (-not (Test-Path -LiteralPath $shortcut)) {
            Write-Output 'ERR|o atalho nao foi criado.'
            exit 1
        }
        Write-Output 'OK|enabled'
        exit 0
    }
}
