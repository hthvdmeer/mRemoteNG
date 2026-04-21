# CLAUDE.md

This file provides guidance to Claude Code (claude.ai/code) when working with code in this repository.

## Project

mRemoteNG is an open-source, multi-protocol, tabbed remote connections manager for Windows (.NET 10.0, WinForms + WPF). It supports RDP, VNC, SSH, Telnet, HTTP/HTTPS, rlogin, Raw Socket, PowerShell remoting, and AnyDesk connections.

## Build & Test Commands

```powershell
# Restore packages
dotnet restore

# Build (x64)
msbuild mRemoteNG.sln -p:Configuration=Release -p:Platform=x64

# Build (ARM64)
msbuild mRemoteNG.sln -p:Configuration=Release -p:Platform=ARM64

# Self-contained publish (x64)
dotnet publish mRemoteNG/mRemoteNG.csproj --configuration "Release Self-Contained" --runtime win-x64 --self-contained true -p:Platform=x64

# Run all tests
dotnet test mRemoteNGTests/mRemoteNGTests.csproj

# Run a single test class or method
dotnet test mRemoteNGTests/mRemoteNGTests.csproj --filter "FullyQualifiedName~ClassName"
```

Dependencies are centrally managed in `Directory.Packages.props`.

## Architecture

### Solution Projects
- **mRemoteNG** — Main WinForms application
- **mRemoteNGTests** — NUnit tests (mirrors main project structure)
- **mRemoteNGSpecs** — Specification tests
- **ExternalConnectors** — External protocol connector implementations
- **ObjectListView.NetCore** — Custom list view control
- **mRemoteNGInstaller** — WiX MSI installer

### Key Directories in `mRemoteNG/`
| Directory | Purpose |
|-----------|---------|
| `App/` | Application startup and initialization |
| `Connection/` | Connection models, protocols, `ConnectionInfo`, property inheritance |
| `Config/` | XML/CSV serializers and deserializers for connection files |
| `Container/` | Folder/group node implementations |
| `Credential/` | Credential storage and repositories |
| `Security/` | Encryption, password management (BouncyCastle) |
| `Tree/` | Connection tree UI and node management |
| `UI/` | WinForms panels, `InterfaceControl` base class, settings pages |
| `Language/` | Localization resource files (`Language.resx`) |

### Property Inheritance System
Connections inherit settings from parent containers. Each inheritable property on `ConnectionInfo`/`AbstractConnectionRecord` has a matching `Inherit<PropertyName>` boolean in `ConnectionInfoInheritance.cs`. Use the `IInheritable` interface for objects supporting inheritance.

### Adding a New Connection Property (Full Checklist)
1. Add enum (if needed) in `Connection/`
2. Add property to `AbstractConnectionRecord.cs` or `ConnectionInfo.cs` with `[Category]` and `[Description]` attributes
3. Add `Inherit<PropertyName>` to `ConnectionInfoInheritance.cs`
4. Update XML serializer (`Config/Serializers/ConnectionSerializers/Xml/XmlConnectionNodeSerializer*.cs`) and deserializer
5. Update CSV serializer (`CsvConnectionsSerializerMremotengFormat.cs`)
6. Add localization entries to `Language/Language.resx`
7. Write tests in `mRemoteNGTests/Connection/`

### Serialization & Backward Compatibility
**This is critical** — old connection XML files must always load correctly. When deserializing, always handle missing attributes gracefully and provide defaults for new properties. The active XML serializer version is `XmlConnectionNodeSerializer28.cs`.

### Localization
All user-facing strings go in `Language/Language.resx`. Access via `Language.ResourceName`. Naming conventions:
- Properties: `PropertyName` (e.g., `ConnectionFrameColor`)
- Tooltips: `PropertyDescription<PropertyName>`
- Enum values: `<EnumName><Value>` (e.g., `FrameColorRed`)

## Code Style

Governed by `mRemoteNG/.editorconfig`:
- 4 spaces, CRLF, UTF-8-BOM for C# files
- Allman brace style (opening brace on its own line)
- System `using` directives sorted first
- No `this.` qualifier unless necessary
- PascalCase for classes, methods, properties, constants; camelCase or `_`-prefixed for private fields

## Testing Conventions

NUnit with NSubstitute. Test method naming: `MethodName_Scenario_ExpectedBehavior`. Use `[TestCase]` for parameterized tests. Mirror main project folder structure inside `mRemoteNGTests/`.

## External Protocol Dependencies
- PuTTY (bundled as `PuTTYNG.exe`) — SSH/Telnet
- Terminal Service Client — RDP
- SSH.NET — SSH library
- VncSharpCore — VNC
