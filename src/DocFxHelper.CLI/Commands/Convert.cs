using DocFxHelper.CLI.Settings;
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
    Processor.Convert.AdoWiki adoWikiProcessor
  )
  {
    private const string _specOption = "--Spec";
    private readonly ILogger<Convert> _logger = logger;
    private readonly DocFxHelperSettings _settings = options.Value;
    private readonly Processor.Convert.AdoWiki _adoWikiProcessor = adoWikiProcessor;

    public enum ExitValues
    {
      /// <summary>
      /// Everything is ok
      /// </summary>
      Ok = 0,
      /// <summary>
      /// spec json not found
      /// </summary>
      SpecJsonNotFound = 1,

      /// <summary>
      /// Error while trying to deserialize the json
      /// </summary>
      DeserializationError = 2
    }

    public Command GetCommand()
    {
      var cmd = new Command("convert", "Convert files from a spec to a DocFx friendly format");

      var pathArgument = new Argument<string>(
        name: "Path",
        getDefaultValue: () => ".",
        description: "Folder where the spec files are.  Default: Current Directory"
      );
      cmd.AddArgument(pathArgument);

      var specOption = new Option<string>(
        name: _specOption,
        getDefaultValue: () => "spec.docs.json",
        description: "Path to the spec json file"
      );
      specOption.AddAlias(_specOption.ToLower());
      specOption.AddAlias("-s");
      cmd.AddOption(specOption);

      cmd.SetHandler(async (string path, string specJson) => await RunAsync(path, specJson), pathArgument, specOption);

      return cmd;
    }

    public async Task<int> RunAsync(string path, string specJson)
    {
      _logger.LogInformation("      path: [{path}]", path);
      _logger.LogInformation("  specJson: [{specJson}]", specJson);
      if (System.IO.File.Exists(path) && System.IO.Directory.Exists(specJson))
      {
        (path, specJson) = (specJson, path); // Tupple - Sweet!
      }

      var locationFullPath = System.IO.Path.GetFullPath(path);
      _logger.LogInformation("Converting from {location}", locationFullPath);

      if (!Directory.Exists(locationFullPath))
      {
        _logger.LogError("{location} folder not found", locationFullPath);

        if (_settings.ShowTips)
        {
          _logger.LogInformation("specify the location where the spec files are found.  Ex:");
          _logger.LogInformation("if the files are in the current directory:");
          _logger.LogInformation("   dfx convert");
          _logger.LogInformation("or use the dot (.) notation to specify the current directory");
          _logger.LogInformation("   dfx convert .");
          _logger.LogInformation("if the files are in a different folder, specify either the full path or the relative path");
          _logger.LogInformation("   dfx convert ..\\foo");

        }
      }

      var location = new DirectoryInfo(locationFullPath);

      if (!System.IO.File.Exists(specJson))
      {
        _logger.LogInformation("{specJson} not found in folder {folder}", specJson, locationFullPath);
        _logger.LogInformation("Checking in the folder [{locationFullName}]", location.FullName);
        specJson = System.IO.Path.Combine(location.FullName, specJson);
      }

      if (!File.Exists(specJson))
      {
        _logger.LogError("{specJson} spec json not found", specJson);

        if (_settings.ShowTips)
        {
          _logger.LogInformation("specify the path and filename of the spec json to load.  Ex:");
          _logger.LogInformation("   dfx convert my.spec.json");
        }

        _logger.LogInformation("Exiting");
        return (int)ExitValues.SpecJsonNotFound;
      }

      _logger.LogInformation("Loading spec from {specJson}", specJson);

      using FileStream openStream = File.OpenRead(specJson);

      DocFxHelper.Specification.DocSpec? spec;

      try
      {
        spec = await System.Text.Json.JsonSerializer.DeserializeAsync<DocFxHelper.Specification.DocSpec>(openStream);
      }
      catch (System.Text.Json.JsonException ex)
      {
        _logger.LogError("{exception}", ex.Message);

        return (int)ExitValues.DeserializationError;
      }

      switch (spec!.GetType().Name)
      {
        case nameof(Specification.DocSpecAdoWiki):
          {
            await _adoWikiProcessor.ConvertAsync((Specification.DocSpecAdoWiki)spec, location);
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
