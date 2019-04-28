workflow "Continuous Integration 👌👀" {
  on = "push"
  resolves = [
    "Style Check",
    "Run Tests",
  ]
}

action "Run Tests" {
  uses = "./.github/action-run-tests"
}

action "Style Check" {
  uses = "./.github/action-critic"
  needs = ["Run Tests"]
  secrets = ["GITHUB_TOKEN"]
}

workflow "The buildenings" {
  resolves = ["Push image as nightly", "Package Windows Installer"]
  on = "push"
}

action "Build LANraragi" {
  uses = "actions/docker/cli@8cdf801b322af5f369e00d85e9cf3a7122f49108"
}

action "Build WSL Distro image" {
  uses = "actions/docker/cli@8cdf801b322af5f369e00d85e9cf3a7122f49108"
  needs = ["Build LANraragi"]
}

action "Login to Docker Hub" {
  uses = "actions/docker/login@8cdf801b322af5f369e00d85e9cf3a7122f49108"
  needs = ["Build LANraragi"]
}

action "Push image as nightly" {
  uses = "actions/docker/tag@8cdf801b322af5f369e00d85e9cf3a7122f49108"
  needs = ["Login to Docker Hub"]
}

action "Package Windows Installer" {
  uses = "Ilshidur/action-slack@2a8ddb6db23f71a413f9958ae75bbc32bbaa6385"
  needs = ["Build WSL Distro image"]
}
