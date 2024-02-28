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
	Write-Information "Ensuring the GitHub repository '$gitHubRepoBaseUrl' is valid and we have access to it..."
	Test-GitHubRepository -repoUrl $gitHubRepoBaseUrl

	Write-Information "Retrieving all open GitHub issues for the repo..."
	[PSCustomObject[]] $openIssues = Get-GitHubReposOpenIssues -owner $RepositoryOwner -repo $RepositoryName

	Write-Information "Grouping the open issues by label..."
	[hashtable] $labelsDictionary = Get-IssuesGroupedByLabel -issues $openIssues

	Write-Information "Calculating the label stats..."
	[hashtable] $getLabelsParams = @{
		labelsDictionary = $labelsDictionary
		totalNumberOfOpenIssues = $openIssues.Count
		baseRepoUrl = $gitHubRepoBaseUrl
	}
	[PSCustomObject[]] $labelStats = Get-IssueStatsByLabel @getLabelsParams

	Write-Information "Writing the label stats to the markdown file..."
	[hashtable] $writeLabelsParams = @{
		labelStats = $labelStats
		baseRepoUrl = $gitHubRepoBaseUrl
		markdownFilePath = $OutputMarkdownFilePath
		maxLabelsToShow = $MaximumNumberOfLabelsToShow
	}
	Write-LabelStatsToMarkdownFile @writeLabelsParams

	if ($ShowMarkdownInBrowser)
	{
		Write-Information "Opening the output markdown file in the default browser..."
		Show-Markdown -Path $OutputMarkdownFilePath -UseBrowser
	}

	Write-Output "The open issues label stats for '$gitHubRepoBaseUrl' have been written to '$OutputMarkdownFilePath'."
}

Begin
{
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
		[string] $uri = "https://api.github.com/repos/$owner/$repo/issues?state=open&per_page=100"
		[hashtable] $headers = @{
			'Accept' = 'application/json'
		}

		[PSCustomObject[]] $results = @()
		do
		{
			$response = Invoke-WebRequest -Uri $uri -Headers $headers
			$results += $response.Content | ConvertFrom-Json -Depth 99

			[string] $uri = $response.RelationLink['next']
			[bool] $hasNextPage = -Not [string]::IsNullOrWhiteSpace($uri)
		} while ($hasNextPage)

		return $results
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

	function Write-LabelStatsToMarkdownFile([PSCustomObject[]] $labelStats, [string] $baseRepoUrl, [string] $markdownFilePath, [int] $maxLabelsToShow)
	{
		[int] $numberOfLabels = $labelStats.Count

		[System.Text.StringBuilder] $stringBuilder = [System.Text.StringBuilder]::new()
		$stringBuilder.AppendLine("# Open Issues Label Stats For $RepositoryOwner/$RepositoryName") > $null
		$stringBuilder.AppendLine() > $null
		$stringBuilder.AppendLine("Repository: [$RepositoryOwner/$RepositoryName]($baseRepoUrl)") > $null
		$stringBuilder.AppendLine() > $null
		$stringBuilder.AppendLine("Total number of open issues: $totalNumberOfOpenIssues") > $null
		$stringBuilder.AppendLine() > $null
		$stringBuilder.AppendLine("Total number of labels: $numberOfLabels") > $null
		$stringBuilder.AppendLine() > $null
		$stringBuilder.AppendLine("## Open Issues By Label") > $null
		$stringBuilder.AppendLine() > $null

		if ($numberOfLabels -gt $maxLabelsToShow)
		{
			$stringBuilder.AppendLine("Note: Only the top $maxLabelsToShow labels are shown here.") > $null
			$stringBuilder.AppendLine() > $null
		}

		$stringBuilder.AppendLine("| Label | Number of Open Issues | Percentage of Open Issues | Open Issues URL |") > $null
		$stringBuilder.AppendLine("| ----- | --------------------- | ------------------------- | --------------- |") > $null
		[int] $numberOfLabelsShown = 0
		foreach ($labelStat in $labelStats)
		{
			$stringBuilder.AppendLine("| $($labelStat.LabelName) | $($labelStat.NumberOfIssuesWithThisLabel) | $($labelStat.PercentageOfIssuesWithThisLabel)% | [$($labelStat.LabelName) open issues]($($labelStat.LabelOpenIssuesUrl)) |") > $null

			# Make sure we don't show more labels than the maximum number specified.
			$numberOfLabelsShown++
			if ($numberOfLabelsShown -ge $maxLabelsToShow)
			{
				break
			}
		}

		Out-File -FilePath $markdownFilePath -InputObject $stringBuilder.ToString() -Force -NoNewline
	}
}
