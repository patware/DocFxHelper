using Microsoft.Extensions.Logging;
using System;
using System.Collections.Generic;
using System.CommandLine;
using System.CommandLine.Invocation;
using System.ComponentModel;
using System.Linq;
using System.Text;
using System.Threading.Tasks;

namespace DocFxHelper.CLI.Commands
{
  internal class InitReversed
  {
    private readonly ILogger _logger;

    public InitReversed(ILogger<InitReversed> logger)
    {
      _logger = logger;
    }

    public Command GetCommand()
    {
      var cmd = new Command("init-reversed", "Initialize Spec Reversed");
      cmd.IsHidden = true;
      cmd.SetHandler(async () => await RunAsync());
      return cmd;
    }

    public async Task<int> RunAsync()
    {
      _logger.LogInformation("InitReversed starting");
      _logger.LogInformation("specMain.json");
      var specMainString = await System.IO.File.ReadAllTextAsync("specMain.json");
      var specMain = System.Text.Json.JsonSerializer.Deserialize<DocFxHelper.Specification.DocSpec>(specMainString);

      _logger.LogInformation("specAdoWiki.json");
      var specAdoWikiString = await System.IO.File.ReadAllTextAsync("specAdoWiki.json");
      var specAdoWiki = System.Text.Json.JsonSerializer.Deserialize<DocFxHelper.Specification.DocSpec>(specAdoWikiString);

      _logger.LogInformation("specPsModule.json");
      var specPsModuleString = await System.IO.File.ReadAllTextAsync("specPsModule.json");
      var specPsModule = System.Text.Json.JsonSerializer.Deserialize<DocFxHelper.Specification.DocSpec>(specPsModuleString);

      _logger.LogInformation("InitReversed finished");
      return 0;
    }

  }
}
