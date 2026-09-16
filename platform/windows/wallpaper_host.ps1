<#
    wallpaper_host.ps1 — prende ou solta a janela do jogo da camada de papel de parede.

    Faz parte de "Como Aumentar Seu Caramelo". Chamado apenas pelo proprio jogo, com uma
    lista de argumentos (sem shell, sem texto interpolado). O unico dado que entra e o
    identificador da janela, validado como inteiro positivo dos dois lados.

    O que ele faz:
      1. acha o Progman, o dono do desktop;
      2. pede a ele a camada WorkerW, que so existe depois desse pedido;
      3. reparenteia a janela do jogo para essa camada, atras dos icones;
      4. confirma o resultado.

    O que ele nunca faz: encerrar ou reiniciar o explorer.exe, ocultar icones, escrever no
    registro, trocar o papel de parede do sistema, pedir privilegio de administrador ou
    usar rede. Desfazer e uma chamada so, com -Action Detach.

    Saida: uma unica linha, "OK|detalhe" ou "ERR|motivo".
#>

param(
    [Parameter(Mandatory = $true)]
    [ValidateSet('Attach', 'Detach')]
    [string]$Action,

    [Parameter(Mandatory = $true)]
    [ValidateRange(1, [long]::MaxValue)]
    [long]$Handle
)

$ErrorActionPreference = 'Stop'

try {
    Add-Type -Namespace Caramelo -Name Native -MemberDefinition @'
[DllImport("user32.dll", SetLastError = true, CharSet = CharSet.Auto)]
public static extern IntPtr FindWindow(string lpClassName, string lpWindowName);

[DllImport("user32.dll", SetLastError = true)]
public static extern IntPtr FindWindowEx(IntPtr parent, IntPtr childAfter, string className, string windowName);

[DllImport("user32.dll", SetLastError = true)]
public static extern IntPtr SendMessageTimeout(IntPtr hWnd, uint msg, IntPtr wParam, IntPtr lParam, uint flags, uint timeout, out IntPtr result);

[DllImport("user32.dll", SetLastError = true)]
public static extern IntPtr SetParent(IntPtr hWndChild, IntPtr hWndNewParent);

[DllImport("user32.dll", SetLastError = true)]
public static extern bool IsWindow(IntPtr hWnd);

public delegate bool EnumWindowsProc(IntPtr hWnd, IntPtr lParam);

[DllImport("user32.dll", SetLastError = true)]
public static extern bool EnumWindows(EnumWindowsProc callback, IntPtr lParam);
'@
}
catch {
    Write-Output "ERR|nao foi possivel carregar as chamadas nativas: $($_.Exception.Message)"
    exit 1
}

$window = [IntPtr]::new($Handle)

if (-not [Caramelo.Native]::IsWindow($window)) {
    Write-Output 'ERR|a janela informada nao existe mais.'
    exit 1
}

if ($Action -eq 'Detach') {
    $restored = [Caramelo.Native]::SetParent($window, [IntPtr]::Zero)
    if ($restored -eq [IntPtr]::Zero) {
        Write-Output 'ERR|nao foi possivel devolver a janela ao desktop.'
        exit 1
    }
    Write-Output 'OK|desassociada'
    exit 0
}

# --- Attach ---------------------------------------------------------------------------

$progman = [Caramelo.Native]::FindWindow('Progman', $null)
if ($progman -eq [IntPtr]::Zero) {
    Write-Output 'ERR|Progman nao encontrado; o Explorer pode nao estar ativo.'
    exit 1
}

# 0x052C e a mensagem nao documentada que faz o Progman criar a camada WorkerW.
# Ela nao destroi nada: se a camada ja existir, o pedido e ignorado.
$unused = [IntPtr]::Zero
[void][Caramelo.Native]::SendMessageTimeout($progman, 0x052C, [IntPtr]::Zero, [IntPtr]::Zero, 0x0000, 1000, [ref]$unused)

# A camada certa e o WorkerW que **nao** tem o SHELLDLL_DefView como filho: o que tem e o
# painel dos icones, e entrar nele cobriria os icones do desktop.
$script:target = [IntPtr]::Zero
$callback = [Caramelo.Native+EnumWindowsProc] {
    param([IntPtr]$hWnd, [IntPtr]$lParam)
    $defView = [Caramelo.Native]::FindWindowEx($hWnd, [IntPtr]::Zero, 'SHELLDLL_DefView', $null)
    if ($defView -ne [IntPtr]::Zero) {
        $sibling = [Caramelo.Native]::FindWindowEx([IntPtr]::Zero, $hWnd, 'WorkerW', $null)
        if ($sibling -ne [IntPtr]::Zero) {
            $script:target = $sibling
        }
    }
    return $true
}
[void][Caramelo.Native]::EnumWindows($callback, [IntPtr]::Zero)

$host_window = $script:target
if ($host_window -eq [IntPtr]::Zero) {
    # Sem WorkerW utilizavel — acontece em algumas versoes do Windows. O Progman serve, e
    # os icones continuam visiveis porque o jogo entra como filho, nao por cima.
    $host_window = $progman
}

$previous = [Caramelo.Native]::SetParent($window, $host_window)
if ($previous -eq [IntPtr]::Zero -and $host_window -ne $progman) {
    Write-Output 'ERR|nao foi possivel prender a janela a camada de papel de parede.'
    exit 1
}

Write-Output ("OK|{0}" -f $host_window.ToInt64())
exit 0
