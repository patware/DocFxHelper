using System;
using System.Collections.Generic;
using System.Linq;
using System.Text;
using System.Text.Json.Serialization;
using System.Threading.Tasks;

namespace DocFxHelper.Specification
{
  public class DocSpecTemplate
  {
    [JsonIgnore]
    public DocSpec? DocSpec { get; set; }
    public string? Name { get; set; }
    public string? Template { get; set; }
    public string? Dest { get; set; }
  }
}
