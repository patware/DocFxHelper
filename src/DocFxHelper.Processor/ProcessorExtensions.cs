using Microsoft.Extensions.DependencyInjection;
using System;
using System.Collections.Generic;
using System.Linq;
using System.Text;
using System.Threading.Tasks;

namespace DocFxHelper.Processor
{
  public static class ProcessorExtensions
  {
    /// <summary>
    /// Adds every Processor to the ServiceCollection
    /// </summary>
    /// <param name="services"></param>
    /// <returns></returns>
    public static IServiceCollection RegisterProcessors(this IServiceCollection services)
    {
      services.AddSingleton<AdoWiki>();

      return services;
    }
  }
}
