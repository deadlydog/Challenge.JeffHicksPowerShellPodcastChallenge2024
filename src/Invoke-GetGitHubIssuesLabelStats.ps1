# This is a helper script for easily invoking the Get-GitHubIssuesLabelStats.ps1 script.

# Define the parameter values to pass to the script.
$parameters = @{
	RepositoryOwner = 'PowerShell'
	RepositoryName = 'PowerShell'
	OutputMarkdownFilePath = "$PSScriptRoot\GitHubIssuesLabelStats.md"
	MaximumNumberOfLabelsToShow = 25
	ShowMarkdownInBrowser = $true
}

# Invoke the script with the parameters.
. "$PSScriptRoot\Get-GitHubIssuesLabelStats.ps1" @parameters
