// Copyright (c) Microsoft. All rights reserved. Licensed under the MIT license. See LICENSE file in the project root for full license information.
// {{! DocFxHelper 0.1 - copied from DocFxHelper[2.63.1]/templates/default/common.js}}
//  - Added AdoWiki support

exports.path = {};
exports.path.getFileNameWithoutExtension = getFileNameWithoutExtension;
exports.path.getDirectoryName = getDirectoryName;

exports.getHtmlId = getHtmlId;

exports.getViewSourceHref = getViewSourceHref;
exports.getImproveTheDocHref = getImproveTheDocHref;
exports.processSeeAlso = processSeeAlso;

exports.isAbsolutePath = isAbsolutePath;
exports.isRelativePath = isRelativePath;

function getFileNameWithoutExtension(path) {
    if (!path || path[path.length - 1] === '/' || path[path.length - 1] === '\\') return '';
    var fileName = path.split('\\').pop().split('/').pop();
    return fileName.slice(0, fileName.lastIndexOf('.'));
}

function getDirectoryName(path) {
    if (!path) return '';
    var index = path.lastIndexOf('/');
    return path.slice(0, index + 1);
}

function getHtmlId(input) {
    if (!input) return '';
    return input.replace(/\W/g, '_');
}

// Note: the parameter `gitContribute` won't be used in this function
function getViewSourceHref(item, gitContribute, gitUrlPattern) {
    if (!item || !item.source || !item.source.remote) return '';
    return getRemoteUrl(item.source.remote, item.source.startLine - '0' + 1, null, gitUrlPattern, item);/* DocFxHelper 0.1 */
}

function getImproveTheDocHref(item, gitContribute, gitUrlPattern) {
    if (!item) return '';
    if (!item.documentation || !item.documentation.remote) {
        return getNewFileUrl(item, gitContribute, gitUrlPattern);
    } else {
        return getRemoteUrl(item.documentation.remote, item.documentation.startLine + 1, gitContribute, gitUrlPattern, item);/* DocFxHelper 0.1 */
    }
}

function processSeeAlso(item) {
    if (item.seealso) {
        for (var key in item.seealso) {
            addIsCref(item.seealso[key]);
        }
    }
    item.seealso = item.seealso || null;
}

function isAbsolutePath(path) {
    return /^(\w+:)?\/\//g.test(path);
}

function isRelativePath(path) {
    if (!path) return false;
    return !exports.isAbsolutePath(path);
}

var gitUrlPatternItems = {
    'github': {
        // HTTPS form: https://github.com/{org}/{repo}.git
        // SSH form: git@github.com:{org}/{repo}.git
        // generate URL: https://github.com/{org}/{repo}/blob/{branch}/{path}
        'testRegex': /^(https?:\/\/)?(\S+\@)?(\S+\.)?github\.com(\/|:).*/i,
        'generateUrl': function (gitInfo, item) {/* DocFxHelper 0.1 */
            var url = normalizeGitUrlToHttps(gitInfo.repo);
            url = getRepoWithoutGitExtension(url);
            url += '/blob' + '/' + gitInfo.branch + '/' + gitInfo.path;
            if (gitInfo.startLine && gitInfo.startLine > 0) {
                url += '/#L' + gitInfo.startLine;
            }
            return url;
        },
        'generateNewFileUrl': function (gitInfo, uid) {
            var url = normalizeGitUrlToHttps(gitInfo.repo);
            url = getRepoWithoutGitExtension(url);
            url += '/new';
            url += '/' + gitInfo.branch;
            url += '/' + getOverrideFolder(gitInfo.apiSpecFolder);
            url += '/new?filename=' + getHtmlId(uid) + '.md';
            url += '&value=' + encodeURIComponent(getOverrideTemplate(uid));
            return url;
        }
    },
    'vso': {
        // HTTPS form: https://{account}@dev.azure.com/{account}/{project}/_git/{repo}
        // HTTPS form: https://{user}.visualstudio.com/{org}/_git/{repo}
        // SSH form: git@ssh.dev.azure.com:v3/{account}/{project}/{repo}
        // SSH form: ssh://{user}@{user}.visualstudio.com:22/{org}/_git/{repo}
        // generated URL under branch: https://{account}@dev.azure.com/{account}/{project}/_git/{repo}?version=GB{branch}
        // generated URL under branch: https://{user}.visualstudio.com/{org}/_git/{repo}?path={path}&version=GB{branch}
        // generated URL under detached HEAD: https://{user}.visualstudio.com/{org}/_git/{repo}?path={path}&version=GC{commit}
        'testRegex': /^(https?:\/\/)?(ssh:\/\/\S+\@)?(\S+@)?(\S+\.)?(dev\.azure|visualstudio)\.com(\/|:)\w*\/\w*\/_git\/.*/i,/* DocFxHelper 0.1 to differenciate git vs wikis */
        'generateUrl': function (gitInfo, item) {/* DocFxHelper 0.1 */
            var url = normalizeGitUrlToHttps(gitInfo.repo);
            var branchPrefix = /[0-9a-fA-F]{40}/.test(gitInfo.branch) ? 'GC' : 'GB';
            url += '?path=' + gitInfo.path + '&version=' + branchPrefix + gitInfo.branch;
            if (gitInfo.startLine && gitInfo.startLine > 0) {
                url += '&line=' + gitInfo.startLine;
            }
            return url;
        },
        'generateNewFileUrl': function (gitInfo, uid) {
            return '';
        }
    },
    'bitbucket': {
        // HTTPS form: https://{user}@bitbucket.org/{org}/{repo}.git
        // SSH form: git@bitbucket.org:{org}/{repo}.git
        // generate URL: https://bitbucket.org/{org}/{repo}/src/{branch}/{path}
        'testRegex': /^(https?:\/\/)?(\S+\@)?(\S+\.)?bitbucket\.org(\/|:).*/i,
        'generateUrl': function (gitInfo, item) {/* DocFxHelper 0.1 */
            var url = normalizeGitUrlToHttps(gitInfo.repo);
            url = getRepoWithoutGitExtension(url);
            url += '/src' + '/' + gitInfo.branch + '/' + gitInfo.path;
            if (gitInfo.startLine && gitInfo.startLine > 0) {
                url += '#lines-' + gitInfo.startLine;
            }
            return url;
        },
        'generateNewFileUrl': function (gitInfo, uid) {
            return '';
        }
      }, /* DocFxHelper 0.1 - whole new section for adowiki */
      'adowiki': {
          // https://dev.azure.com/{account}/{project}/_apis/wiki/wikis/{repo}/pages?path={path}&recursionLevel=0&versionDescriptor.version={branch}&includeContent=true
          // generated URL under branch: https://{account}@dev.azure.com/{account}/{project}/_git/{repo}?version=GB{branch}
          // generated URL under branch: https://{user}.visualstudio.com/{org}/_git/{repo}?path={path}&version=GB{branch}
          // generated URL under detached HEAD: https://{user}.visualstudio.com/{org}/_git/{repo}?path={path}&version=GC{commit}
          'testRegex': /^(https?:\/\/)?(ssh:\/\/\S+\@)?(\S+@)?(\S+\.)?(dev\.azure|visualstudio)\.com(\/|:)\w*\/\w*\/_wiki\/wikis\/.*/i,
          'generateUrl': function (gitInfo, item) {
              var url = normalizeGitUrlToHttps(gitInfo.repo);
              var path;
              if (item.adoWikiPath)
              {
                  path = item.adoWikiPath;
              }
              else
              {
                  
                  var relativePath = "/";
                  if (gitInfo.relativePath)
                  {
                      relativePath = gitInfo.relativePath;
                  }
      
                  var path = gitInfo.path.replace(gitInfo.relativePath,'');            
      
                  if (path.lastIndexOf(".md", path.length - ".md".length) !== -1)
                  {
                      path = path.substring(0, path.length - 3);
                  }
              }
              
            
              // &pagePath=/Foo/Bar
              url += '?pagePath=' + path ;
              return url;
          },
          'generateNewFileUrl': function (gitInfo, uid) {
              return '';
          }
      }
}

function getRepoWithoutGitExtension(repo) {
    if (repo.substr(-4) === '.git') {
        repo = repo.substr(0, repo.length - 4);
    }
    return repo;
}

function normalizeGitUrlToHttps(repo) {
    var pos = repo.indexOf('@');
    if (pos == -1) return repo;
    return 'https://' + repo.substr(pos + 1).replace(/:[0-9]+/g, '').replace(/:/g, '/');
}

function getNewFileUrl(item, gitContribute, gitUrlPattern) {
    // do not support VSO for now
    if (!item.source) {
        return '';
    }

    var gitInfo = getGitInfo(gitContribute, item.source.remote);
    if (!gitInfo.repo || !gitInfo.branch || !gitInfo.path) {
        return '';
    }

    var patternName = getPatternName(gitInfo.repo, gitUrlPattern);
    if (!patternName) return patternName;
    return gitUrlPatternItems[patternName].generateNewFileUrl(gitInfo, item.uid);
}

function getRemoteUrl(remote, startLine, gitContribute, gitUrlPattern, item) { /* DocFxHelper 0.1 */
    var gitInfo = getGitInfo(gitContribute, remote);
    if (!gitInfo.repo || !gitInfo.branch || !gitInfo.path) {
        return '';
    }

    var patternName = getPatternName(gitInfo.repo, gitUrlPattern);
    if (!patternName) return '';

    gitInfo.startLine = startLine;
    return gitUrlPatternItems[patternName].generateUrl(gitInfo, item);
}

function getGitInfo(gitContribute, gitRemote) {
    // apiSpecFolder defines the folder contains overwrite files for MRef, the default value is apiSpec
    var defaultApiSpecFolder = 'apiSpec';

    var result = {};
    if (gitContribute && gitContribute.apiSpecFolder) {
        result.apiSpecFolder = gitContribute.apiSpecFolder;
    } else {
        result.apiSpecFolder = defaultApiSpecFolder;
    }
    mergeKey(gitContribute, gitRemote, result, 'repo');
    mergeKey(gitContribute, gitRemote, result, 'branch');
    mergeKey(gitContribute, gitRemote, result, 'path');
    mergeKey(gitContribute, gitRemote, result, 'relativePath'); /* DocFxHelper 0.1 */

    return result;

    function mergeKey(source, sourceFallback, dest, key) {
        if (source && source.hasOwnProperty(key)) {
            dest[key] = source[key];
        } else if (sourceFallback && sourceFallback.hasOwnProperty(key)) {
            dest[key] = sourceFallback[key];
        }
    }
}

function getPatternName(repo, gitUrlPattern) {
    if (gitUrlPattern && gitUrlPattern.toLowerCase() in gitUrlPatternItems) {
        return gitUrlPattern.toLowerCase();
    } else {
        for (var p in gitUrlPatternItems) {
            if (gitUrlPatternItems[p].testRegex.test(repo)) {
                return p;
            }
        }
    }
    return '';
}

function getOverrideFolder(path) {
    if (!path) return "";
    path = path.replace(/\\/g, '/');
    if (path.charAt(path.length - 1) == '/') path = path.substring(0, path.length - 1);
    return path;
}

function getOverrideTemplate(uid) {
    if (!uid) return "";
    var content = "";
    content += "---\n";
    content += "uid: " + uid + "\n";
    content += "summary: '*You can override summary for the API here using *MARKDOWN* syntax'\n";
    content += "---\n";
    content += "\n";
    content += "*Please type below more information about this API:*\n";
    content += "\n";
    return content;
}

function addIsCref(seealso) {
    if (!seealso.linkType || seealso.linkType.toLowerCase() == "cref") {
        seealso.isCref = true;
    }
}