action "Run Tests" {
  uses = "./.github/action-run-tests"
}

action "Style Check" {
  uses = "./.github/action-critic"
  needs = ["Run Tests"]
  secrets = ["GITHUB_TOKEN"]
}

workflow "Build basically everything" {
  resolves = [
    "Perl Critic",
    "Tag as latest",
    "Push to Docker Hub",
    "Upload Installer to MEGA",
    "Build WSL Distro image",
  ]
  on = "push"
}

action "Build LANraragi Docker image" {
  uses = "actions/docker/cli@8cdf801b322af5f369e00d85e9cf3a7122f49108"
  args = "build -t difegue/lanraragi -f ./tools/DockerSetup/Dockerfile ."
}

action "Build WSL Distro image" {
  uses = "actions/docker/cli@8cdf801b322af5f369e00d85e9cf3a7122f49108"
  needs = ["Build LANraragi Docker image"]
}

action "Login to Docker Hub" {
  uses = "actions/docker/login@8cdf801b322af5f369e00d85e9cf3a7122f49108"
  secrets = ["DOCKER_USERNAME", "DOCKER_PASSWORD"]
  needs = ["Build LANraragi Docker image"]
}

action "LANraragi Test Suite" {
  uses = "./.github/action-run-tests"
  needs = ["Build LANraragi Docker image"]
}

action "Perl Critic" {
  uses = "./.github/action-critic"
  needs = ["LANraragi Test Suite"]
  secrets = ["GITHUB_TOKEN"]
}

action "If dev branch" {
  uses = "actions/bin/filter@3c0b4f0e63ea54ea5df2914b4fabf383368cd0da"
  needs = ["Login to Docker Hub"]
  args = "branch dev"
}

action "If master branch" {
  uses = "actions/bin/filter@3c0b4f0e63ea54ea5df2914b4fabf383368cd0da"
  needs = ["Login to Docker Hub"]
  args = "branch master"
}

action "Tag as nightly" {
  uses = "actions/docker/cli@8cdf801b322af5f369e00d85e9cf3a7122f49108"
  needs = ["If dev branch"]
  args = "tag lanraragi difegue/lanraragi:nightly"
}

action "Tag as latest" {
  uses = "actions/docker/cli@8cdf801b322af5f369e00d85e9cf3a7122f49108"
  needs = ["If master branch"]
  args = "tag lanraragi difegue/lanraragi:latest"
}

action "Push to Docker Hub" {
  uses = "actions/docker/cli@8cdf801b322af5f369e00d85e9cf3a7122f49108"
  needs = ["Tag as latest", "Tag as nightly"]
  args = "push"
}

action "Upload Installer to MEGA" {
  uses = "difegue/action-megacmd@master"
  needs = ["Build WSL Distro image"]
  args = "put README.md ej"
  secrets = ["USERNAME", "PASSWORD"]
}
