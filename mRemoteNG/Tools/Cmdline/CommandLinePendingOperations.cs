using mRemoteNG.Connection;

namespace mRemoteNG.Tools.Cmdline
{
    public static class CommandLinePendingOperations
    {
        public static string ConnectOnStartup { get; set; }
        public static ConnectionInfo AddConnectionOnStartup { get; set; }
        public static bool CollapseOnStartup { get; set; }
    }
}
