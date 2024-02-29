function Get-GitHubIssuesLabelStats
{
	<#
	.SYNOPSIS
		Retrieves all open issues for a GitHub repository and groups them by label, then calculates the label stats, optionally writes them to a markdown file, and then returns them.

	.DESCRIPTION
		Retrieves all open issues for a GitHub repository and groups them by label, then calculates the label stats, optionally writes them to a markdown file, and then returns them.

	.PARAMETER RepositoryOwner
		The owner of the GitHub repository to query. e.g. deadlydog in the deadlydog/PowerShell.tiPS repository.

	.PARAMETER RepositoryName
		The name of the GitHub repository to query. e.g. PowerShell.tiPS in the deadlydog/PowerShell.tiPS repository.

	.PARAMETER OutputMarkdownFilePath
		The path to the output markdown file to create. If not provided, a markdown file will not be created.

	.PARAMETER MaximumNumberOfLabelsToShow
		The maximum number of labels to show in the output markdown file. Default value is 25.

	.EXAMPLE
		PS> Get-GitHubIssuesLabelStats -RepositoryOwner deadlydog -RepositoryName PowerShell.tiPS -OutputMarkdownFilePath "$PSScriptRoot\GitHubIssuesLabelStats.md"

		Retrieves the open issues for the deadlydog/PowerShell.tiPS repository, calculates the label stats, writes the stats to the specified markdown file, and returns the results.

	.OUTPUTS
		An array of PSCustomObjects containing the label stats is returned.
		The label stats include the label name, the number of open issues with that label, and the percentage of open issues with that label.
	#>
	[CmdletBinding()]
	Param
	(
		[Parameter(Mandatory = $true, HelpMessage = 'The owner of the GitHub repository to query. e.g. deadlydog.')]
		[ValidateNotNullOrEmpty()]
		[string] $RepositoryOwner,

		[Parameter(Mandatory = $true, HelpMessage = 'The name of the GitHub repository to query. e.g. PowerShell.tiPS')]
		[ValidateNotNullOrEmpty()]
		[string] $RepositoryName,

		[Parameter(Mandatory = $false, HelpMessage = 'The path to the output markdown file to create.')]
		[ValidateNotNullOrEmpty()]
		[string] $OutputMarkdownFilePath,

		[Parameter(Mandatory = $false, HelpMessage = 'The maximum number of labels to show in the output markdown file. Default value is 25.')]
		[ValidateRange(1, 999999)]
		[int] $MaximumNumberOfLabelsToShow = 25
	)

	Process
	{
		[string] $gitHubRepoBaseUrl = "https://github.com/$RepositoryOwner/$RepositoryName"
		Write-Information "Ensuring the GitHub repository '$gitHubRepoBaseUrl' is valid and we have access to it..."
		Test-GitHubRepository -repoUrl $gitHubRepoBaseUrl

		Write-Information "Retrieving all open GitHub issues for the repo..."
		[PSCustomObject[]] $openIssues = Get-GitHubReposOpenIssues -owner $RepositoryOwner -repo $RepositoryName
		[int] $totalNumberOfOpenIssues = $openIssues.Count

		Write-Information "Grouping the open issues by label..."
		[hashtable] $labelsDictionary = Get-IssuesGroupedByLabel -issues $openIssues

		Write-Information "Calculating the label stats..."
		[hashtable] $getLabelsParams = @{
			labelsDictionary = $labelsDictionary
			totalNumberOfOpenIssues = $totalNumberOfOpenIssues
			baseRepoUrl = $gitHubRepoBaseUrl
		}
		[PSCustomObject[]] $labelStats = Get-IssueStatsByLabel @getLabelsParams

		[bool] $markdownFilePathWasProvided = -Not [string]::IsNullOrWhiteSpace($OutputMarkdownFilePath)
		if ($markdownFilePathWasProvided)
		{
			Write-Information "Writing the label stats to the markdown file '$OutputMarkdownFilePath'..."
			[hashtable] $writeLabelsParams = @{
				labelStats = $labelStats
				baseRepoUrl = $gitHubRepoBaseUrl
				markdownFilePath = $OutputMarkdownFilePath
				totalNumberOfOpenIssues = $totalNumberOfOpenIssues
				maxLabelsToShow = $MaximumNumberOfLabelsToShow
			}
			Write-LabelStatsToMarkdownFile @writeLabelsParams
		}

		return $labelStats
	}

	Begin
	{
		function Test-GitHubRepository([string] $repoUrl)
		{
			try
			{
				$response = Invoke-WebRequest -Uri $repoUrl -UseBasicParsing -ErrorAction SilentlyContinue
				if ($response.StatusCode -ne 200)
				{
					throw "The status code returned was '$($response.StatusCode)'."
				}
			}
			catch
			{
				throw "The GitHub repository at '$repoUrl' could not be found or we do not have permission to access it. Please check the owner and repository name and try again. Error message: $($_.Exception.Message)"
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
				$response = $null
				try
				{
					$response = Invoke-WebRequest -Uri $uri -Headers $headers -ErrorAction SilentlyContinue
					if ($response.StatusCode -ne 200)
					{
						throw "The status code returned was '$($response.StatusCode)'."
					}
				}
				catch
				{
					throw "An error occurred while trying to retrieve the open issues from the GitHub repository. Error message: $($_.Exception.Message)"
				}

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

		function Write-LabelStatsToMarkdownFile([PSCustomObject[]] $labelStats, [string] $baseRepoUrl, [string] $markdownFilePath, [int] $totalNumberOfOpenIssues, [int] $maxLabelsToShow)
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

			$stringBuilder.AppendLine("| Label | Number of Open Issues | Percentage of Open Issues |") > $null
			$stringBuilder.AppendLine("| ----- | --------------------- | ------------------------- |") > $null
			[int] $numberOfLabelsShown = 0
			foreach ($labelStat in $labelStats)
			{
				$stringBuilder.AppendLine("| [$($labelStat.LabelName)]($($labelStat.LabelOpenIssuesUrl)) | $($labelStat.NumberOfIssuesWithThisLabel) | $($labelStat.PercentageOfIssuesWithThisLabel)% |") > $null

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
}
