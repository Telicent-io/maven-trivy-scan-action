# Maven Trivy Scan Action

This repository provides a GitHub Action that performs a vulnerability scan using [Trivy][Trivy] and uploads the
resulting JSON report files as GitHub build artifacts

While there is a general purpose [Trivy GitHub Action][TrivyAction] testing has shown that this isn't reliable in
actually detecting vulnerabilities.  Using a `scan-type` of `fs` finds the `pom.xml` files but doesn't seem to properly
process them for vulnerability detection in all cases.  For example, it can fail to detect vulnerable dependencies if
these are transitive dependencies of private dependencies (i.e. those not in Maven Central), and more generally where
the vulnerable dependency is transitive.  By scanning the actual SBOM generated from the Maven build we can guarantee
that we have a complete bill of materials to scan, and get much more accurate vulnerability scanning results.

This action basically searches the filesystem for the actual SBOMs (produced by the [Maven CycloneDX
Plugin][MavenCycloneDX] or another method) and then individually runs Trivy against each of those files. 

# Requirements

- This action requires a runner with a Bash shell available, and which can have Trivy CLI installed upon it.
- This action looks for SBOMs generated as part of a Maven build in your `target/` directories.  Your Maven build
  **MUST** happen prior to calling this action and generate SBOMs within the `target/` directories of your module(s).
- Since this action loops on a filesystem search we have to call the Trivy CLI directly rather than via the
  [Action][TrivyAction], thus it needs to install Trivy.  If your workflow that calls this action already has Trivy
  installed then you can set the action input `skip-trivy-install` to `true` to skip that installation.

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
| `directory` | `.` | Specifies the top level directory which will be scanned for Maven generated SBOMs. |
| `pattern` | `*-cyclonedx.json` | Specifies the filename search pattern used to locate Maven SBOMs, set this if your build configuration generates SBOMs with different names. |
| `severities` | `HIGH,CRITICAL` | Specifies the Trivy vulnerability severities that are scanned for and will fail the build. |
| `skip-trivy-install` | `false` | When set to `true` skips the Trivy CLI installation and assumes you've already installed it on your runner, or in an earlier part of your workflow. |
| `report-suffix` | | Sets an optional report name suffix that will be appended to the end of the artifact name, this can be useful if you are running a matrix job to ensure that the action generates a unique artifact name for each matrix job. |

## Outputs

This action does not produce any outputs currently.  It either succeeds if no violations were detected, or fails if
violations were detected.

Note that the action will also fail in other circumstances:

- It's unable to install the required tooling, or you told it not to and failed to provide that tooling yourself
- The provided `directory` does not contain a `pom.xml` file
- No SBOMs are detected within the configured `directory`
- If failed to upload the scan results because the artifact name was not unique.  This can happen if this action is used
  in a matrix build because it only keys the artifact name on the job name.  Unless your dependencies vary by your build
  matrix consider only running this action on one of the jobs within your matrix, or set the `suffix` input to a unique value per matrix job.

## Artifacts

This action uploads a build artifact named `maven-trivy-sbom-scan-results-<job-name><suffix>` to your build.  You can download
this artifact to inspect the scan results if a build fails.

The `<job-name>` comes from the `github.job` context variable which contains the name of your job, and the optional
`<suffix>` comes from the `report-suffix` [input](#inputs) if configured.  A `report-suffix` **MUST** be configured if calling this action from a Matrix job otherwise the matrix jobs won't produce unique artifact names and some of them will fail as a result.

[Trivy]: https://aquasecurity.github.io/trivy/v0.52/
[TrivyAction]: https://github.com/aquasecurity/trivy-action
[MavenCycloneDX]: https://github.com/CycloneDX/cyclonedx-maven-plugin
