using System;
using System.Collections.Generic;
using System.Linq;
using System.Text;
using System.Threading.Tasks;

namespace DocFxHelper.Specification
{
  /// <summary>
  /// Represents the specs for integrating a PowerShell Module in the Doc site
  /// </summary>
  public class DocSpecPowershellModule : DocSpecResource
  {
    public string? Psd1 { get; set; }

    public static DocSpec Init()
    {
      var spec = new DocFxHelper.Specification.DocSpecPowershellModule()
      {
        Id = "MyPsModule",
        Name = "MyPsModule Powershell Module",
        Homepage = "index.md",
        ParentId = "ParentId",
        Target = "/PS/MyPsModule",
        MenuParentItemName = "Some Suite",
        MenuDisplayName = "MyPsModule",
        MenuPosition = -1,
        MenuUid = "myPsModule_index",
        Excludes = [],
        Medias = [],
        Psd1 = "MyPsModule.psd1"
      };

      return spec;
    }
  }
}
