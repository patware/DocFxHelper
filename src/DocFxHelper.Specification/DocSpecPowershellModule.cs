using System;
using System.Collections.Generic;
using System.Linq;
using System.Text;
using System.Threading.Tasks;

namespace DocFxHelper.Specification
{
  public class DocSpecPowershellModule : DocSpecResource
  {
    public string? Psd1 { get; set; }

    public static DocSpec Init()
    {
      var spec = new DocFxHelper.Specification.DocSpecPowershellModule()
      {
        Id = "DocSpecWiki",
        Name = "DocSpec Wiki",
        IsRoot = true,
        Homepage = "index.md",
        Psd1 = "MyPsModule.psd1"
      };

      return spec;
    }
  }
}
