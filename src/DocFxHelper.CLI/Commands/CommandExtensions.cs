using Microsoft.Extensions.DependencyInjection;
using System;
using System.Collections.Generic;
using System.CommandLine;
using System.Diagnostics.CodeAnalysis;
using System.Linq;
using System.Runtime.CompilerServices;
using System.Text;
using System.Threading.Tasks;

namespace DocFxHelper.CLI.Commands
{
  public static class CommandExtensions
  {
    /// <summary>
    /// Adds every Commands to the ServiceCollection
    /// </summary>
    /// <param name="services"></param>
    /// <returns></returns>
    public static IServiceCollection RegisterCommands(this IServiceCollection services)
    {
      services.AddSingleton<Common>();
      services.AddSingleton<Init>();
      services.AddSingleton<InitReversed>();
      services.AddSingleton<Convert>();
      services.AddSingleton<Add>();
      services.AddSingleton<Root>();

      return services;
    }

    public static async Task<int> RunRootCommandAsync(this IServiceProvider services, string[] args)
    {
      return await services
        .GetRequiredService<DocFxHelper.CLI.Commands.Root>()
        .Get()
        .InvokeAsync(args);

    }
  }
}
