# DocFxHelper

PowerShell Script and DocFx Template for integrating multiple [DocFx](https://dotnet.github.io/docfx/index.html) sources including Azure DevOps Wikis, API and PowerShell Module documentation.

[DocFx](https://dotnet.github.io/docfx/index.html) is great at generating documentation from source code, but requires a good level of docFx in order to integrate documentation of multiple APIS.

[DocFx](https://dotnet.github.io/docfx/index.html) can convert and integrate MarkDown files, but requires a certain skillset and tooling that is enough to discourage adopting DocFx.

## Release notes

Version 0.2.6

[Fix] [Issue #1](https://github.com/patware/DocFxHelper/issues/1): Template coupled to specific versions of the DocFx.

This fix required an important refactoring of the PowerShell script and the template in order to decouple DocFxHelper from DocFx.

## Key features

- Use Azure DevOps Wiki's intuitive interface as the editor for your conceptual documentation
- Combine documentation from multiple ADO Wikis, API, PowerShell modules in one site

The present version of DocFxHelper.ps1 supports the following scenarios:

- Ado Wikis
- Conceptual docs
- .NET API Docs
- REST API docs
- PowerShell Modules docs

And has been tested with Azure DevOps Pipelines only.

### Ado Wikis

Azure DevOps (ADO) Wiki is intuitive and simplifies the authoring of technical documentation.  But, out-of-the box, the underlying ADO files can't be consumed directly from DocFx, some "changes" are required.

The DocFxHelper script and the templates work together to make them DocFx friendly

- Converts an ADO (Azure DevOps) Wiki into files that DocFx can consume
  - Converts "Edit this page" links from git urls to ADO Wiki urls
  - Handles ADO Wiki mermaid graphs
  - Converts .order to toc.yml
  - Handles filenames and folders that are not DocFx friendly
  - Fixes links of the renamed files/folders
  - Converts absolute links to relative links

DocFxHelper can even make the proper changes to the docfx.json for you.

### Multiple APIs

DocFx has the ability to generate documentation from parsing [.Net API code](https://dotnet.github.io/docfx/docs/dotnet-api-docs.html) and [REST API](https://dotnet.github.io/docfx/docs/rest-api-docs.html) from [Swagger](http://swagger.io/specification/) files.

There's a one-to-one relationship between docfx.json (the configuration used by DocFx to generate the site) and the generated site.  Each repo will have the code for the api and the docfx.json, generating a "docfx site" for each API.  Each site generated may end with a different look and feel, and the search won't work across sites.

If your organization prefers having a centralized site, you'll need extensive knowledge of DocFx in order to bring all of this together.

DocFxHelper helps the integration of multiple APIs in one site.

### Integrate documentation from other repos or pipeline artifacts

Your docs site will contain technical documentation from various teams, products and groups, but you want them rendered as a whole.  These other sources will be in different repos.

You'll have a repo and a pipeline for "the site".  The repo will have the DocFxHelper.ps1 and DocFxHelper Template, optionally a DocFx.config file, and the pipeline.

With DocFxHelper, you can integrate documentation that are in different repos or pipelines.

### Handle parent-child wikis

As your docs site grow, you might want to split sections of articles in multiple Azure DevOps Wikis.  Those sections might have different publishing practices, processes, policies or schedules.

Your organization might already have multiple Azure DevOps Wikis that you would like to integrate into the "docs site".

DocFxHelper will integrate "child Wikis" and will take care of updating the parent Wiki table of content file (toc.yml), convert absolute links to relative links, etc.

### Document PowerShell Modules

[PlatyPS](https://github.com/PowerShell/platyPS) generates markdown help for your PowerShell modules.  

DocFx Integrate these generated markdown files, but adds the necessary elements so that the "View source code" link points to the right URL.

## Usage

Download or clone this repo:

- devops/DocFxHelper.ps1: the script can be called from your Azure DevOps Pipeline
- src/templates/DocFxHelper: the template will convert git url to an Azure DevOps Wiki url

Check the [ADO pipeline](devops/README.md) for how to use the DocFxHelper.ps1
