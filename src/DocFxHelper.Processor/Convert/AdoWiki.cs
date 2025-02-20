using Markdig;
using Markdig.Syntax.Inlines;
using Markdig.Syntax;
using Microsoft.Extensions.Logging;
using System.Linq;
using System.Runtime.InteropServices;

namespace DocFxHelper.Processor.Convert
{
  public class AdoWiki(ILogger<AdoWiki> logger)
  {
    private const string Http_Home_Net = "http://home.net";
    private readonly Uri HomeUri = new(Http_Home_Net);
    private readonly ILogger<AdoWiki> _logger = logger;

    public async Task<int> ConvertAsync(DocFxHelper.Specification.DocSpecAdoWiki docSpec, DirectoryInfo location)
    {
      _logger.LogInformation("Convertion started for spec [{name}]", docSpec.Id);

      await EnsureItemNamesAreDocFxSafe(location);
      await FixHyperlinks(location);

      _logger.LogInformation("Convertion done for spec [{name}]", docSpec.Id);

      return 0;
    }

    private async Task FixHyperlinks(DirectoryInfo location)
    {
      var mdFiles = location.GetFiles("*.md", SearchOption.AllDirectories);

      foreach(var mdFile in mdFiles)
      {
        await FixHyperlinks(mdFile);
      }
    }

    private async Task FixHyperlinks(FileInfo mdFile)
    {
      var mdContent = await Domain.AdoWiki.FromFileAsync(mdFile);

      var pageRelativePath = System.IO.Path.GetRelativePath(Directory.GetCurrentDirectory(), mdFile.FullName);

      var pageUri = new Uri(HomeUri, pageRelativePath!);

      var markdownDocument = Markdown.Parse(mdContent.Content);

      // Traverse the document to find all link elements
      foreach (var node in markdownDocument.Descendants())
      {
        if (node is LinkInline link)
        {
          _logger.LogDebug("Found a link [{link}]", link.Url);

          if (link.Url != null && link.Url != "/")
          {
            var url = link.Url;

            if (System.Uri.IsWellFormedUriString(url, UriKind.Relative))
            {

              string? docfxSafeUrl = url;

              if (System.Web.HttpUtility.UrlDecode(url) != url)
              {
                docfxSafeUrl = System.Web.HttpUtility.UrlDecode(url.Replace("-", " "));
              }

              var linkUri = new Uri(HomeUri, docfxSafeUrl);

              var linkUriWithoutFrontSlash = linkUri.LocalPath.Substring(1);

              string linkPath = System.IO.Path.Combine(Directory.GetCurrentDirectory(), linkUriWithoutFrontSlash);

              string? linkRelative;

              if (System.IO.File.Exists(linkPath))
              {
                _logger.LogDebug("Link [{url}] is a file", docfxSafeUrl);
                linkRelative = linkUriWithoutFrontSlash;
              }
              else if (System.IO.File.Exists(linkPath + ".md"))
              {
                _logger.LogDebug("Link [{url}] is an md file", docfxSafeUrl);
                linkRelative = linkUriWithoutFrontSlash + ".md";
              }
              else if (System.IO.Directory.Exists(linkPath))
              {
                _logger.LogDebug("Link points [{url}] is a folder, need to check the first item of the .order", docfxSafeUrl);

                var dotOrder = System.IO.Path.Combine(linkPath, ".order");

                if (System.IO.File.Exists(dotOrder))
                {
                  _logger.LogDebug("Get first item of {dotOrder}", dotOrder);

                  var firstItem = (await System.IO.File.ReadAllLinesAsync(dotOrder)).FirstOrDefault();
                  if (firstItem != null && !firstItem.EndsWith('/'))
                  {
                    logger.LogDebug("first item of .order {firstItem} doesn't have a trailing slash, so it's hopefully an mdFile", firstItem);
                    linkRelative = linkUriWithoutFrontSlash + "/" + firstItem + ".md";
                  }
                  else
                  {
                    logger.LogDebug("first item of .order {firstItem} has a trailing slash, so a subFolder", firstItem);
                    linkRelative = linkUriWithoutFrontSlash + "/";
                  }
                }
                else
                {
                  _logger.LogDebug("No .order file found in [{linkPath}], the link will be to the folder", linkPath);
                  linkRelative = linkUriWithoutFrontSlash + "/";
                }
              }
              else
              {
                _logger.LogWarning("Link [{url}] is not a file or directory", docfxSafeUrl);
                linkRelative = linkUriWithoutFrontSlash;
              }

              var linkRelativeUri = new Uri(HomeUri, linkRelative);

              if (linkRelativeUri.LocalPath == pageUri.LocalPath)
              {
                _logger.LogDebug("Link [{url}] points the current file [{linkRelativeUri}]", linkUri.LocalPath, pageUri.LocalPath);
                linkRelative = pageUri.Segments[^1];
              }
              else
              {
                linkRelative = System.Web.HttpUtility.UrlDecode(pageUri.MakeRelativeUri(linkRelativeUri).ToString());
              }

              _logger.LogDebug("For page [{pageRelativePath}] Link [{url}] will be [{linkRelative}]", pageRelativePath, link.Url, linkRelative);
              link.Url = linkRelative;

            }
          }
        }
      }

      var writer = new StringWriter();
      var renderer = new Markdig.Renderers.Normalize.NormalizeRenderer(writer);
      var pipeline = new MarkdownPipelineBuilder().Build();
      pipeline.Setup(renderer);
      renderer.Render(markdownDocument);
      writer.Flush();
      
      mdContent.Markdown = writer.ToString();

      await mdContent.ToFile(mdFile);
    }

    private async Task EnsureItemNamesAreDocFxSafe(DirectoryInfo location)
    {
      Stack<DirectoryInfo> folderStack = GetStackOfFolders(location);

      do
      {
        var current = folderStack.Pop();

        RenameDirectoryToSafeName(current);

        var mdFiles = current.GetFiles("*.md");

        foreach (var mdFile in mdFiles)
        {
          RenameMdFileToSafeName(mdFile);

          if (mdFile.Name != "index.md")
          {
            await MoveMdFileToTheirSubFolder(mdFile);
          }
        }

        await CreateTocYmlFromDotOrder(current);

      } while (folderStack.Count > 0);
    }

    private async Task CreateTocYmlFromDotOrder(DirectoryInfo location)
    {
      var includeIndexMd = location.FullName != Directory.GetCurrentDirectory();

      var dotOrder = System.IO.Path.Combine(location.FullName, ".order");

      if (!System.IO.File.Exists(dotOrder))
      {
        _logger.LogWarning("No .order file found in [{location}]", location.FullName);
        return;
      }

      _logger.LogDebug("Loading .order file from [{location}]", location.FullName);
      var orderItems = await System.IO.File.ReadAllLinesAsync(dotOrder);

      var tocItems = new System.Collections.Generic.List<string>();

      foreach (var item in orderItems)
      {
        if (item == "index" && !includeIndexMd)
        {
          continue;
        }

        string? tocItem;

        if (item.EndsWith('/'))
        {
          tocItem = $"- href: {item}";
        }
        else
        {
          tocItem = $"- href: {item}.md";
        }

        tocItems.Add(tocItem);
      }

      var toc_Yml = System.IO.Path.Combine(location.FullName, "toc.yml");

      await System.IO.File.WriteAllLinesAsync(toc_Yml, tocItems);
    }

    private static Stack<DirectoryInfo> GetStackOfFolders(DirectoryInfo location)
    {
      var folderStack = new Stack<DirectoryInfo>();
      var folderQueue = new Queue<DirectoryInfo>();

      folderQueue.Enqueue(location);

      do
      {
        var current = folderQueue.Dequeue();

        folderStack.Push(current);

        foreach (var subFolder in current.GetDirectories())
        {
          folderQueue.Enqueue(subFolder);
        }

      } while (folderQueue.Count > 0);

      return folderStack;
    }

    private async Task MoveMdFileToTheirSubFolder(FileInfo mdFile)
    {
      var location = mdFile.Directory!;
      var originalFileBaseName = System.IO.Path.GetFileNameWithoutExtension(mdFile.Name);

      var mdSubFolder = new DirectoryInfo(System.IO.Path.Combine(location.FullName, originalFileBaseName));

      if (mdSubFolder.Exists)
      {
        _logger.LogDebug("A folder with the md file's name exists, we're at the root and it's best to move it and rename it index.md");
        string newMdFilename = GetMdFileNameInSubFolder(mdFile, originalFileBaseName, mdSubFolder);

        if (newMdFilename != null && !string.IsNullOrEmpty(newMdFilename))
        {
          _logger.LogDebug("Moving root file [{mdFile}] to [{newMdFilename}]", mdFile.Name, newMdFilename);
          mdFile.MoveTo(newMdFilename);

          await SetDotOrderItemNewLocation(location, originalFileBaseName, mdSubFolder);

          var newMdFileBaseName = System.IO.Path.GetFileNameWithoutExtension(newMdFilename);
          await InsertNewItemInDotOrder(mdSubFolder, newMdFileBaseName);
        }
      }
    }

    private async Task InsertNewItemInDotOrder(DirectoryInfo location, string newMdFileBaseName)
    {
      var dotOrder = System.IO.Path.Combine(location.FullName, ".order");

      if (System.IO.File.Exists(dotOrder))
      {
        _logger.LogDebug("Loading .order file from [{mdSubFolder}]", location.FullName);

        var orderItems = await System.IO.File.ReadAllLinesAsync(dotOrder);

        string[] newArray = new string[orderItems.Length + 1];

        _logger.LogDebug("Inserting new item [{newMdFileBaseName}] at the beginning of the .order file", newMdFileBaseName);
        newArray[0] = newMdFileBaseName;

        for (int i = 0; i < orderItems.Length; i++)
        {
          newArray[i + 1] = orderItems[i];
        }

        await System.IO.File.WriteAllLinesAsync(dotOrder, newArray);
        
      }
    }

    private string GetMdFileNameInSubFolder(FileInfo mdFile, string originalFileBaseName, DirectoryInfo mdSubFolder)
    {
      string newMdFilename = string.Empty;

      var testFileName = System.IO.Path.Combine(mdSubFolder.FullName, "index.md");

      if (System.IO.File.Exists(testFileName))
      {
        _logger.LogWarning("File [{newMdFilename}] already exists.", testFileName);

        testFileName = System.IO.Path.Combine(mdSubFolder.FullName, originalFileBaseName + ".md");

        if (System.IO.File.Exists(testFileName))
        {
          _logger.LogError("File [{newMdFilename}] already exists. Really?!  Lets try appending a number from 1..999", testFileName);

          for (int i = 1; i < 1000; i++)
          {
            testFileName = System.IO.Path.Combine(mdSubFolder.FullName, originalFileBaseName + $"-{i}.md");

            if (System.IO.File.Exists(testFileName))
            {
              _logger.LogDebug("File [{testFileName}] already exists.", testFileName);
            }
            else
            {
              _logger.LogDebug("Found a new name for the {mdFile} - [{newMdFilename}]", mdFile.Name, testFileName);
              newMdFilename = testFileName;
              break;
            }
          }
        }
        else
        {
          newMdFilename = testFileName;
        }
      }
      else
      {
        newMdFilename = testFileName;
      }

      return newMdFilename;
    }

    private async Task SetDotOrderItemNewLocation(DirectoryInfo location, string originalFileBaseName, DirectoryInfo mdSubFolder)
    {
      var dotOrder = System.IO.Path.Combine(location.FullName, ".order");

      if (System.IO.File.Exists(dotOrder))
      {
        _logger.LogDebug("Loading .order file from [{mdSubFolder}]", mdSubFolder.FullName);

        var orderItems = await System.IO.File.ReadAllLinesAsync(dotOrder);

        var index = orderItems.ToList().IndexOf(originalFileBaseName);

        if (index > -1)
        {
          _logger.LogDebug("Found the index of the file in the .order file [{index}]", index);
          orderItems[index] = originalFileBaseName + "/";
          await System.IO.File.WriteAllLinesAsync(dotOrder, orderItems);
        }
      }
    }

    private void RenameDirectoryToSafeName(DirectoryInfo current)
    {

      if (System.Web.HttpUtility.UrlDecode(current.Name) != current.Name)
      {
        var safeFolderName = System.Web.HttpUtility.UrlDecode(current.Name.Replace("-", " "));

        if (current.Parent != null)
        {
          _logger.LogDebug("Renaming folder [{currentName}] to [{safeFolderName}] - DocFx Friendly folder name", current.Name, safeFolderName);
          var newFolder = new DirectoryInfo(System.IO.Path.Combine(current.Parent!.FullName, safeFolderName));
          current.MoveTo(newFolder.FullName);
        }
      }
    }

    private void RenameMdFileToSafeName(FileInfo mdFile)
    {

      if (System.Web.HttpUtility.UrlDecode(mdFile.Name) != mdFile.Name)
      {
        var originalFileBaseName = System.IO.Path.GetFileNameWithoutExtension(mdFile.Name);
        var safeFileName = System.Web.HttpUtility.UrlDecode(mdFile.Name.Replace("-", " "));

        _logger.LogDebug("Renaming file [{currentName}] to [{safeFileName}] - DocFx Friendly file name", mdFile.Name, safeFileName);
        var newFile = new FileInfo(System.IO.Path.Combine(mdFile.DirectoryName!, safeFileName));
        mdFile.MoveTo(newFile.FullName);
        UpdateOrderFileItemWithSafeName(mdFile, originalFileBaseName, safeFileName);
      }
    }

    private void UpdateOrderFileItemWithSafeName(FileInfo mdFile, string originalFileBaseName, string safeFileName)
    {
      var orderFile = System.IO.Path.Combine(mdFile.Directory!.FullName, ".order");

      if (System.IO.File.Exists(orderFile))
      {
        _logger.LogDebug("Loading .order file from [{orderFile}]", orderFile);
        var orderItems = System.IO.File.ReadAllLines(orderFile);
        var index = orderItems.ToList().IndexOf(originalFileBaseName);
        if (index > -1)
        {
          _logger.LogDebug("Found the index of the file in the .order file [{index}]", index);
          var safeFileBaseName = System.IO.Path.GetFileNameWithoutExtension(safeFileName);
          orderItems[index] = safeFileBaseName;
          System.IO.File.WriteAllLines(orderFile, orderItems);
        }

      }
    }
  }
}
