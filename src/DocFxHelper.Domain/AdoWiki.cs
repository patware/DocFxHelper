using System.Security.Cryptography;

namespace DocFxHelper.Domain
{
  public class AdoWiki
  {

    public string RelativePath { get; }
    public string RelativePathFixed { get; }
    public bool NeedsToBeRenamed { 
      get { 
        return RelativePath != RelativePathFixed;
      }
    }

    public AdoWiki (string relativePath)
    {
      RelativePath = relativePath;
      RelativePathFixed = System.Web.HttpUtility.UrlDecode(relativePath.Replace("-", " "));
    }

    public void RenameToDocFxSafe()
    {
      throw new NotImplementedException();
    }

    public void MoveToSubFolder()
    {
      throw new NotImplementedException();
    }
  }
}
