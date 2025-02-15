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
  }
}
