using DocFxHelper.Specification;
using Microsoft.Extensions.Logging;
using Microsoft.Extensions.Options;
using System;
using System.Collections.Generic;
using System.CommandLine;
using System.Linq;
using System.Runtime.CompilerServices;
using System.Text;
using System.Threading.Tasks;

namespace DocFxHelper.CLI.Commands
{
  internal class Common(
    ILogger<Common> logger,
    IOptions<Settings.DocFxHelperSettings> options
    )
  {
    private readonly ILogger<Common> _logger = logger;
    private readonly Settings.DocFxHelperSettings _settings = options.Value;
    internal const string SpecOption = "--Spec";
    internal const string Specs_docs_json = "spec.docs.json";
    internal const string BuildOption = "--Build";
    internal const string Build_docs_json = "build.docs.json";
    internal const string DocFxOption = "--DocFx";

    /// <summary>
    /// Returns a --build --Build Command option
    /// </summary>
    /// <returns></returns>
    internal Option<string> GetBuildOption()
    {
      var buildOption = new Option<string>(
              name: BuildOption,
              getDefaultValue: () => Build_docs_json,
              description: "Path to the build.docs.json file"
            );
      buildOption.AddAlias(BuildOption.ToLower());

      return buildOption;
    }

    /// <summary>
    /// returns a [Path] Command argument
    /// </summary>
    /// <returns></returns>
    internal Argument<string> GetPathArgument()
    {
      var pathArgument = new Argument<string>(
        name: "Path",
        getDefaultValue: () => ".",
        description: "Folder where the spec files are.  Default: Current Directory"
      );

      return pathArgument;
    }


    /// <summary>
    /// Returns a -s --spec --Spec Command option
    /// </summary>
    /// <returns></returns>
    internal Option<string> GetSpecOption()
    {
      var specOption = new Option<string>(
        name: SpecOption,
        getDefaultValue: () => Specs_docs_json,
        description: "Path to the spec json file"
      );
      specOption.AddAlias(SpecOption.ToLower());
      specOption.AddAlias("-s");
      return specOption;
    }

    internal Option<string> GetDocFxOption()
    {
      var opt = new Option<string>(
        name: DocFxOption,
        getDefaultValue: () => "docfx.json",
        description: "Path to the docfx.json file"
      );
      opt.AddAlias(DocFxOption.ToLower());
      return opt;
    }

    internal DirectoryInfo GetLocation(string path)
    {
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

      return location;
    }

    internal async Task<DocBuild?> GetBuildFromJsonAsync(string buildJson, DirectoryInfo location)
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
        build!.FileInfo = new System.IO.FileInfo(buildJson);
        return build;
      }
      catch (System.Text.Json.JsonException ex)
      {
        _logger.LogError("{exception}", ex.Message);
      }

      return null;
    }

    internal async Task<DocSpec?> GetSpecFromJsonAsync(string specJson, DirectoryInfo location)
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
        spec!.FileInfo = new System.IO.FileInfo(specJson);
        return spec;
      }
      catch (System.Text.Json.JsonException ex)
      {
        _logger.LogError("{exception}", ex.Message);

      }

      return null;
    }

    internal FileInfo GetDocFxJson(string docfxJson)
    {
      if (File.Exists(docfxJson))
      {
        return new FileInfo(docfxJson);
      }

      var check = System.IO.Path.Combine(Directory.GetCurrentDirectory(), "docfx.json");

      if (File.Exists(check))
      {
        return new FileInfo(check);
      }

      throw new System.IO.FileNotFoundException("docfx.json not found");

    }
  }
}
