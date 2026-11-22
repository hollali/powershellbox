# Argument completions for PowerShellBox helpers.
# Loaded by the profile, or on its own with: . ~/.local/share/powershellbox/completions.ps1

$gitBranchCompleter = {
    param($wordToComplete, $commandAst, $cursorPosition)
    @(git branch --format='%(refname:short)' 2>$null) |
        Where-Object { $_ -like "$wordToComplete*" } |
        ForEach-Object {
            [System.Management.Automation.CompletionResult]::new($_, $_, 'ParameterValue', "Branch: $_")
        }
}
Register-ArgumentCompleter -CommandName 'gco' -ParameterName 'branch' -ScriptBlock $gitBranchCompleter
Register-ArgumentCompleter -CommandName 'gb' -ScriptBlock $gitBranchCompleter

$portCompleter = {
    param($wordToComplete, $commandAst, $cursorPosition)
    if (Get-Command Get-PsbListeningConnections -ErrorAction SilentlyContinue) {
        $listening = @(Get-PsbListeningConnections)
    } elseif (Get-Command Get-NetTCPConnection -ErrorAction SilentlyContinue) {
        $listening = @(Get-NetTCPConnection -State Listen -ErrorAction SilentlyContinue)
    } else {
        return
    }
    @($listening | Select-Object -ExpandProperty LocalPort -Unique | Sort-Object) |
        Where-Object { "$_" -like "$wordToComplete*" } |
        ForEach-Object {
            [System.Management.Automation.CompletionResult]::new("$_", "$_", 'ParameterValue', "Listening port $_")
        }
}
Register-ArgumentCompleter -CommandName 'port' -ParameterName 'number' -ScriptBlock $portCompleter
Register-ArgumentCompleter -CommandName 'killport' -ParameterName 'number' -ScriptBlock $portCompleter

$fileCompleter = {
    param($wordToComplete, $commandAst, $cursorPosition)
    [System.Management.Automation.CompletionCompleters]::CompleteFilename($wordToComplete) |
        ForEach-Object {
            [System.Management.Automation.CompletionResult]::new($_.CompletionText, $_.ListItemText, 'ParameterValue', $_.ToolTip)
        }
}
Register-ArgumentCompleter -CommandName 'extract' -ParameterName 'file' -ScriptBlock $fileCompleter
Register-ArgumentCompleter -CommandName 'tbcompletion' -ParameterName 'Path' -ScriptBlock $fileCompleter
