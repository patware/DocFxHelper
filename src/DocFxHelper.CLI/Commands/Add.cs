using DocFxHelper.CLI.Settings;
using Microsoft.Extensions.Logging;
using Microsoft.Extensions.Options;
using System;
using System.Collections.Generic;
using System.CommandLine;
using System.IO;
using System.Linq;
using System.Text;
using System.Threading.Tasks;

namespace DocFxHelper.CLI.Commands
{
  internal class Add(
    ILogger<Add> logger,
    IOptions<Settings.DocFxHelperSettings> options,
    Common common,
    Processor.AdoWiki adoWikiProcessor
  )
  {
    private const string Description = "Add files from a spec to docfx.json and integrates them with other spec files";
    private readonly ILogger<Add> _logger = logger;
    private readonly DocFxHelperSettings _settings = options.Value;
    private readonly Common _common = common;
    private readonly Processor.AdoWiki _adoWikiProcessor = adoWikiProcessor;

    public enum ExitValues
    {
      /// <summary>
      /// Everything is ok
      /// </summary>
      Ok = 0,

      /// <summary>
      /// spec.docs.json not found
      /// </summary>
      SpecJsonNotFound = 1,

      /// <summary>
      /// build.docs.json not found
      /// </summary>
      BuildJsonNotFound = 2,

      /// <summary>
      /// Error while trying to deserialize the json
      /// </summary>
      DeserializationError = 3
    }

    public Command GetCommand()
    {
      var cmd = new Command("add", Description);

      Argument<string> pathArgument = _common.GetPathArgument();
      cmd.AddArgument(pathArgument);

      Option<string> specOption = _common.GetSpecOption();
      cmd.AddOption(specOption);

      Option<string> docfxJson = _common.GetDocFxOption();
      cmd.AddOption(docfxJson);

      cmd.SetHandler(async (string path, string specJson, string docfxJson) => await RunAsync(path, specJson, docfxJson), pathArgument, specOption, docfxJson);
      return cmd;

    }

    private async Task<int> RunAsync(string path, string specJson, string docfxJson)
    {
      _logger.LogInformation(Description);
      _logger.LogInformation("      path: [{path}]", path);
      _logger.LogInformation("  specJson: [{specJson}]", specJson);

      if (System.IO.File.Exists(path) && System.IO.Directory.Exists(specJson))
      {
        (path, specJson) = (specJson, path); // Tupple - Sweet!
      }

      DirectoryInfo location = _common.GetLocation(path);

      var spec = await _common.GetSpecFromJsonAsync(specJson, location);

      if (spec == null)
      {
        return (int)ExitValues.SpecJsonNotFound;
      }

      var docfx = _common.GetDocFxJson(docfxJson);

      switch (spec!.GetType().Name)
      {
        case nameof(Specification.DocSpecAdoWiki):
          {
            await _adoWikiProcessor.AddAsync((Specification.DocSpecAdoWiki)spec, docfx);
            break;
          }
        default:
          {
            _logger.LogInformation("Spec Type: {specType} - not implemented yet... stay tuned.", spec!.GetType().Name);

            break;
          }
      }

      return (int)ExitValues.Ok;

    }
  }
}
