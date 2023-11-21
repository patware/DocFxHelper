exports.preTransform = function (model) {

  if (model.sourceurl || model.docurl)
  {
    return model;
  }

  if (model._gitContribute && model._gitContribute.AdoWikiUri)
  {
    console.log(`[DocFxHelper.transform] [${model.path}] is an AdoWiki`);
    console.log(`[DocFxHelper.transform] [${model.path}]    model._gitContribute.AdoWikiUri: [${model._gitContribute.AdoWikiUri}]`);
    console.log(`[DocFxHelper.transform] [${model.path}]          model.adoWikiAbsolutePath: [${model.adoWikiAbsolutePath}]`);
    console.log(`[DocFxHelper.transform] [${model.path}]    model.documentation.remote.repo: [${model.documentation.remote.repo}]`);
    console.log(`[DocFxHelper.transform] [${model.path}]    model.documentation.remote.branch: [${model.documentation.remote.branch}]`);
    console.log(`[DocFxHelper.transform] [${model.path}]    model.documentation.remote.path: [${model.documentation.remote.path}]`);

    var mdPath = model.documentation.remote.path ?? model.path;
    if (model.adoWikiAbsolutePath)
    {
      console.log(`[DocFxHelper.transform] [${model.path}] using model.adoWikiAbsolutePath for the path`);
      mdPath = model.adoWikiAbsolutePath;
    }
    else
    {
      console.log(`[DocFxHelper.transform] [${model.path}] using model.documentation.remote.path for the path`);

      var relativePath = "/";
      if (model._gitContribute.relativePath)
      {
        console.log(`[DocFxHelper.transform] [${model.path}] but removing specified _gitContribute.relativePath`);
        relativePath = model._gitContribute.relativePath;
      }
      mdPath = mdPath.replace(relativePath,''); 

    }

    if (mdPath.lastIndexOf(".md", mdPath.length - 3) !== -1)
    {
      mdPath = mdPath.substring(0, mdPath.length - 3);
    }

    model.docurl = `${model._gitContribute.AdoWikiUri}?pagePath=${mdPath}`;

    console.log(`[DocFxHelper.transform] [${model.path}] docurl: [${model.docurl}]`)

  }
  
  return model;
}

exports.postTransform = function (model) {
  return model;
}