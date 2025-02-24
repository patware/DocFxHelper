using System;
using System.Collections.Generic;
using System.Linq;
using System.Text;
using System.Threading.Tasks;

namespace DocFxHelper.Processor
{
  public interface IProcessor<T>
  {
    Task<int> ConvertAsync(T docSpec, DirectoryInfo location, DocFxHelper.Specification.DocBuild build);

    Task<int> AddAsync(T docSpec, FileInfo docfxJson);
  }
}
