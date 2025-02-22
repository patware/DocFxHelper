using DocFxHelper.CLI.Settings;
using Microsoft.Extensions.Logging;
using Microsoft.Extensions.Options;
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
    private readonly ILogger<Init> _logger;
    private readonly DocFxHelperSettings _settings;
    private readonly JsonSerializerOptions _jsonOptions;
    private const string default_spec_docs_json = "spec.docs.json";
    private const string out_filename_arg = "--out";

    public Init(ILogger<Init> logger, IOptions<Settings.DocFxHelperSettings> options)
    {
      _logger = logger;
      _settings = options.Value;

      _jsonOptions = new JsonSerializerOptions
      {
        WriteIndented = true
      };
    }

    public Command GetCommand()
    {
      var specTypeArgument = new Argument<DocFxHelper.Specification.Enums.DocSpecType>(
        name: "SpecType",
        description: "The type of spec to generate"
      );

      var outOption = new Option<string>(
        name: out_filename_arg,
        description: $"file name to save the specType to.  Default {default_spec_docs_json}"
      );
      outOption.AddAlias("-o");

      var cmd = new Command("init", "Generate a sample spec json based on the provide SpecType");
      cmd.AddArgument(specTypeArgument);
      cmd.AddOption(outOption);
      cmd.SetHandler(async (specType, specFilename) => { await RunAsync(specType, specFilename); }, specTypeArgument, outOption);

      return cmd;
    }

    public async Task RunAsync(DocFxHelper.Specification.Enums.DocSpecType specType, string? specFilename)
    {
      _logger.LogInformation("Init {specType}", specType);

      string specName_json;

      if (specFilename == null)
      {
        if (_settings.ShowTips)
        {
          _logger.LogInformation("{argName} not provided, using default filename [{defaultSpecFilename}]", out_filename_arg, default_spec_docs_json);
          _logger.LogInformation("You can specify a different filename by specifying one via the {argName} argument", out_filename_arg);

        }
        specName_json = "spec.docs.json";
      }
      else
      {
        specName_json = specFilename;
      }

      DocFxHelper.Specification.DocSpec? spec;

      switch (specType)
      {
        case Specification.Enums.DocSpecType.Info:
          {
            spec = DocFxHelper.Specification.DocSpecInfo.Init();
            break;
          }

        case Specification.Enums.DocSpecType.AdoWiki:
          {
            spec = DocFxHelper.Specification.DocSpecAdoWiki.Init();
            break;
          }

        case Specification.Enums.DocSpecType.DotnetApi:
          {
            spec = DocFxHelper.Specification.DocSpecDotnetApi.Init();
            break;
          }

        case Specification.Enums.DocSpecType.RestApi:
          {
            spec = DocFxHelper.Specification.DocSpecRestApi.Init();
            break;
          }

        case Specification.Enums.DocSpecType.PowerShellModule:
          {
            spec = DocFxHelper.Specification.DocSpecPowershellModule.Init();
            break;
          }

        case Specification.Enums.DocSpecType.Conceptual:
          {
            spec = DocFxHelper.Specification.DocSpecConceptual.Init();
            break;
          }

        case Specification.Enums.DocSpecType.DotnetApiYaml:
          {
            spec = DocFxHelper.Specification.DocSpecDotnetApiYaml.Init();
            break;
          }

        default:
          {
            _logger.LogInformation("Unknown specType {specType}, using the base object DocSpec", specType);

            if (_settings.ShowTips)
            {
              _logger.LogInformation("The {initName} expects a SpecType parameter which is one the following:", nameof(Init));
              var enumItems = Enum.GetValues(typeof(Specification.Enums.DocSpecType)).Cast<Specification.Enums.DocSpecType>();

              foreach (var e in enumItems)
              {
                _logger.LogInformation("\tdfx Init {specType}", e);
              }
            }

            spec = new Specification.DocSpec();

            break;
          }
      }

      if (spec != null)
      {
        _logger.LogInformation("Writing [{specType}] to {specName}", specType, specName_json);
        await System.IO.File
          .WriteAllTextAsync(
            specName_json,
            System.Text.Json.JsonSerializer.Serialize<DocFxHelper.Specification.DocSpec>(
              spec,
              _jsonOptions
            )
          );
      }

      _logger.LogInformation("Init finished");
    }
  }
}
