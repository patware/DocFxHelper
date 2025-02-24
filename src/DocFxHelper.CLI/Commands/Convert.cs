using DocFxHelper.CLI.Settings;
using DocFxHelper.Processor;
using DocFxHelper.Specification;
using Microsoft.Extensions.Logging;
using Microsoft.Extensions.Options;
using NLog.LayoutRenderers;
using System;
using System.Collections.Generic;
using System.CommandLine;
using System.Linq;
using System.Text;
using System.Threading.Tasks;

namespace DocFxHelper.CLI.Commands
{
  internal class Convert(
    ILogger<Convert> logger,
    IOptions<Settings.DocFxHelperSettings> options,
    Common common,
    AdoWiki adoWikiProcessor
  )
  {
    private const string Description = "Convert files from a spec to a DocFx friendly format";
    private readonly ILogger<Convert> _logger = logger;
    private readonly DocFxHelperSettings _settings = options.Value;
    private readonly Common _common = common;
    private readonly AdoWiki _adoWikiProcessor = adoWikiProcessor;

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
      var cmd = new Command("convert", Description);

      Argument<string> pathArgument = _common.GetPathArgument();
      cmd.AddArgument(pathArgument);

      Option<string> specOption = _common.GetSpecOption();
      cmd.AddOption(specOption);

      Option<string> buildOption = _common.GetBuildOption();
      cmd.AddOption(buildOption);

      cmd.SetHandler(async (string path, string specJson, string buildJson) => await RunAsync(path, specJson, buildJson), pathArgument, specOption, buildOption);

      return cmd;
    }



    public async Task<int> RunAsync(string path, string specJson, string buildJson)
    {
      _logger.LogInformation(Description);
      _logger.LogInformation("      path: [{path}]", path);
      _logger.LogInformation("  specJson: [{specJson}]", specJson);
      _logger.LogInformation(" buildJson: [{buildJson}]", buildJson);

      var currentDirectory = Environment.CurrentDirectory;

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

      Directory.SetCurrentDirectory(spec.FileInfo!.Directory!.FullName);

      var build = await _common.GetBuildFromJsonAsync(buildJson, location);

      if (build == null)
      {
        return (int)ExitValues.BuildJsonNotFound;
      }

      switch (spec!.GetType().Name)
      {
        case nameof(Specification.DocSpecAdoWiki):
          {
            await _adoWikiProcessor.ConvertAsync((Specification.DocSpecAdoWiki)spec, location, build!);
            break;
          }
        default:
          {
            _logger.LogInformation("Spec Type: {specType} - not implemented yet... stay tuned.", spec!.GetType().Name);

            break;
          }
      }

      Directory.SetCurrentDirectory(currentDirectory);

      return (int)ExitValues.Ok;
    }


  }
}
