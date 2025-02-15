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
    public static void RegisterCommands(this IServiceCollection services)
    {
      services.AddSingleton<Init>();
      services.AddSingleton<InitReversed>();
      services.AddSingleton<Root>();
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
