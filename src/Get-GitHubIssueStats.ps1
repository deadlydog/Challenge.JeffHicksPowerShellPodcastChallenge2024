[CmdletBinding()]
Param
(
	[Parameter(Mandatory = $false, HelpMessage = 'The owner of the repository to query. e.g. PowerShell.')]
	[ValidateNotNullOrEmpty()]
	[string] $RepositoryOwner = 'PowerShell',

	[Parameter(Mandatory = $false, HelpMessage = 'The name of the repository to query. e.g. PowerShell.')]
	[ValidateNotNullOrEmpty()]
	[string] $RepositoryName = 'PowerShell'
)

Process
{
	[PSCustomObject[]] $openIssues = Get-GitHubOpenIssues -owner $RepositoryOwner -repo $RepositoryName
	[hashtable] $labelsDictionary = Get-IssuesGroupedByLabel -issues $openIssues

	[int] $totalNumberOfOpenIssues = $openIssues.Count
	Write-IssueStatsPerLabel -labelsDictionary $labelsDictionary -totalNumberOfOpenIssues $totalNumberOfOpenIssues
}

Begin
{
	$InformationPreference = 'Continue'

	function Get-GitHubOpenIssues([string] $owner, [string] $repo)
	{
		[string] $uri = "https://api.github.com/repos/$owner/$repo/issues?state=open"
		[hashtable] $headers = @{
			'Accept' = 'application/json'
		}

		$response = Invoke-RestMethod -Uri $uri -Headers $headers
		return $response
	}

	function Get-IssuesGroupedByLabel([PSCustomObject[]] $issues)
	{
		[hashtable] $labelsDictionary = @{}
		$issues | ForEach-Object {
			$issue = $_
			$issue.labels | ForEach-Object {
				$label = $_
				$labelInfo = @{
					IssueNumber = $issue.number
					IssueTitle = $issue.title
					IssueUrl = $issue.html_url
					Label = $label.name
					LabelUrl = $label.url
				}
				$labelsDictionary[$label.name] += @($labelInfo)
			}
		}

		return $labelsDictionary
	}

	function Write-IssueStatsPerLabel([hashtable] $labelsDictionary, [int] $totalNumberOfOpenIssues)
	{
		$labelsDictionary.GetEnumerator() | ForEach-Object {
			$label = $_
			$labelName = $label.Name
			$labelIssues = $label.Value

			$numberOfIssuesWithThisLabel = $labelIssues.Count
			$percentageOfIssuesWithThisLabel = [math]::Round(($numberOfIssuesWithThisLabel / $totalNumberOfOpenIssues) * 100, 2)

			Write-Output "Label: $labelName, Number of Issues: $numberOfIssuesWithThisLabel, Percentage of Total: $percentageOfIssuesWithThisLabel%"
		}
	}

	# Display the time that this script started running.
	[DateTime] $startTime = Get-Date
	Write-Verbose "Starting script at '$startTime'."
}

End
{
	# Display the time that this script finished running, and how long it took to run.
	[DateTime] $finishTime = Get-Date
	[TimeSpan] $elapsedTime = $finishTime - $startTime
	Write-Verbose "Finished script at '$finishTime'. Took '$elapsedTime' to run."
}
