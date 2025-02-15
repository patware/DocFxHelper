using Microsoft.Extensions.Logging;
using System;
using System.Collections.Generic;
using System.CommandLine;
using System.CommandLine.Invocation;
using System.Linq;
using System.Text;
using System.Text.Json;
using System.Threading.Tasks;

namespace DocFxHelper.CLI.Commands
{
  internal class Init
  {
    private ILogger<Init> _logger;

    public Init(ILogger<Init> logger)
    {
      _logger = logger;
    }

    public Command GetCommand()
    {
      var cmd = new Command("init", "Initialize Spec");
      cmd.SetHandler(async() => await RunAsync());
      return cmd;
    }

    public async Task RunAsync()
    {
      _logger.LogInformation("Init starting");

      var jsonOptions = new JsonSerializerOptions
      {
        WriteIndented = true
      };

      _logger.LogInformation("specMain.json");
      var specMain = new DocFxHelper.Specification.DocSpecMain()
      {
        DocFx_Json = "docfx.json",
        MoveToSubfolder = true
      };
      await System.IO.File.WriteAllTextAsync("specMain.json", System.Text.Json.JsonSerializer.Serialize<DocFxHelper.Specification.DocSpec>(specMain, jsonOptions));

      _logger.LogInformation("specAdoWiki.json");
      var specAdoWiki = new DocFxHelper.Specification.DocSpecAdoWiki()
      {
        Id = "DocSpecWiki",
        Name = "DocSpec Wiki",
        IsRoot = true,
        Homepage = "index.md",
        WikiUrl = "https://dev.azure.com/MyOrg/MyProject/_wiki/wikis/MyProject.wiki/1/MyPage"
      };

      await System.IO.File.WriteAllTextAsync("specAdoWiki.json", System.Text.Json.JsonSerializer.Serialize<DocFxHelper.Specification.DocSpec>(specAdoWiki, jsonOptions));

      _logger.LogInformation("specPsModule.json");
      var specPsModule = new DocFxHelper.Specification.DocSpecPowershellModule()
      {
        Id = "DocSpecWiki",
        Name = "DocSpec Wiki",
        IsRoot = true,
        Homepage = "index.md",
        Psd1 = "MyPsModule.psd1"
      };

      await System.IO.File.WriteAllTextAsync("specPsModule.json", System.Text.Json.JsonSerializer.Serialize<DocFxHelper.Specification.DocSpec>(specPsModule, jsonOptions));

      _logger.LogInformation("Init finished");

    }
  }
}
