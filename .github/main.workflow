workflow "Analyze" {
  on = "push"
  resolves = [" PSScriptAnalyzer"]
}

action " PSScriptAnalyzer" {
  uses = "devblackops/github-action-psscriptanalyzer@v1.2.1"
  secrets = ["GITHUB_TOKEN"]
}
