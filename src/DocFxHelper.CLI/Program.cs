// See https://aka.ms/new-console-template for more information
using Microsoft.Extensions.DependencyInjection;
using Microsoft.Extensions.Hosting;
using Microsoft.Extensions.Logging;
using Microsoft.Extensions.Options;
using NLog.Extensions.Logging;
using System.CommandLine;
using System.ComponentModel.Design;
using System.Text.Json;
using DocFxHelper.CLI.Commands;

Console.WriteLine("DocFxHelper starting");

var builder = Host.CreateApplicationBuilder(args);

builder.Services.Configure<DocFxHelper.CLI.Settings.DocFxHelperSettings>(builder.Configuration.GetSection(DocFxHelper.CLI.Settings.DocFxHelperSettings.SectionName));

builder.Services.RegisterCommands();

builder.Logging.ClearProviders();
var loggingBuilder = builder.Logging.AddNLog();

using IHost host = builder.Build();



return await host.Services.RunRootCommandAsync(args);

