using System;
using System.Collections.Generic;
using System.Linq;
using System.Text;
using System.Threading.Tasks;

namespace DocFxHelper.Specification
{
  public class Enums
  {
    public enum DocSpecType
    {
      /// <summary>
      /// Represents all settings settings required to customize the Doc site
      /// </summary>
      Info = 1,
      /// <summary>
      /// Represents the specs for integrating an ADO Wiki in the Doc site
      /// </summary>
      AdoWiki = 2,
      /// <summary>
      /// Represents the specs for integrating a .Net Library/API in the Doc site
      /// </summary>
      DotnetApi = 3,
      /// <summary>
      /// Represents the specs for integrating a REST API via a swagger json file in the Doc site
      /// </summary>
      RestApi = 4,
      /// <summary>
      /// Represents the specs for integrating a PowerShell Module in the Doc site
      /// </summary>
      PowershellModule = 5,
      /// <summary>
      /// Represents the specs for integrating a DocFx Conceptual site in the Doc site
      /// </summary>
      Conceptual = 6,
      /// <summary>
      /// Represents the specs for integrating the DocFx metadata generated Yaml from a .Net Library/API in the Doc site
      /// </summary>
      ApiYaml = 7
    }
  }
}
