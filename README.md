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

      # Use this action to obtain the AWS CodeArtifact token
      - name: "CodeArtifact Login"
        uses: Telicent-io/maven-trivy-scan-action@v1
        with:
          pattern: 

      # Add steps that use the token as you see fit...
```

After our action has been called the CodeArtifact token is available in the environment of subsequent steps via the
`AWS_CODEARTIFACT_TOKEN` environment variable.  The default username `aws` used for communicating with CodeArtifact is
also exported to the `AWS_CODEARTIFACT_USER` variable.

For example a Maven user might then use a subsequent step to configure Maven with these credentials e.g.

```yaml
      - name: Install Java and Maven
        uses: actions/setup-java@v3
        with:
          java-version: 17
          distribution: temurin
          cache: maven
          server-id: codeartifact
          server-username: AWS_CODEARTIFACT_USER
          server-password: AWS_CODEARTIFACT_TOKEN
```

Or a Python user might do the following:

```yaml
      - name: Install pip requirements
        run: |
          pip install -r requirements.txt
        env:
          PIP_EXTRA_INDEX_URL: "https://aws:${{ env.AWS_CODEARTIFACT_TOKEN }}@telicent-098669589541.d.codeartifact.eu-west-2.amazonaws.com/pypi/telicent-code-artifacts/simple/"
```

Again please refer to the relevant CodeArtifact and/or GitHub Actions documentation for how best to supply the obtained
credentials to the appropriate package manager for your builds.

# Advanced Usage

We provide the ability to further customise the CodeArtifact login process as shown in this example:

```yaml
name: Advanced Login Example
on: 
  push:
  workflow_dispatch:

jobs:
  example:
    runs-on: ubuntu-latest
    permissions:
      id-token: write
      contents: read

    steps:
      # Per requirements you first need to obtain AWS Credentials somehow before using this action
      # We recommend using the official AWS action for this, please refer to their documentation
      # for necessary inputs 
      - name: Configure AWS credentials
        uses: aws-actions/configure-aws-credentials@v1-node16
        with:
          role-to-assume: arn:aws:iam::098669589541:role/AWSDeployCodeArtifact
          aws-region: eu-west-2

      # Use this action to obtain the AWS CodeArtifact Token
      - name: "CodeArtifact Login"
        uses: Telicent-io/aws-codeartifact-login-action@v1
        with:
          domain: telicent
          owner: "098669589541"
          # Place the CodeArtifact username and token into custom environment variables
          user-variable: "CUSTOM_USER"
          token-variable: "CUSTOM_TOKEN"
          # Extend the lifetime of the token to 3600 seconds (1 hour)
          token-lifetime: "3600"
```

In this example the CodeArtifact credentials are placed into the `CUSTOM_USER` and `CUSTOM_TOKEN` variables,
additionally the retrieved token will have a lifetime i.e. validity of 1 hour.

## Token Lifetime

Generally you should set a `token-lifetime` that corresponds to the approximate length of your build, allowing some
slack for the performance vagaries of running a build in GitHub Actions.  If you don't explicitly specify this then the
default lifetime is 900 seconds (15 minutes) which is the minimum permitted duration for a token.

AWS enforces a maximum token duration of 43200 (12 hours), if your build takes longer than that you might need more help
than this action can provide!

[1]: https://docs.aws.amazon.com/codeartifact/latest/ug/tokens-authentication.html
[2]: https://github.com/aws-actions/configure-aws-credentials
