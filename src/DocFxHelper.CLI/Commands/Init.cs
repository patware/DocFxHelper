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

      var specTypeArgument = new Argument<DocFxHelper.Specification.Enums.DocSpecType>(
        name: "SpecType",
        description: "The type of spec to generate"
      );

      var cmd = new Command("init", "Initialize Spec");
      cmd.AddArgument(specTypeArgument);

      cmd.SetHandler(async (specType) => { await RunAsync(specType); }, specTypeArgument);
      return cmd;
    }

    public async Task RunAsync(DocFxHelper.Specification.Enums.DocSpecType specType)
    {
      _logger.LogInformation("Init starting");

      var jsonOptions = new JsonSerializerOptions
      {
        WriteIndented = true
      };

      var specName_json = $"spec{specType}.json";
      _logger.LogInformation(specName_json);

      DocFxHelper.Specification.DocSpec? spec;

      switch (specType)
      {
        case Specification.Enums.DocSpecType.Main:
          {
            spec = DocFxHelper.Specification.DocSpecMain.Init();
            break;
          }

        case Specification.Enums.DocSpecType.AdoWiki:
          {
            spec = DocFxHelper.Specification.DocSpecAdoWiki.Init();
            break;
          }

        case Specification.Enums.DocSpecType.PowerShellModule:
          {

            spec = DocFxHelper.Specification.DocSpecPowershellModule.Init();

            break;
          }

        default:
          {
            spec = new Specification.DocSpec();
            break;
          }
      }

      if (spec != null)
      {
        await System.IO.File.WriteAllTextAsync(specName_json, System.Text.Json.JsonSerializer.Serialize<DocFxHelper.Specification.DocSpec>(spec, jsonOptions));
      }

      _logger.LogInformation("Init finished");
    }
  }
}
