using System;
using System.Collections.Generic;
using System.Linq;
using System.Runtime.Versioning;
using System.Security;
using mRemoteNG.Config.DatabaseConnectors;
using mRemoteNG.Config.DataProviders;
using mRemoteNG.Config.Serializers;
using mRemoteNG.Config.Serializers.ConnectionSerializers.Sql;
using mRemoteNG.Config.Serializers.Versioning;
using mRemoteNG.Container;
using mRemoteNG.Security;
using mRemoteNG.Security.Authentication;
using mRemoteNG.Security.SymmetricEncryption;
using mRemoteNG.Tools;
using mRemoteNG.Tree;
using mRemoteNG.Tree.Root;

namespace mRemoteNG.Config.Connections
{
    [SupportedOSPlatform("windows")]
    public class SqlConnectionsLoader(
        IDeserializer<string, IEnumerable<LocalConnectionPropertiesModel>> localConnectionPropertiesDeserializer,
        IDataProvider<string> dataProvider) : IConnectionsLoader
    {
        private readonly IDeserializer<string, IEnumerable<LocalConnectionPropertiesModel>> _localConnectionPropertiesDeserializer = localConnectionPropertiesDeserializer.ThrowIfNull(nameof(localConnectionPropertiesDeserializer));

        private readonly IDataProvider<string> _dataProvider = dataProvider.ThrowIfNull(nameof(dataProvider));

        private Func<Optional<SecureString>> AuthenticationRequestor { get; set; } = () => MiscTools.PasswordDialog("", false);

        public ConnectionTreeModel Load()
        {
            string sqlHost = Properties.OptionsDBsPage.Default.SQLHost;
            string sqlDb = Properties.OptionsDBsPage.Default.SQLDatabaseName;
            string sqlUser = Properties.OptionsDBsPage.Default.SQLUser;

            App.Logger.Instance.Log?.Info($"[SqlConnectionsLoader.Load] START — host={sqlHost} db={sqlDb} user={sqlUser}");
            App.Runtime.MessageCollector.AddMessage(Messages.MessageClass.InformationMsg, $"SqlConnectionsLoader: connecting to {sqlHost}/{sqlDb} as {sqlUser}");

            IDatabaseConnector connector = DatabaseConnectorFactory.DatabaseConnectorFromSettings();
            SqlDataProvider dataProvider = new(connector);
            SqlDatabaseMetaDataRetriever metaDataRetriever = new();
            SqlDatabaseVersionVerifier databaseVersionVerifier = new(connector);
            LegacyRijndaelCryptographyProvider cryptoProvider = new();

            App.Runtime.MessageCollector.AddMessage(Messages.MessageClass.InformationMsg, "SqlConnectionsLoader: retrieving database metadata");
            SqlConnectionListMetaData metaData;
            try
            {
                metaData = metaDataRetriever.GetDatabaseMetaData(connector) ?? HandleFirstRun(metaDataRetriever, connector);
            }
            catch (Exception ex)
            {
                throw new Exception($"Cannot connect to SQL server {sqlHost}/{sqlDb}: {ex.Message}", ex);
            }

            App.Runtime.MessageCollector.AddMessage(Messages.MessageClass.InformationMsg, "SqlConnectionsLoader: getting decryption key");
            Optional<SecureString> decryptionKey = GetDecryptionKey(metaData);

            if (!decryptionKey.Any())
                throw new Exception("Could not load SQL connections");

            App.Runtime.MessageCollector.AddMessage(Messages.MessageClass.InformationMsg, $"SqlConnectionsLoader: verifying database version ({metaData.ConfVersion})");
            databaseVersionVerifier.VerifyDatabaseVersion(metaData.ConfVersion);

            App.Runtime.MessageCollector.AddMessage(Messages.MessageClass.InformationMsg, "SqlConnectionsLoader: loading data table");
            System.Data.DataTable dataTable = dataProvider.Load();

            App.Logger.Instance.Log?.Info($"[SqlConnectionsLoader.Load] loaded {dataTable.Rows.Count} rows from {sqlHost}/{sqlDb}");

            if (dataTable.Rows.Count == 0)
                App.Runtime.MessageCollector.AddMessage(Messages.MessageClass.WarningMsg, $"SQL database {sqlHost}/{sqlDb} is empty — no connections loaded", onlyLog: false);

            App.Runtime.MessageCollector.AddMessage(Messages.MessageClass.InformationMsg, $"SqlConnectionsLoader: deserializing {dataTable.Rows.Count} rows");
            DataTableDeserializer deserializer = new(cryptoProvider, decryptionKey.First());
            ConnectionTreeModel connectionTree = deserializer.Deserialize(dataTable);

            // Restore master password state on the root node so saves re-encrypt with the correct key.
            string decryptedProtected = cryptoProvider.Decrypt(metaData.Protected, decryptionKey.First());
            RootNodeInfo rootNode = (RootNodeInfo)connectionTree.RootNodes.First(i => i is RootNodeInfo);
            if (decryptedProtected == "ThisIsProtected")
            {
                rootNode.Password = true;
                rootNode.PasswordString = decryptionKey.First().ConvertToUnsecureString();
            }

            App.Runtime.MessageCollector.AddMessage(Messages.MessageClass.InformationMsg, "SqlConnectionsLoader: applying local connection properties");
            ApplyLocalConnectionProperties(rootNode);

            App.Runtime.MessageCollector.AddMessage(Messages.MessageClass.InformationMsg, "SqlConnectionsLoader: load complete");
            return connectionTree;
        }

        private Optional<SecureString> GetDecryptionKey(SqlConnectionListMetaData metaData)
        {
            LegacyRijndaelCryptographyProvider cryptographyProvider = new();
            string cipherText = metaData.Protected;
            PasswordAuthenticator authenticator = new(cryptographyProvider, cipherText, AuthenticationRequestor);
            bool authenticated = authenticator.Authenticate(new RootNodeInfo(RootNodeType.Connection).DefaultPassword.ConvertToSecureString());

            return authenticated ? authenticator.LastAuthenticatedPassword : Optional<SecureString>.Empty;
        }

        private void ApplyLocalConnectionProperties(ContainerInfo rootNode)
        {
            string localPropertiesXml = _dataProvider.Load();
            IEnumerable<LocalConnectionPropertiesModel> localConnectionProperties = _localConnectionPropertiesDeserializer.Deserialize(localPropertiesXml);

            rootNode
                .GetRecursiveChildList()
                .Join(localConnectionProperties,
                      con => con.ConstantID,
                      locals => locals.ConnectionId,
                      (con, locals) => new {Connection = con, LocalProperties = locals})
                .ForEach(x =>
                {
                    x.Connection.PleaseConnect = x.LocalProperties.Connected;
                    x.Connection.Favorite = x.LocalProperties.Favorite;
                    if (x.Connection is ContainerInfo container)
                        container.IsExpanded = x.LocalProperties.Expanded;
                });
        }

        private SqlConnectionListMetaData HandleFirstRun(SqlDatabaseMetaDataRetriever metaDataRetriever, IDatabaseConnector connector)
        {
	        metaDataRetriever.WriteDatabaseMetaData(new RootNodeInfo(RootNodeType.Connection), connector);
	        return metaDataRetriever.GetDatabaseMetaData(connector);
		}
    }
}