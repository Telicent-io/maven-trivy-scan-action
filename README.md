# Maven Trivy Scan Action

This repository provides a GitHub Action that performs a vulnerability scan using [Trivy][Trivy] and uploads the
resulting JSON report files as GitHub build artifacts

While there is a general purpose [Trivy GitHub Action][TrivyAction] testing has shown that this isn't reliable in
actually detecting vulnerabilities.  Using a `scan-type` of `fs` finds the `pom.xml` files but doesn't seem to properly
process them for vulnerability detection.

This action basically searches the filesystem for the actual SBOMs (produced by the [Maven CycloneDX
Plugin][MavenCycloneDX] or another method) and then individually runs Trivy against each of those files.  This seems to
then reliably report any vulnerabilities.

# Requirements

- This action requires a runner with a Bash shell available, and which can have Trivy CLI installed upon it.
- This action looks for SBOMs generated as part of a Maven build in your `target/` directories.  Your Maven build
  **MUST** happen prior to calling this action and generate SBOMs within the `target/` directories of your module(s).
- Since this action loops on a filesystem search we have to call the Trivy CLI directly rather than via the
  [Action][TrivyAction], thus it needs to install Trivy.  If your workflow that calls this action already has Trivy
  installed then you can use the action inputs to skip that installation.

# Usage

At its most basic the action is used as follows:

```yaml
name: Trivy Maven Scan Example
on: 
  push:
  workflow_dispatch:

jobs:
  example:
    runs-on: ubuntu-latest
    permissions:
      contents: read

    steps:
      # Per requirements you first need to obtain AWS Credentials somehow before using this action
      # We recommend using the official AWS action for this, please refer to their documentation
      # for necessary inputs 
      - name: Maven Build
        run: |
          mvn clean install

      # Run the Maven Trivy SBOM Scan
      - name: "Maven Trivy SBOM Scan"
        uses: Telicent-io/maven-trivy-scan-action@v1

      # Add steps that use the token as you see fit...
```

## Inputs

The following inputs are supported by this action:

| Input | Default | Purpose |
|-------|---------|---------|
| `directory` | `.` | Specifies the top level directory which will be scanned for Maven generated SBOMs |
| `pattern` | `*-cyclonedx.json` | Specifies the filename search pattern used to locate Maven SBOMs |
| `severities` | `HIGH,CRITICAL` | Specifies the Trivy vulnerability severities that are scanned for and will fail the build |

[Trivy]: https://aquasecurity.github.io/trivy/v0.52/
[TrivyAction]: https://github.com/aquasecurity/trivy-action
[MavenCycloneDX]: https://github.com/CycloneDX/cyclonedx-maven-plugin
