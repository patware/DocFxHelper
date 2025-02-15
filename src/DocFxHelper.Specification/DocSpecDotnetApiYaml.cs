using System;
using System.Collections.Generic;
using System.Linq;
using System.Text;
using System.Threading.Tasks;

namespace DocFxHelper.Specification
{
  /// <summary>
  /// Represents the specs for integrating the DocFx metadata generated Yaml from a .Net Library/API in the Doc site
  /// </summary>
  public class DocSpecDotnetApiYaml : DocSpecResource
  {

    public static DocSpec Init()
    {
      var spec = new DocFxHelper.Specification.DocSpecDotnetApiYaml()
      {
        Id = "MyOtherApi",
        Name = "MyOtherApi Dotnet Api Yaml",
        Homepage = "index.md",
        ParentId = "ParentId",
        Target = "/Apis/MyOtherApi",
        MenuParentItemName = "Some Suite",
        MenuDisplayName = "My Other API",
        MenuPosition = -1,
        MenuUid = "myOtherApi_index",
        Excludes = [],
        Medias = []
      };

      return spec;
    }
  }
}
