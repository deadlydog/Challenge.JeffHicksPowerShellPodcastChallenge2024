[CmdletBinding()]
Param
(
	[Parameter(Mandatory = $true, HelpMessage = 'The owner of the GitHub repository to query. e.g. deadlydog.')]
	[ValidateNotNullOrEmpty()]
	[string] $RepositoryOwner = 'PowerShell',

	[Parameter(Mandatory = $true, HelpMessage = 'The name of the GitHub repository to query. e.g. PowerShell.tiPS')]
	[ValidateNotNullOrEmpty()]
	[string] $RepositoryName = 'PowerShell',

	[Parameter(Mandatory = $false, HelpMessage = 'The path to the output markdown file to create. If not specified, GitHubIssueLabelStats.md will be created in the same directory as this script.')]
	[string] $OutputMarkdownFilePath = "$PSScriptRoot\GitHubIssuesLabelStats.md",

	[Parameter(Mandatory = $false, HelpMessage = 'The maximum number of labels to show in the output markdown file. Default value is 25.')]
	[ValidateRange(1, 999999)]
	[int] $MaximumNumberOfLabelsToShow = 25,

	[Parameter(Mandatory = $false, HelpMessage = 'If specified, the output markdown file will be opened in the default browser.')]
	[switch] $ShowMarkdownInBrowser
)

Process
{
	[string] $gitHubRepoBaseUrl = "https://github.com/$RepositoryOwner/$RepositoryName"
	Test-GitHubRepository -repoUrl $gitHubRepoBaseUrl

	[PSCustomObject[]] $openIssues = Get-GitHubReposOpenIssues -owner $RepositoryOwner -repo $RepositoryName
	[hashtable] $labelsDictionary = Get-IssuesGroupedByLabel -issues $openIssues

	[int] $totalNumberOfOpenIssues = $openIssues.Count
	[PSCustomObject[]] $labelStats = Get-IssueStatsByLabel -labelsDictionary $labelsDictionary -totalNumberOfOpenIssues $totalNumberOfOpenIssues -baseRepoUrl $gitHubRepoBaseUrl

	Write-LabelStatsToMarkdownFile -labelStats $labelStats -baseRepoUrl $gitHubRepoBaseUrl -markdownFilePath $OutputMarkdownFilePath -maximumLabelsToShow $MaximumNumberOfLabelsToShow

	Write-Output "The open issues label stats have been written to '$OutputMarkdownFilePath'."

	if ($ShowMarkdownInBrowser)
	{
		Show-Markdown -Path $OutputMarkdownFilePath -UseBrowser
	}
}

Begin
{
	$InformationPreference = 'Continue'

	function Test-GitHubRepository([string] $repoUrl)
	{
		$response = Invoke-WebRequest -Uri $repoUrl -UseBasicParsing
		if ($response.StatusCode -ne 200)
		{
			throw "The GitHub repository at '$repoUrl' could not be found or we do not have permission to access it. Please check the owner and repository name and try again."
		}
	}

	function Get-GitHubReposOpenIssues([string] $owner, [string] $repo)
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

		[PSCustomObject[]] $orderedLabelStats = $labelStats | Sort-Object -Property NumberOfIssuesWithThisLabel -Descending
		return $orderedLabelStats
	}

	function Write-LabelStatsToMarkdownFile([PSCustomObject[]] $labelStats, [string] $baseRepoUrl, [string] $markdownFilePath, [int] $maximumLabelsToShow)
	{
		[System.Text.StringBuilder] $stringBuilder = [System.Text.StringBuilder]::new()
		$stringBuilder.AppendLine("# Open Issues Stats For $RepositoryOwner/$RepositoryName") > $null
		$stringBuilder.AppendLine() > $null
		$stringBuilder.AppendLine("Repository: [$RepositoryOwner/$RepositoryName]($baseRepoUrl)") > $null
		$stringBuilder.AppendLine() > $null
		$stringBuilder.AppendLine("Total number of open issues: $totalNumberOfOpenIssues") > $null
		$stringBuilder.AppendLine() > $null
		$stringBuilder.AppendLine("## Open Issues By Label") > $null
		$stringBuilder.AppendLine() > $null

		$stringBuilder.AppendLine("| Label | Number of Open Issues | Percentage of Open Issues | Open Issues URL |") > $null
		$stringBuilder.AppendLine("| ----- | --------------------- | ------------------------- | --------------- |") > $null
		[int] $numberOfLabelsShown = 0
		foreach ($labelStat in $labelStats)
		{
			$stringBuilder.AppendLine("| $($labelStat.LabelName) | $($labelStat.NumberOfIssuesWithThisLabel) | $($labelStat.PercentageOfIssuesWithThisLabel)% | [Label's Open Issues]($($labelStat.LabelOpenIssuesUrl)) |") > $null

			# Make sure we don't show more labels than the maximum number specified.
			$numberOfLabelsShown++
			if ($numberOfLabelsShown -ge $maximumLabelsToShow)
			{
				break
			}
		}

		Out-File -FilePath $markdownFilePath -InputObject $stringBuilder.ToString() -Force -NoNewline
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
