using System;
using System.Collections.Generic;
using System.Linq;
using System.Text;
using System.Threading.Tasks;

namespace DocFxHelper.Specification
{
  public class DocSpecAdoWiki : DocSpecResource
  {
    public required string WikiUrl { get; set; }

    public static DocSpec Init()
    {
      var spec = new DocFxHelper.Specification.DocSpecAdoWiki()
      {
        Id = "DocSpecAdoWiki",
        Name = "DocSpec Ado Wiki",
        IsRoot = true,
        Homepage = "index.md",
        WikiUrl = "https://dev.azure.com/MyOrg/MyProject/_wiki/wikis/MyProject.wiki/1/index"
      };

      return spec;
    }
  }
}
