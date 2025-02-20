using System.Security.Cryptography;

namespace DocFxHelper.Domain
{
  public class AdoWiki
  {

    public FileInfo MdFile { get; }
    public string RelativePath { get; }

    public string Content { get; private set; }
    public string YamlHeader { get; set; }
    public string Markdown { get; set; }
    
    public static async Task<AdoWiki> FromFileAsync(FileInfo mdFile)
    {
      var adoWiki = new AdoWiki(mdFile);

      await adoWiki.LoadContentAsync();

      return adoWiki;
    }

    private async Task LoadContentAsync()
    {
      Content = await File.ReadAllTextAsync(MdFile.FullName);

      const string yamlDelimiter = "---";
      int startIndex = Content.IndexOf(yamlDelimiter);
      int endIndex = Content.LastIndexOf(yamlDelimiter);

      if (startIndex == -1 || endIndex == -1)
      {
        YamlHeader = string.Empty;
        Markdown = Content;
      }
      else
      {
        YamlHeader = Content.Substring(startIndex + yamlDelimiter.Length, endIndex - (startIndex + yamlDelimiter.Length)).Trim();
        Markdown = Content.Substring(endIndex + yamlDelimiter.Length).Trim();
      }
    }

    public async Task ToFile(FileInfo mdFile)
    {

      if (string.IsNullOrWhiteSpace(YamlHeader))
      {
        await File.WriteAllTextAsync(mdFile.FullName, Markdown);
      }
      else
      {
        await File.WriteAllTextAsync(mdFile.FullName, $"---\n{YamlHeader}\n---\n{Markdown}");
      }

    }

    private AdoWiki (FileInfo mdFile)
    {
      MdFile = mdFile;
      RelativePath = System.IO.Path.GetRelativePath(Directory.GetCurrentDirectory(), mdFile.FullName);
    }


  }
}
