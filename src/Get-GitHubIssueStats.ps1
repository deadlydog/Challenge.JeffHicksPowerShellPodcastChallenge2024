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
	[string] $gitHubRepoBaseUrl = "https://github.com/$RepositoryOwner/$RepositoryName"

	[PSCustomObject[]] $openIssues = Get-GitHubOpenIssues -owner $RepositoryOwner -repo $RepositoryName
	[hashtable] $labelsDictionary = Get-IssuesGroupedByLabel -issues $openIssues

	[int] $totalNumberOfOpenIssues = $openIssues.Count
	[PSCustomObject[]] $labelStats = Get-IssueStatsByLabel -labelsDictionary $labelsDictionary -totalNumberOfOpenIssues $totalNumberOfOpenIssues -baseRepoUrl $gitHubRepoBaseUrl

	Write-LabelStats -issueStats $labelStats -baseRepoUrl $gitHubRepoBaseUrl
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

	function Get-IssueStatsByLabel([hashtable] $labelsDictionary, [int] $totalNumberOfOpenIssues, [string] $baseRepoUrl)
	{
		[PSCustomObject[]] $labelStats = @()
		$labelsDictionary.GetEnumerator() | ForEach-Object {
			$label = $_
			$labelName = $label.Name
			$labelIssues = $label.Value

			$numberOfIssuesWithThisLabel = $labelIssues.Count
			$percentageOfIssuesWithThisLabel = [math]::Round(($numberOfIssuesWithThisLabel / $totalNumberOfOpenIssues) * 100, 2)

			$labelOpenIssuesUrl = [System.Uri]::EscapeUriString("$baseRepoUrl/issues?q=is:open+is:issue+label:$labelName")

			$stats = [PSCustomObject] @{
				LabelName = $labelName
				NumberOfIssuesWithThisLabel = $numberOfIssuesWithThisLabel
				PercentageOfIssuesWithThisLabel = $percentageOfIssuesWithThisLabel
				LabelOpenIssuesUrl = $labelOpenIssuesUrl
			}
			$labelStats += $stats
		}

		return $labelStats
	}

	function Write-LabelStats([PSCustomObject[]] $issueStats, [string] $baseRepoUrl)
	{
		Write-Output "The number of issues by label for the repository '$baseRepoUrl':"
		$issueStats | Format-Table -AutoSize
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
