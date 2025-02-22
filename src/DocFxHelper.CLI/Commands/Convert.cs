using DocFxHelper.CLI.Settings;
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
    Processor.Convert.AdoWiki adoWikiProcessor
  )
  {
    private const string _specOption = "--Spec";
    private const string specs_docs_json = "spec.docs.json";
    private const string _buildOption = "--Build";
    private const string build_docs_json = "build.docs.json";
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
      var cmd = new Command("convert", "Convert files from a spec to a DocFx friendly format");

      var pathArgument = new Argument<string>(
        name: "Path",
        getDefaultValue: () => ".",
        description: "Folder where the spec files are.  Default: Current Directory"
      );
      cmd.AddArgument(pathArgument);

      var specOption = new Option<string>(
        name: _specOption,
        getDefaultValue: () => specs_docs_json,
        description: "Path to the spec json file"
      );
      specOption.AddAlias(_specOption.ToLower());
      specOption.AddAlias("-s");
      cmd.AddOption(specOption);

      var buildOption = new Option<string>(
        name: _buildOption,
        getDefaultValue: () => build_docs_json,
        description: "Path to the build.docs.json file"
      );
      specOption.AddAlias(_buildOption.ToLower());
      cmd.AddOption(buildOption);

      cmd.SetHandler(async (string path, string specJson, string buildJson) => await RunAsync(path, specJson, buildJson), pathArgument, specOption, buildOption);

      return cmd;
    }

    public async Task<int> RunAsync(string path, string specJson, string buildJson)
    {
      _logger.LogInformation("      path: [{path}]", path);
      _logger.LogInformation("  specJson: [{specJson}]", specJson);
      _logger.LogInformation(" buildJson: [{buildJson}]", buildJson);

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

      var spec = await GetSpecFromJsonAsync(specJson, location);
           
      if (spec == null)
      {
        return (int)ExitValues.SpecJsonNotFound;
      }

      var build = await GetBuildFromJsonAsync(buildJson, location);

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



      return (int)ExitValues.Ok;
    }

    private async Task<DocBuild?> GetBuildFromJsonAsync(string buildJson, DirectoryInfo location)
    {

      if (!File.Exists(buildJson))
      {
        _logger.LogInformation("{buildJson} not found", buildJson);
        _logger.LogInformation("Checking in the folder [{locationFullName}]", location.FullName);
        buildJson = System.IO.Path.Combine(location.FullName, buildJson);
      }

      if (!File.Exists(buildJson))
      {
        _logger.LogError("{buildJson} build.docs.json not found in {folder}", buildJson, location.FullName);

        if (_settings.ShowTips)
        {
          _logger.LogInformation("specify the path and filename of the build.docs.json to load.  Ex:");
          _logger.LogInformation("   dfx convert build.docs.json");
        }

        return null;
      }

      using FileStream buildJsonStream = File.OpenRead(buildJson);

      DocFxHelper.Specification.DocBuild? build;

      try
      {
        _logger.LogDebug("Deserializing {buildJson}", buildJson);
        build = await System.Text.Json.JsonSerializer.DeserializeAsync<DocFxHelper.Specification.DocBuild>(buildJsonStream);
        return build;
      }
      catch (System.Text.Json.JsonException ex)
      {
        _logger.LogError("{exception}", ex.Message);
      }

      return null;
    }

    private async Task<DocSpec?> GetSpecFromJsonAsync(string specJson, DirectoryInfo location)
    {
      if (!System.IO.File.Exists(specJson))
      {
        _logger.LogInformation("{specJson} not found in folder {folder}", specJson, location.FullName);
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

      }

      _logger.LogInformation("Loading spec from {specJson}", specJson);

      using FileStream specJsonStream = File.OpenRead(specJson);
      DocFxHelper.Specification.DocSpec? spec;

      try
      {
        _logger.LogDebug("Deserializing {specJson}", specJson);
        spec = await System.Text.Json.JsonSerializer.DeserializeAsync<DocFxHelper.Specification.DocSpec>(specJsonStream);
        return spec;
      }
      catch (System.Text.Json.JsonException ex)
      {
        _logger.LogError("{exception}", ex.Message);

      }

      return null;
    }
  }
}
