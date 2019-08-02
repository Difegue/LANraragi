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
  on = "release"
}

workflow "Build nightly WSL distro" {
  on = "push"
  resolves = ["Upload Installer to MEGA"]
}

workflow "Add WSL distro package to release" {
  on = "release"
  resolves = ["Upload Installer to release"]
}

workflow "Continuous Integration 👌👀" {
  resolves = [
    "Perl Critic",
  ]
  on = "push"
}

workflow "PR Test Suite" {
  resolves = [
    "Perl Critic",
  ]
  on = "pull_request"
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

action "Build Nightly Docker image" {
  uses = "actions/docker/cli@8cdf801b322af5f369e00d85e9cf3a7122f49108"
  needs = ["If dev branch"]
  args = "build -t difegue/lanraragi:nightly -f ./tools/DockerSetup/Dockerfile ."
}

action "Build Latest Docker image" {
  uses = "actions/docker/cli@8cdf801b322af5f369e00d85e9cf3a7122f49108"
  needs = ["Login to Docker Hub"]
  args = "build -t difegue/lanraragi:latest -f ./tools/DockerSetup/Dockerfile ."
}

action "Push nightly to Docker Hub" {
  uses = "actions/docker/cli@8cdf801b322af5f369e00d85e9cf3a7122f49108"
  needs = ["Build Nightly Docker image"]
  args = "push difegue/lanraragi:nightly"
}

action "Push latest to Docker Hub" {
  uses = "actions/docker/cli@8cdf801b322af5f369e00d85e9cf3a7122f49108"
  needs = ["Build Latest Docker image"]
  args = "push difegue/lanraragi:latest"
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

action "Build WSL zip" {
  uses = "./.github/action-wslbuild"
  needs = ["Untagged Docker Build"]
}

action "Upload Installer to MEGA" {
  uses = "difegue/action-megacmd@master"
  needs = ["Build WSL zip"]
  args = "put -c LANraragi_Windows_Installer.zip Windows_Nightlies/${GITHUB_SHA}/LRR_Nightly_Windows.zip"
  secrets = ["USERNAME", "PASSWORD"]
}

action "Upload Installer to release" {
  uses = "JasonEtco/upload-to-release@master"
  args = "LANraragi_Windows_Installer.zip application/zip"
  secrets = ["GITHUB_TOKEN"]
  needs = ["Build WSL zip"]
}
