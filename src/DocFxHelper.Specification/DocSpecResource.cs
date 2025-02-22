using System;
using System.Collections.Generic;
using System.Linq;
using System.Text;
using System.Text.Json.Serialization;
using System.Threading.Tasks;

namespace DocFxHelper.Specification
{

  public class DocSpecResource : DocSpec
  {
    public string? Id { get; set; }
    public string? Name { get; set; }
    public string? ParentId { get; set; }
    public string Target { get; set; } = "/";
    public string RepoRelativePath { get; set; } = "/";
    public string? MenuParentItemName { get; set; }
    public string? MenuDisplayName { get; set; }
    public int MenuPosition { get; set; } = -1;
    public string? Homepage { get; set; }
    public string? MenuUid { get; set; }
    public string[] Excludes { get; set; } = [];
    public string[] Medias { get; set; } = [];
  }
}
