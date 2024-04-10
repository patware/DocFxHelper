/*
  Any file (conceptual or api) will either have a:
    docurl: url for the [Improve this Doc]
    sourceurl: url for the [View source]

  These urls are built from some git metadata:
    repo : git clone Url
    branch: git branch
    path: file path relative to git

  For Conceptual files: (Improve this Doc)
    model.docurl is built from:
      a. [optional] extension.preTransform()
        * NOTE: if implemented by template
      b. if model.docurl still empty after preTransform()
        getImproveTheDocHref()
          1. model.documentation.remote (Important: required, or else the url will be empty and Improve this Doc won't be displayed)
          2. [Optional] model._gitContribute: overwrites to repo, branch, path
      c. extension.postTransform()
        * NOTE: if implemented by template
  
  The important part is: b.1. - model.documentation.remote.  If the (md)file is outside a git repo, and since this is per-file (because of path), then it makes sense to include this in the md file's Yaml Header.

  DocFxHelper:
  - ADO Wiki:
    - Chances are that the ADO Wiki files will have been published by a Pipeline as pipeline artifacts and won't contain the git details - no source.remote or documentation.remote
    - The git repo url <> wiki url
    - The path to the file in git <> path to the wiki page
      - git path will have a .md extension, the wiki page won't
      - git folder/filename might be moved or renamed to fit docfx, the wiki page path needs to be the original
  - PowerShell Module:
    - Chances are that the PowerShell module will have been published by a Pipeline as pipeline artifacts and won't contain the git details - no source.remote or documentation.remote
    - the git repo url doesn't need translation (like Ado Wiki does)
    - the git path will that of a generated powerShell help with a .md extension, but the actual file is a ps1, a psd1 and/or a psm1.

  Who does what?

  ADO Wiki:
    The docurl needs to be the url to the page's wiki

    - item._adoWikiUri: Wiki URL: https://dev.azure.com/{org}/{teamProject}/_wiki/wikis/{WikiName}

      * NOTE: best location for this: file's Yaml Header : https://{foo}/{teamProject}/_wiki/wikis/{WikiName}
      
      [DocFxHelper]: ConvertTo-DocFxAdoWiki will add this to each md files's Yaml Header

    - item._docfxHelper.remote
        repo: cloneUrl
        branch: branch name (default: main)
        path: file's path relative to the wiki pagePath (original path before any moving or renaming by DocFxHelper)

      * NOTE: best location for this: file's Yaml Header
      
      [DocFxHelper]: ConvertTo-DocFxAdoWiki will add this in the md files Yaml header
    
    the preTransform() will set:
      item.source.remote if not set, use item._docfxHelper.remote
      item.documentation.remote if not set, use item._docfxHelper.remote

    the postTransform() will set:
      item.docurl if not set, use item._adoWikiUri and item.documentation.remote.path

    * NOTE: A code/repo wiki has the ability to specify a branch, but the wiki url will disregard this branch name and will default to the wiki's default.

  Conceptual:
    - item._docfxHelper.remote
        repo: cloneUrl
        branch: branch name (default: main)
        path: file's path relative git path to the md file

      * NOTE: best location for this: file's Yaml Header
      
      [DocFxHelper]: ConvertTo-DocFxConceptual will add this in the md files Yaml header


    this preTransform() will set:
      item.source.remote if not set, and use item._docfxHelper.remote
      item.documentation.remote if not set, and use item._docfxHelper.remote
      
  PowerShell Module:
    The docurl needs to be the url to the powersShell ps1 and/or psm1

    - item._docfxHelper.remote
        repo: cloneUrl
        branch: branch name (default: main)
        path: file's path relative git path to the ps1 and/or psm1 and/or psd1

      * NOTE: best location for this: file's Yaml Header
      
      [DocFxHelper]: ConvertTo-DocFxPowerShellModule will add this in the md files Yaml header
    
    this preTransform() will set:
      item.source.remote if not set, and use item._docfxHelper.remote
      item.documentation.remote if not set, and use item._docfxHelper.remote
      
  
*/
exports.preTransform = function (model) {

  //console.log("DocFxHelper version 0.3.3 - Multiple ADOWiki fixes stabilization phase");

  if (model.sourceurl || model.docurl) {
    return model;
  }

  // console.log("Before:")
  // console.log("path: " + JSON.stringify(model.path));
  // console.log("source: " + JSON.stringify(model.source));
  // console.log("documentation: " + JSON.stringify(model.documentation));
  // console.log("_docfxHelper: " + JSON.stringify(model._docfxHelper));

  if (model._docfxHelper && model._docfxHelper.remote)
  {
    if (!model.source)
    {
      // console.log("model.source not found, creating empty object {}");
      model.source = {};
    }

    if (!model.source.remote)
    {
      // console.log("model.source.remote not found, creating empty object {}");
      model.source.remote = {};
    }

    if (!model.documentation)
    {
      // console.log("model.documentation not found, creating empty object {}");
      model.documentation = {};
    }

    if (!model.documentation.remote)
    {
      // console.log("model.documentation.remote not found, creating empty object {}");
      model.documentation.remote = {};
    }

    if (model._docfxHelper.remote.repo)
    {
      // console.log(`model._docfxHelper.remote.repo: [${model._docfxHelper.remote.repo}] specified, overriding model.source.remote.repo`);
      model.source.remote.repo = model._docfxHelper.remote.repo;
      // console.log(`model._docfxHelper.remote.repo: [${model._docfxHelper.remote.repo}] specified, overriding model.documentation.remote.repo`);
      model.documentation.remote.repo = model._docfxHelper.remote.repo;
    }

    if (model._docfxHelper.remote.branch)
    {
      // console.log(`model._docfxHelper.remote.branch: [${model._docfxHelper.remote.branch}] specified, overriding model.source.remote.branch`);
      model.source.remote.branch = model._docfxHelper.remote.branch;
      // console.log(`model._docfxHelper.remote.branch: [${model._docfxHelper.remote.branch}] specified, overriding model.documentation.remote.branch`);
      model.documentation.remote.branch = model._docfxHelper.remote.branch;
    }

    if (model._docfxHelper.remote.path)
    {
      // console.log(`model._docfxHelper.remote.path: [${model._docfxHelper.remote.repo}] specified, overriding model.source.remote.path`);
      model.source.remote.path = model._docfxHelper.remote.path;
      // console.log(`model._docfxHelper.remote.path: [${model._docfxHelper.remote.path}] specified, overriding model.documentation.remote.path`);
      model.documentation.remote.path = model._docfxHelper.remote.path;
    }

    if (model._docfxHelper.startLine)
    {
      // console.log(`model._docfxHelper.startLine: [${model._docfxHelper.startLine}] specified, overriding model.source.startLine`);
      model.source.startLine = model._docfxHelper.startLine;
      // console.log(`model._docfxHelper.startLine: [${model._docfxHelper.startLine}] specified, overriding model.documentation.startLine`);
      model.documentation.startLine = model._docfxHelper.startLine;
    }

    if (model._docfxHelper.endLine)
    {
      // console.log(`model._docfxHelper.endLine: [${model._docfxHelper.endLine}] specified, overriding model.source.endLine`);
      model.source.endLine = model._docfxHelper.endLine;
      // console.log(`model._docfxHelper.endLine: [${model._docfxHelper.endLine}] specified, overriding model.documentation.endLine`);
      model.documentation.endLine = model._docfxHelper.endLine;
    }
  }

  // console.log("After:")
  // console.log("source: " + JSON.stringify(model.source));
  // console.log("documentation: " + JSON.stringify(model.documentation));

  if (model._adoWikiUri) {
    // console.log(`_adoWikiUri: ${model._adoWikiUri}`);

    if (model.documentation && model.documentation.remote && model.documentation.remote.path)
    {
      // console.log(`model.documentation.remote.path: ${model.documentation.remote.path}`);
      //console.log(`model.docurl before: ${model.docurl}`);
      model.docurl = `${model._adoWikiUri}?pagePath=${model.documentation.remote.path}`;
      //console.log(`model.docurl after: ${model.docurl}`);
    }
    else
    {
      // console.log("model.documentation.remote.path: undefined");
    }
  }

  return model;

}
