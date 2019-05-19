workflow "Build nightly Docker image" {
  resolves = [
    "Push nightly to Docker Hub",
  ]
  on = "push"
}

workflow "Build latest Docker image" {
  resolves = [
    "Push latest to Docker Hub",
  ]
  on = "push"
}

workflow "Build WSL distro" {
  resolves = [
    "Upload Installer to MEGA"
  ]
  on = "push"
}

workflow "Continuous Integration 👌👀" {
  resolves = [
    "Perl Critic",
  ]
  on = "push"
}

action "Login to Docker Hub" {
  uses = "actions/docker/login@8cdf801b322af5f369e00d85e9cf3a7122f49108"
  secrets = ["DOCKER_USERNAME", "DOCKER_PASSWORD"]
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

action "Build Nightly Docker image" {
  uses = "actions/docker/cli@8cdf801b322af5f369e00d85e9cf3a7122f49108"
  needs = ["If dev branch"]
  args = "build -t difegue/lanraragi:nightly -f ./tools/DockerSetup/Dockerfile ."
}

action "Build Latest Docker image" {
  uses = "actions/docker/cli@8cdf801b322af5f369e00d85e9cf3a7122f49108"
  needs = ["If master branch"]
  args = "build -t difegue/lanraragi:latest -f ./tools/DockerSetup/Dockerfile ."
}

action "Push nightly to Docker Hub" {
  uses = "actions/docker/cli@8cdf801b322af5f369e00d85e9cf3a7122f49108"
  needs = ["Build Nightly Docker image"]
  args = "push"
}

action "Push latest to Docker Hub" {
  uses = "actions/docker/cli@8cdf801b322af5f369e00d85e9cf3a7122f49108"
  needs = ["Build Latest Docker image"]
  args = "push"
}

action "Untagged Docker Build" {
  uses = "actions/docker/cli@8cdf801b322af5f369e00d85e9cf3a7122f49108"
  args = "build -t difegue/lanraragi -f ./tools/DockerSetup/Dockerfile ."
}

action "LANraragi Test Suite" {
  uses = "./.github/action-run-tests"
  needs = ["Untagged Docker Build"]
}

action "Perl Critic" {
  uses = "./.github/action-critic"
  needs = ["LANraragi Test Suite"]
  secrets = ["GITHUB_TOKEN"]
}

action "Build WSL Distro image" {
  uses = "actions/docker/cli@8cdf801b322af5f369e00d85e9cf3a7122f49108"
  needs = ["Untagged Docker Build"]
  secrets = ["GITHUB_TOKEN"]
}

action "Upload Installer to MEGA" {
  uses = "difegue/action-megacmd@master"
  needs = ["Build WSL zip"]
  args = "put win_package.zip Windows_Nightlies"
  secrets = ["USERNAME", "PASSWORD"]
}

action "Build WSL zip" {
  uses = "./.github/action-wslbuild"
  needs = ["Build WSL Distro image"]
}
