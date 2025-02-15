using System;
using System.Collections.Generic;
using System.Linq;
using System.Text;
using System.Threading.Tasks;

namespace DocFxHelper.Specification
{
  public class DocSpecMain : DocSpec
  {
    public string? DocFx_Json { get; set; }
    public bool MoveToSubfolder { get; set; }

    public static DocSpecMain Init()
    {
      var spec = new DocSpecMain()
      {
        DocFx_Json = "my.docfx.json",
        MoveToSubfolder = true
      };

      return spec;
    }

  }
}
