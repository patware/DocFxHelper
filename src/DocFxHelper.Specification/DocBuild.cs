using System;
using System.Collections.Generic;
using System.Linq;
using System.Text;
using System.Text.Json.Serialization;
using System.Threading.Tasks;

namespace DocFxHelper.Specification
{
  public class DocBuild
  {
    public int BuildId { get; set; } = 0;
    public string BuildName { get; set; } = string.Empty;
    public DateTime BuildDate { get; set; }
    public string RequestedForEmail { get; set; } = string.Empty;
    public string RequestedForName { get; set; } = string.Empty;
    public string RepositoryUri { get; set; } = string.Empty;
    public string RepositoryBranch { get; set; } = "refs/heads/main";
    public string RepositoryBranchName { get; set; } = "main";

    [JsonIgnore]
    public FileInfo? FileInfo { get; set; }
  }
}
