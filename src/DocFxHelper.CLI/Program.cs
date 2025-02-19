// See https://aka.ms/new-console-template for more information
using Microsoft.Extensions.DependencyInjection;
using Microsoft.Extensions.Logging;
using Microsoft.Extensions.Options;
using NLog.Extensions.Logging;
using System.CommandLine;
using System.ComponentModel.Design;
using System.Text.Json;
using DocFxHelper.CLI.Commands;
using Microsoft.Extensions.Hosting;
using Microsoft.Extensions.Configuration;

var ass = System.Reflection.Assembly.GetExecutingAssembly();
var exe = new FileInfo(ass.Location);

Console.WriteLine("DocFxHelper CLI [{0}]", ass.GetName().Version);

var hostSettings = new HostApplicationBuilderSettings
{
  ContentRootPath = exe.Directory!.FullName,
  Configuration = new ConfigurationManager()
};

var dfh_json = System.IO.Path.Combine(System.Environment.CurrentDirectory, "dfh.json");
hostSettings.Configuration!.AddJsonFile(dfh_json, optional: true);
hostSettings.Configuration!.AddEnvironmentVariables(prefix: "DFH_");
hostSettings.Configuration!.AddCommandLine(args);

var builder = Host.CreateApplicationBuilder(hostSettings);

builder.Services.Configure<DocFxHelper.CLI.Settings.DocFxHelperSettings>(
  builder.Configuration.GetSection(
    DocFxHelper.CLI.Settings.DocFxHelperSettings.SectionName
  )
);

builder.Services.RegisterCommands();

builder.Services.AddSingleton<DocFxHelper.Processor.Convert.AdoWiki>();

builder.Logging.ClearProviders();
builder.Logging.AddNLog();

using IHost host = builder.Build();

return await host.Services.RunRootCommandAsync(args);

