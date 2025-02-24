using Microsoft.Extensions.Logging;
using System;
using System.Collections.Generic;
using System.Linq;
using System.Text;
using System.Threading.Tasks;

namespace DocFxHelper.Specification
{
  public class AllSpecs(ILogger<AllSpecs> logger)
  {
    private readonly ILogger<AllSpecs> _logger = logger;


    public DocSpecInfo? Info { get; set; }
    public IDictionary<string, DocSpecResource> All { get; set; } = new Dictionary<string, DocSpecResource>();

    private IDictionary<string, DocSpecResource> _hierarchy = new Dictionary<string, DocSpecResource>();
    public IDictionary<string, DocSpecResource> Hierarchy
    {
      get
      {
        if (_hierarchy.Keys.Count == 0)
        {
          buildHierarchy();
        }
        return _hierarchy;
      }
    }


    private IList<DocSpecResource> _ordered = new List<DocSpecResource>();
    public IList<DocSpecResource> Ordered
    {
      get
      {
        if (_ordered.Count == 0)
        {
          buildHierarchy();
        }

        return _ordered;
      }
    }

    private IDictionary<string, DocSpecResource> _children = new Dictionary<string, DocSpecResource>();
    public IDictionary<string, DocSpecResource> Children
    {
      get
      {
        if (_children.Keys.Count == 0)
        {
          buildHierarchy();
        }

        return _children;
      }
    }

    public void Add(DocSpec docSpec)
    {
      if (docSpec is DocSpecInfo)
      {
        if (Info != null && docSpec.FileInfo != Info.FileInfo)
        {
          _logger.LogWarning("There's already a registered Info with FileInfo {fileInfo}", Info.FileInfo);
        }

        Info = docSpec as DocSpecInfo;
      }
      else if (docSpec is DocSpecResource)
      {
        var docSpecResource = (DocSpecResource)docSpec;

        if (string.IsNullOrEmpty(docSpecResource.Id))
        {
          _logger.LogWarning("{specDocsJson} has no Id, using Name {name} as Id", docSpecResource.FileInfo!.FullName, docSpecResource.Name);
          docSpecResource.Id = docSpecResource.Name;
        }

        All[docSpecResource.Id!] = docSpecResource;


      }
    }

    private void buildHierarchy()
    {
      
    }
  }
}