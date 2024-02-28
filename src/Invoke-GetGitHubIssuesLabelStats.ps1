# This is a helper script for easily invoking the Get-GitHubIssuesLabelStats function.

Write-Information "Importing the script so we can invoke the function."
. "$PSScriptRoot\Get-GitHubIssuesLabelStats.ps1"

# Define the parameter values to pass to the function.
[string] $markdownFilePath = "$PSScriptRoot\GitHubIssuesLabelStats.md"
$parameters = @{
	RepositoryOwner = 'PowerShell'
	RepositoryName = 'PowerShell'
	OutputMarkdownFilePath = $markdownFilePath
	MaximumNumberOfLabelsToShow = 25
}

Write-Information "Invoking the function with the given parameters."
$results = Get-GitHubIssuesLabelStats @parameters -InformationAction Continue

Write-Information "Opening the output markdown file in the default browser."
Show-Markdown -Path $markdownFilePath -UseBrowser

Write-Information "Writing the label stats to the console."
$results | Format-Table -AutoSize
