# PowerShell Podcast 2024 Challenge Implementation

This repo is my implementation of [Jeff Hicks' PowerShell Podcast 2024 challenge](https://gist.github.com/jdhitsolutions/36f16e9b2d89353cfa93edc8e4b5b3c3).

## 🚀 Running the code

Open the [Invoke-GetGitHubIssuesLabelStats.ps1](/src/Invoke-GetGitHubIssuesLabelStats.ps1) script and run it.
This will generate a markdown file with the label statistics for the PowerShell repository.
If the `ShowMarkdownInBrowser` parameter is set to `$true`, the markdown file will be opened in the default browser.
Feel free to change the parameters to test it with different repositories.

## ? The challenge

Below is a copy of the challenge from Jeff's Gist, in case it disappears in the future.

### Base Challenge

Using whatever tools and techniques you want, write a PowerShell function that will query the Issues section of a GitHub repository and create output showing the number of open issues by label and the percentage of all open issues.
Remember that multiple labels may be used with an issue.

For example, if there are 54 open issues and the bug label is used 23 times, your output would show a count of 23 and a total percentage of 42.59 for the bug label.

The function should work for any GitHub repository, but test it with the PowerShell repository.
Naturally, the function should follow community accepted best practices, have parameter validation, and proper error handling.

### Bonus Challenges

Once you have the function, add custom formatting to display the results in a table, including the repository name or path.

Create an alternative view that will also display the repository and the label URI that GitHub uses to create a filtered page view.

Finally, create a control script using the function to create a markdown report for the PowerShell repository showing the top 25 labels.
The markdown report should have clickable links.

You will most likely end up with several files to meet all the challenge requirements.

Hint: There's more than one way to access the GitHub API.
