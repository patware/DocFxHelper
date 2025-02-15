using System;
using System.Collections.Generic;
using System.Linq;
using System.Text;
using System.Threading.Tasks;

namespace DocFxHelper.Specification
{
  /// <summary>
  /// Represents the specs for integrating a DocFx Conceptual site in the Doc site
  /// </summary>
  public class DocSpecConceptual : DocSpecResource
  {
    public static DocSpec Init()
    {
      var spec = new DocFxHelper.Specification.DocSpecConceptual()
      {
        Id = "MyOtherProduct",
        Name = "My Other Product Conceptual",
        Homepage = "index.md",
        ParentId = "ParentId",
        Target = "/Products/Flaghsip/MyOtherProduct",
        MenuParentItemName = "Flagship Suite",
        MenuDisplayName = "My Other Product",
        MenuPosition = -1,
        MenuUid = "my_other_product_index",
        Excludes = ["docfx.json"],
        Medias = ["images/**", "videos/**"]
      };

      return spec;
    }
  }
}
