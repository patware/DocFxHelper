using System;
using System.Collections.Generic;
using System.Linq;
using System.Text;
using System.Threading.Tasks;

namespace DocFxHelper.Specification
{
  /// <summary>
  /// Represents the specs for integrating a .Net Library/API in the Doc site
  /// </summary>
  public class DocSpecDotnetApi : DocSpecResource
  {
    public static DocSpec Init()
    {
      var spec = new DocFxHelper.Specification.DocSpecDotnetApi()
      {
        Id = "MyApi",
        Name = "MyApi Dotnet Api",
        Homepage = "index.md",
        ParentId = "ParentId",
        Target = "/Apis/MyApi",
        MenuParentItemName = "Some Suite",
        MenuDisplayName = "My API",
        MenuPosition = -1,
        MenuUid = "myApi_index",
        Excludes = ["obj/**", "bin/**"],
        Medias = []
      };

      return spec;
    }
  }
}
