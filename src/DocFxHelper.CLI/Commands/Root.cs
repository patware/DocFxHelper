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

    public Root(Commands.Init init, Commands.InitReversed initReversed)
    {
      _init = init;
      _initReversed = initReversed;
    }
    public RootCommand Get()
    {
      var cmd = new RootCommand()
      {
        _init.GetCommand(),
        _initReversed.GetCommand()
      };

      cmd.Name = "help";
      cmd.Description = "Command line tool for performing DocFxHelper operations";

      return cmd;
    }
  }
}
