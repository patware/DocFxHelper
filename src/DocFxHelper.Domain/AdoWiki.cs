using System.Security.Cryptography;

namespace DocFxHelper.Domain
{
  public class AdoWiki
  {

    public FileInfo MdFile { get; }
    public string RelativePath { get; }


    public string Content { 
      get 
      {
        if (string.IsNullOrWhiteSpace(YamlHeader))
        {
          return Markdown;
        }
        else
        {
          return $"---\r\n{YamlHeader}\r\n---\r\n{Markdown}";
        }
      }
    }

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
      var s = await File.ReadAllTextAsync(MdFile.FullName);

      const string yamlDelimiter = "---\r\n";
      int startIndex = s.IndexOf(yamlDelimiter);
      int endIndex = s.LastIndexOf(yamlDelimiter);

      if (startIndex == -1 || endIndex == -1)
      {
        YamlHeader = string.Empty;
        Markdown = s;
      }
      else
      {
        YamlHeader = s.Substring(startIndex + yamlDelimiter.Length, endIndex - (startIndex + yamlDelimiter.Length)).Trim();
        Markdown = s.Substring(endIndex + yamlDelimiter.Length).Trim();
      }
    }

    public async Task ToFile(FileInfo mdFile)
    {
      await File.WriteAllTextAsync(mdFile.FullName, Content);
    }

    private AdoWiki (FileInfo mdFile)
    {
      MdFile = mdFile;
      RelativePath = System.IO.Path.GetRelativePath(Directory.GetCurrentDirectory(), mdFile.FullName);
    }


  }
}
