workflow "Continuous Integration 👌👀" {
  on = "push"
  resolves = ["Style Check"]
}

action "Run Tests" {
  uses = "./.github/action-run-tests"
}

action "Style Check" {
  uses = "./.github/action-critic"
  needs = ["Run Tests"]
  secrets = ["GITHUB_TOKEN"]
}
