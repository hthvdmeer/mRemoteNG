using System;
using mRemoteNG.App;
using mRemoteNG.App.Info;
using mRemoteNG.UI.Forms;
using System.IO;
using System.Xml;
using mRemoteNG.Messages;
using mRemoteNG.Security;
using mRemoteNG.Tools;
using mRemoteNG.UI.Controls;
using System.Runtime.Versioning;

namespace mRemoteNG.Config.Settings
{
    [SupportedOSPlatform("windows")]
    public class ExternalAppsLoader
    {
        private readonly FrmMain _mainForm;
        private readonly MessageCollector _messageCollector;
        private readonly ExternalToolsToolStrip _externalToolsToolStrip;

        public ExternalAppsLoader(FrmMain mainForm, MessageCollector messageCollector, ExternalToolsToolStrip externalToolsToolStrip)
        {
            if (mainForm == null)
                throw new ArgumentNullException(nameof(mainForm));
            if (messageCollector == null)
                throw new ArgumentNullException(nameof(messageCollector));
            if (externalToolsToolStrip == null)
                throw new ArgumentNullException(nameof(externalToolsToolStrip));

            _mainForm = mainForm;
            _messageCollector = messageCollector;
            _externalToolsToolStrip = externalToolsToolStrip;
        }


        private static string ExtAppsPath =>
            Path.Combine(
                ProgramRoot.ConfigFileDirectory ?? SettingsFileInfo.SettingsPath,
                SettingsFileInfo.ExtAppsFilesName);

        public void LoadExternalAppsFromXML()
        {
            string extAppsPath = ExtAppsPath;
            XmlDocument xDom;
            if (File.Exists(extAppsPath))
            {
                _messageCollector.AddMessage(MessageClass.InformationMsg, $"Loading External Apps from: {extAppsPath}", true);
                xDom = SecureXmlHelper.LoadXmlFromFile(extAppsPath);
            }
#if !PORTABLE
            else if (ProgramRoot.ConfigFileDirectory == null)
            {
                string oldPath = Path.Combine(Environment.GetFolderPath(Environment.SpecialFolder.LocalApplicationData), GeneralAppInfo.ProductName, SettingsFileInfo.ExtAppsFilesName);
                if (File.Exists(oldPath))
                {
                    _messageCollector.AddMessage(MessageClass.InformationMsg, $"Loading External Apps from: {oldPath}", true);
                    xDom = SecureXmlHelper.LoadXmlFromFile(oldPath);
                }
                else
                {
                    _messageCollector.AddMessage(MessageClass.WarningMsg, "Loading External Apps failed: Could not FIND file!");
                    return;
                }
            }
#endif
            else
            {
                _messageCollector.AddMessage(MessageClass.WarningMsg, "Loading External Apps failed: Could not FIND file!");
                return;
            }

            if (xDom.DocumentElement == null)
            {
                _messageCollector.AddMessage(MessageClass.WarningMsg, "Loading External Apps failed: Could not LOAD file!");
                return;
            }

            foreach (XmlElement xEl in xDom.DocumentElement.ChildNodes)
            {
                ExternalTool extA = new()
                {
                    DisplayName = xEl.Attributes["DisplayName"].Value,
                    FileName = xEl.Attributes["FileName"].Value,
                    Arguments = xEl.Attributes["Arguments"].Value
                };

                // check before, since old save files won't have this set
                if (xEl.HasAttribute("WorkingDir"))
                    extA.WorkingDir = xEl.Attributes["WorkingDir"].Value;
                if (xEl.HasAttribute("RunElevated"))
                    extA.RunElevated = bool.Parse(xEl.Attributes["RunElevated"].Value);

                if (xEl.HasAttribute("WaitForExit"))
                {
                    extA.WaitForExit = bool.Parse(xEl.Attributes["WaitForExit"].Value);
                }

                if (xEl.HasAttribute("TryToIntegrate"))
                {
                    extA.TryIntegrate = bool.Parse(xEl.Attributes["TryToIntegrate"].Value);
                }

                if (xEl.HasAttribute("ShowOnToolbar"))
                {
                    extA.ShowOnToolbar = bool.Parse(xEl.Attributes["ShowOnToolbar"].Value);
                }

                _messageCollector.AddMessage(MessageClass.InformationMsg,
                                             $"Adding External App: {extA.DisplayName} {extA.FileName} {extA.Arguments}",
                                             true);
                Runtime.ExternalToolsService.ExternalTools.Add(extA);
            }

            _externalToolsToolStrip.SwitchToolBarText(Properties.Settings.Default.ExtAppsTBShowText);
            _externalToolsToolStrip.AddExternalToolsToToolBar();
        }
    }
}