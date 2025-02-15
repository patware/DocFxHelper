using System;
using System.Collections.Generic;
using System.Linq;
using System.Text;
using System.Threading.Tasks;

namespace DocFxHelper.Specification
{
  /// <summary>
  /// Represents the specs for integrating a REST API via a swagger json file in the Doc site
  /// </summary>
  public class DocSpecRestApi : DocSpecResource
  {

    public static DocSpec Init()
    {
      var spec = new DocFxHelper.Specification.DocSpecRestApi()
      {
        Id = "MyRestApi",
        Name = "MyRestApi Rest Api",
        Homepage = "index.md",
        ParentId = "ParentId",
        Target = "/Apis/MyRestApi",
        MenuParentItemName = "REST API Suite",
        MenuDisplayName = "My REST API",
        MenuPosition = -1,
        MenuUid = "myRestApi_index",
        Excludes = [],
        Medias = []
      };

      return spec;
    }
  }
}
