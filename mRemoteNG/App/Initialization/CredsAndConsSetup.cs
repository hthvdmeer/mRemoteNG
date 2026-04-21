using System.IO;
using System.Runtime.Versioning;
using mRemoteNG.Config.Connections;
using mRemoteNG.Properties;
using mRemoteNG.App;

namespace mRemoteNG.App.Initialization
{
    [SupportedOSPlatform("windows")]
    public class CredsAndConsSetup
    {
        public void LoadCredsAndCons()
        {
            new SaveConnectionsOnEdit(Runtime.ConnectionsService);

            Logger.Instance.Log?.Info($"[CredsAndConsSetup] FirstStart={Properties.App.Default.FirstStart} UseSQLServer={Properties.OptionsDBsPage.Default.UseSQLServer}");
            if (Properties.App.Default.FirstStart && !Properties.OptionsBackupPage.Default.LoadConsFromCustomLocation && !File.Exists(Runtime.ConnectionsService.GetStartupConnectionFileName()))
                Runtime.ConnectionsService.NewConnectionsFile(Runtime.ConnectionsService.GetStartupConnectionFileName());

            Logger.Instance.Log?.Info("[CredsAndConsSetup] calling Runtime.LoadConnections");
            Runtime.LoadConnections();
            Logger.Instance.Log?.Info("[CredsAndConsSetup] Runtime.LoadConnections done");
        }
    }
}