using System;
using System.Collections.Generic;
using System.CommandLine;
using System.Linq;
using System.Text;
using System.Threading.Tasks;

namespace DocFxHelper.CLI.Commands
{
  internal class Root
  {
    private Init _init;
    private InitReversed _initReversed;
    private Convert _convert;
    private Add _add;

    public Root(
      Commands.Init init, 
      Commands.InitReversed initReversed, 
      Commands.Convert convert,
      Commands.Add add)
    {
      _init = init;
      _initReversed = initReversed;
      _convert = convert;
      _add = add;
    }
    public RootCommand Get()
    {
      var cmd = new RootCommand()
      {
        _init.GetCommand(),
        _initReversed.GetCommand(),
        _convert.GetCommand(),
        _add.GetCommand()
      };

      cmd.Name = "help";
      cmd.Description = "Command line tool for performing DocFxHelper operations";

      return cmd;
    }
  }
}
