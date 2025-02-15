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
  internal class InitReversed(ILogger<InitReversed> logger)
  {
    private const string spec_json_pattern = "spec*.json";

    public enum ExitValues
    {
      /// <summary>
      /// Everything is ok
      /// </summary>
      Ok = 0,
      /// <summary>
      /// Didn't find any spec to parse
      /// </summary>
      NoJsonFound = 1
    }
    private readonly ILogger _logger = logger;

    public Command GetCommand()
    {
      var cmd = new Command("init-reversed", "Initialize Spec Reversed")
      {
        IsHidden = true
      };
      cmd.SetHandler(async () => await RunAsync());
      return cmd;
    }

    public async Task<int> RunAsync()
    {
      _logger.LogInformation("InitReversed starting");

      var spec_json_files = System.IO.Directory.GetFiles(System.Environment.CurrentDirectory, spec_json_pattern);

      if (spec_json_files.Length == 0)
      {
        _logger.LogInformation("No json file matching pattern {pattern}", spec_json_pattern);
        return (int)ExitValues.NoJsonFound;
      }

      _logger.LogInformation("Found {fileCount} spec*.json to Deserialize", spec_json_files.Length);

      var maxFilenameLength = spec_json_files
        .Select(f => new FileInfo(f).Name.Length)
        .Max();

      _logger.LogDebug("Max Filename Length: {maxFilenameLength}", maxFilenameLength);      
      var maxSpecTypeNameLength = "DocSpec".Length + Enum.GetNames(typeof(Specification.Enums.DocSpecType)).Select(e => e.Length).Max();
      _logger.LogDebug("Max SpecType Name Length: {maxSpecTypeNameLength}", maxSpecTypeNameLength);

      _logger.LogInformation("{file} {SpecType}", "File".PadLeft(maxFilenameLength,' '), "Spec Type".PadRight(maxSpecTypeNameLength, ' '));
      _logger.LogInformation("{file} {SpecType}", "".PadLeft(maxFilenameLength, '-'), "".PadRight(maxSpecTypeNameLength, '-'));

      foreach (var spec_json_file in spec_json_files)
      {
        var fi = new System.IO.FileInfo(spec_json_file);
        var specMainString = await System.IO.File.ReadAllTextAsync(spec_json_file);
        var specMain = System.Text.Json.JsonSerializer.Deserialize<DocFxHelper.Specification.DocSpec>(specMainString);
        //_logger.LogInformation("{file} type is {specType}", fi.Name, specMain!.GetType());
        _logger.LogInformation("{file} {SpecType}", fi.Name.PadLeft(maxFilenameLength, ' '), specMain!.GetType().Name.PadRight(maxSpecTypeNameLength, ' '));
      }

      return (int)ExitValues.Ok;
    }

  }
}
