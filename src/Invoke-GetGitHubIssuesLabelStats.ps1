# This is a helper script for easily invoking the Get-GitHubIssuesLabelStats.ps1 function.

# Import the function so we can invoke it.
. "$PSScriptRoot\Get-GitHubIssuesLabelStats.ps1"

# Define the parameter values to pass to the function.
$parameters = @{
	RepositoryOwner = 'PowerShell'
	RepositoryName = 'PowerShell'
	OutputMarkdownFilePath = "$PSScriptRoot\GitHubIssuesLabelStats.md"
	MaximumNumberOfLabelsToShow = 25
	WriteResultsTableToConsole = $true
	ShowMarkdownInBrowser = $true
}

# Invoke the function with using the given parameters.
Get-GitHubIssuesLabelStats @parameters -InformationAction Continue
