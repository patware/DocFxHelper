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

      var spec_json_files = System.IO.Directory.GetFiles(System.Environment.CurrentDirectory, "spec*.json");

      _logger.LogInformation("Found {fileCount} spec*.json to Deserialize", spec_json_files.Length);

      foreach(var spec_json_file in spec_json_files)
      {
        var fi = new System.IO.FileInfo(spec_json_file);
        var specMainString = await System.IO.File.ReadAllTextAsync(spec_json_file);
        var specMain = System.Text.Json.JsonSerializer.Deserialize<DocFxHelper.Specification.DocSpec>(specMainString);
        _logger.LogInformation("{file} type is {specType}", fi.Name, specMain!.GetType());
      }

      _logger.LogInformation("InitReversed finished");
      return 0;
    }

  }
}
