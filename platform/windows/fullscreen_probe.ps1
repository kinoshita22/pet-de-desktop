<#
    fullscreen_probe.ps1 — ha um aplicativo alheio ocupando a tela inteira?

    Faz parte de "Como Aumentar Seu Caramelo". Serve so para o jogo decidir se reduz o
    processamento. Nao le titulo, nao lista processos, nao guarda nada e nao envia nada.

    A resposta compara o retangulo da janela em primeiro plano com o monitor onde ela
    esta. O desktop em si (Progman/WorkerW) nao conta como tela cheia.

    Saida: "OK|yes", "OK|no" ou "OK|unknown".
#>

param(
    [Parameter(Mandatory = $true)]
    [ValidateSet('Probe')]
    [string]$Action
)

$ErrorActionPreference = 'Stop'

try {
    Add-Type -AssemblyName System.Windows.Forms
    Add-Type -Namespace Caramelo -Name Probe -MemberDefinition @'
[DllImport("user32.dll")]
public static extern IntPtr GetForegroundWindow();

[StructLayout(LayoutKind.Sequential)]
public struct RECT { public int Left; public int Top; public int Right; public int Bottom; }

[DllImport("user32.dll")]
public static extern bool GetWindowRect(IntPtr hWnd, out RECT rect);

[DllImport("user32.dll", CharSet = CharSet.Auto)]
public static extern int GetClassName(IntPtr hWnd, System.Text.StringBuilder name, int count);
'@
}
catch {
    Write-Output 'OK|unknown'
    exit 0
}

$foreground = [Caramelo.Probe]::GetForegroundWindow()
if ($foreground -eq [IntPtr]::Zero) {
    Write-Output 'OK|unknown'
    exit 0
}

$builder = New-Object System.Text.StringBuilder 256
[void][Caramelo.Probe]::GetClassName($foreground, $builder, $builder.Capacity)
$className = $builder.ToString()
if ($className -eq 'Progman' -or $className -eq 'WorkerW') {
    # O proprio desktop em primeiro plano: nada cobrindo a tela.
    Write-Output 'OK|no'
    exit 0
}

$rect = New-Object Caramelo.Probe+RECT
if (-not [Caramelo.Probe]::GetWindowRect($foreground, [ref]$rect)) {
    Write-Output 'OK|unknown'
    exit 0
}

$bounds = [System.Windows.Forms.Screen]::FromHandle($foreground).Bounds
$width = $rect.Right - $rect.Left
$height = $rect.Bottom - $rect.Top

if ($width -ge $bounds.Width -and $height -ge $bounds.Height) {
    Write-Output 'OK|yes'
}
else {
    Write-Output 'OK|no'
}
exit 0
