using System;
using System.Collections.Generic;
using System.Drawing;
using System.IO;
using System.Runtime.Versioning;
using System.Windows.Forms;
using mRemoteNG.App.Info;
using mRemoteNG.Connection;
using mRemoteNG.Connection.Protocol;
using mRemoteNG.Messages;
using mRemoteNG.Properties;
using mRemoteNG.Resources.Language;


namespace mRemoteNG.Tools.Cmdline
{
    [SupportedOSPlatform("windows")]
    public class StartupArgumentsInterpreter
    {
        private readonly MessageCollector _messageCollector;

        public StartupArgumentsInterpreter(MessageCollector messageCollector)
        {
            if (messageCollector == null)
                throw new ArgumentNullException(nameof(messageCollector));

            _messageCollector = messageCollector;
        }

        public void ParseArguments(IEnumerable<string> cmdlineArgs)
        {
            //if (!cmdlineArgs.Any()) return;
            _messageCollector.AddMessage(MessageClass.DebugMsg, "Parsing cmdline arguments");

            try
            {
                CmdArgumentsInterpreter args = new(cmdlineArgs);

                ParseResetPositionArg(args);
                ParseResetPanelsArg(args);
                ParseResetToolbarArg(args);
                ParseNoReconnectArg(args);
                ParseCustomConnectionPathArg(args);
                ParseConnectArg(args);
                ParseAddConnectionArg(args);
                ParseCollapseArg(args);
            }
            catch (Exception ex)
            {
                _messageCollector.AddExceptionMessage(Language.CommandLineArgsCouldNotBeParsed, ex, logOnly: false);
            }
        }

        private void ParseResetPositionArg(CmdArgumentsInterpreter args)
        {
            if (args["resetpos"] == null && args["rp"] == null && args["reset"] == null) return;
            _messageCollector.AddMessage(MessageClass.DebugMsg, "Cmdline arg: Resetting window positions.");
            Properties.App.Default.MainFormKiosk = false;
            int newWidth = 900;
            int newHeight = 600;
            int newX = Screen.PrimaryScreen.WorkingArea.Width / 2 - newWidth / 2;
            int newY = Screen.PrimaryScreen.WorkingArea.Height / 2 - newHeight / 2;
            Properties.App.Default.MainFormLocation = new Point(newX, newY);
            Properties.App.Default.MainFormSize = new Size(newWidth, newHeight);
            Properties.App.Default.MainFormState = FormWindowState.Normal;
        }

        private void ParseResetPanelsArg(CmdArgumentsInterpreter args)
        {
            if (args["resetpanels"] == null && args["rpnl"] == null && args["reset"] == null) return;
            _messageCollector.AddMessage(MessageClass.DebugMsg, "Cmdline arg: Resetting panels");
            Properties.App.Default.ResetPanels = true;
        }

        private void ParseResetToolbarArg(CmdArgumentsInterpreter args)
        {
            if (args["resettoolbar"] == null && args["rtbr"] == null && args["reset"] == null) return;
            _messageCollector.AddMessage(MessageClass.DebugMsg, "Cmdline arg: Resetting toolbar position");
            Properties.App.Default.ResetToolbars = true;
        }

        private void ParseNoReconnectArg(CmdArgumentsInterpreter args)
        {
            if (args["noreconnect"] == null && args["norc"] == null) return;
            _messageCollector.AddMessage(MessageClass.DebugMsg,
                                         "Cmdline arg: Disabling reconnection to previously connected hosts");
            Properties.OptionsAdvancedPage.Default.NoReconnect = true;
        }

        private void ParseConnectArg(CmdArgumentsInterpreter args)
        {
            string connectName = args["connect"] ?? args["cn"];
            if (connectName == null) return;
            _messageCollector.AddMessage(MessageClass.DebugMsg, $"Cmdline arg: will open connection '{connectName}' after startup");
            CommandLinePendingOperations.ConnectOnStartup = connectName;
        }

        private void ParseAddConnectionArg(CmdArgumentsInterpreter args)
        {
            if (args["add-connection"] == null && args["addcon"] == null) return;

            string name = args["name"];
            string host = args["host"];
            string protocolStr = args["protocol"] ?? args["proto"] ?? "RDP";
            string username = args["username"] ?? args["user"] ?? "";
            string password = args["password"] ?? args["pass"] ?? "";
            string domain = args["domain"] ?? args["dom"] ?? "";
            string portStr = args["port"];
            string description = args["description"] ?? args["desc"] ?? "";

            if (string.IsNullOrEmpty(name) || string.IsNullOrEmpty(host))
            {
                _messageCollector.AddMessage(MessageClass.WarningMsg,
                    "Cmdline --add-connection requires --name and --host");
                return;
            }

            _messageCollector.AddMessage(MessageClass.DebugMsg,
                $"Cmdline arg: will add connection '{name}' ({host}) after startup");

            ConnectionInfo newConnection = new()
            {
                Name = name,
                Hostname = host,
                Username = username,
                Password = password,
                Domain = domain,
                Description = description,
            };

            if (Enum.TryParse(protocolStr, ignoreCase: true, out ProtocolType protocol))
                newConnection.Protocol = protocol;
            else
                _messageCollector.AddMessage(MessageClass.WarningMsg,
                    $"Cmdline --add-connection: unknown protocol '{protocolStr}', defaulting to RDP");

            if (int.TryParse(portStr, out int port))
                newConnection.Port = port;

            CommandLinePendingOperations.AddConnectionOnStartup = newConnection;
        }

        private void ParseCollapseArg(CmdArgumentsInterpreter args)
        {
            if (args["collapse"] == null && args["cl"] == null) return;
            _messageCollector.AddMessage(MessageClass.DebugMsg, "Cmdline arg: collapsing all folders on startup");
            CommandLinePendingOperations.CollapseOnStartup = true;
        }

        private void ParseCustomConnectionPathArg(CmdArgumentsInterpreter args)
        {
            string consParam = "";
            if (args["cons"] != null)
                consParam = "cons";
            if (args["c"] != null)
                consParam = "c";

            if (string.IsNullOrEmpty(consParam)) return;
            _messageCollector.AddMessage(MessageClass.DebugMsg, "Cmdline arg: loading connections from a custom path");
            if (File.Exists(args[consParam]) == false)
            {
                if (File.Exists(Path.Combine(GeneralAppInfo.HomePath, args[consParam])))
                {
                    Properties.OptionsBackupPage.Default.LoadConsFromCustomLocation = true;
                    Properties.OptionsBackupPage.Default.BackupLocation = Path.Combine(GeneralAppInfo.HomePath, args[consParam]);
                    return;
                }

                if (!File.Exists(Path.Combine(ConnectionsFileInfo.DefaultConnectionsPath, args[consParam]))) return;
                Properties.OptionsBackupPage.Default.LoadConsFromCustomLocation = true;
                Properties.OptionsBackupPage.Default.BackupLocation = Path.Combine(ConnectionsFileInfo.DefaultConnectionsPath, args[consParam]);
            }
            else
            {
                Properties.OptionsBackupPage.Default.LoadConsFromCustomLocation = true;
                Properties.OptionsBackupPage.Default.BackupLocation = args[consParam];
            }
        }
    }
}