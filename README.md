# DocFxHelper

Script and Template for integrating multiple [DocFx](https://dotnet.github.io/docfx/index.html) sources including Azure DevOps Wikis and multiple APIs

## Key features

- Use Azure DevOps (ADO) Wiki's intuitive interface as the editor for your conceptual documentation
- Document multiple APIs in one site
- Integrate documentation from other repos or pipeline artifacts
- Handle parent-child wikis
- Document PowerShell Modules

The present version of DocFxHelper.ps1 supports the following scenarios:

| Resource Type           | resources.repositories | resources.pipeline |
|-------------------------|:----------------------:|:------------------:|
| Ado Wiki                | Yes                    | No                 |
| Conceptual docs         | No                     | Yes                |
| .NET API Docs           | No                     | Yes                |
| REST API docs           | No                     | Yes                |
| PowerShell Modules docs | No                     | Yes                |

And has been tested with Azure DevOps Pipelines only.

### Ado Wikis

Azure DevOps (ADO) Wiki is intuitive and simplifies the authoring of technical documentation.  But, out-of-the box, the underlying ADO files can't be consumed directly from DocFx, some "changes" are required.

The DocFxHelper script and the templates work together to make them DocFx friendly

- Converts an ADO (Azure DevOps) Wiki into files that DocFx can consume
  - Converts "Improve this docs" links from git urls to ADO Wiki urls
  - Handles ADO Wiki mermaid graphs
  - Converts .order to toc.yml
  - Handles filenames and folders that are not DocFx friendly
  - Fixes links of the renamed files/folders
  - Converts absolute links to relative links

DocFxHelper makes the proper changes to the docfx.json for you.

### Multiple APIs

DocFx has the ability to generate documentation from parsing [.Net API code](https://dotnet.github.io/docfx/docs/dotnet-api-docs.html) and [REST API](https://dotnet.github.io/docfx/docs/rest-api-docs.html) from [Swagger](http://swagger.io/specification/) files.

There's a one-to-one relationship between docfx.json (the configuration used by DocFx to generate the site) and the generated site.  Each repo will have the code for the api and the docfx.json, generating a "docfx site" for each API.  Each site generated may end with a different look and feel, and the search won't work across sites.

If your organization prefers having a centralized site, you'll need extensive knowledge of DocFx in order to bring all of this together.

DocFxHelper helps the integration of multiple APIs in one site.

## Usage

Download or clone this repo:

- devops/DocFxHelper.ps1: use this script in your Azure DevOps Pipeline
- src/templates/DocFxHelper: use this template to convert an Azure DevOps git url to an Azure DevOps Wiki url

## Justification

[DocFx](https://dotnet.github.io/docfx/index.html) is great at generating documentation from source code, but requires a good level of docFx in order to integrate documentation of multiple APIS.

Anyone (or almost) can and should contribute in creating amazing documentation, but the skillset required in order to work locally can be enough to discourage adopting DocFx.

The DocFxHelper aims at bringing that gap by offering the ability to 