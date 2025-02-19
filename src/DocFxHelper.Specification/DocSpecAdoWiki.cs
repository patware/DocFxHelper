using System;
using System.Collections.Generic;
using System.Linq;
using System.Text;
using System.Threading.Tasks;

namespace DocFxHelper.Specification
{
  /// <summary>
  /// Represents the specs for integrating an ADO Wiki in the Doc site
  /// </summary>
  public class DocSpecAdoWiki : DocSpecResource
  {
    public bool IsRoot { get; set; }

    public required string WikiUrl { get; set; }

    public static DocSpec Init()
    {
      var spec = new DocFxHelper.Specification.DocSpecAdoWiki()
      {
        Id = "MyProduct",
        Name = "My Product Ado Wiki",
        Homepage = "my_product_homepage.md",
        ParentId = "ParentId",
        Target = "/Products/Flaghsip/MyProduct",
        MenuParentItemName = "Flagship Suite",
        MenuDisplayName = "My Product",
        MenuPosition = -1,
        MenuUid = "my_product_homepage",
        Excludes = ["bla", "settings"],
        Medias = ["images/**", "videos/**"],
        IsRoot = false,
        WikiUrl = "https://dev.azure.com/MyOrg/MyProject/_wiki/wikis/MyProduct.wiki/1/my_product_homepage"
      };

      return spec;
    }
  }
}
