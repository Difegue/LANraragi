workflow "Continuous Integration 👌👀" {
  on = "push"
  resolves = ["Run Tests", "Style Check"]
}

action "Run Tests" {
  uses = "./.github/action-run-tests"
}

action "Style Check" {
  uses = "./.github/action-critic"
}
