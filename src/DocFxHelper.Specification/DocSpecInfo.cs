using System;
using System.Collections.Generic;
using System.Linq;
using System.Text;
using System.Threading.Tasks;

namespace DocFxHelper.Specification
{
  /// <summary>
  /// Represents all settings settings required to customize the Doc site
  /// </summary>
  public class DocSpecInfo : DocSpec
  {
    public string? DocFx_Json { get; set; }
    public bool MoveToSubfolder { get; set; }

    public static DocSpecInfo Init()
    {
      var spec = new DocSpecInfo()
      {
        DocFx_Json = "my.docfx.json",
        MoveToSubfolder = true
      };

      return spec;
    }

  }
}
