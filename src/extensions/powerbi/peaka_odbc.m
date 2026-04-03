//==================================================================================================
//==================================================================================================
///  @file peaka_odbc.pq
///
///  Implementation of Peaka ODBC Power BI connector
///
///  Copyright (C) 2024 Peaka Technologies.
//==================================================================================================

section Peaka;

[DataSource.Kind="Peaka", Publish="Peaka.UI"]
shared Peaka.Databases = Value.ReplaceType(InputImpl, InputType);

InputType = type function (
    Label as (type text meta [
        Documentation.FieldCaption = "Connection Label",
        Documentation.FieldDescription = "A short name that identifies this connection. Power BI stores credentials per Label, so use a different label each time you need a separate API key (e.g. ""ProjectA"", ""Production"").",
        Documentation.SampleValues = {"default"}
    ]),
    optional DSN as (type text meta [
        Documentation.FieldCaption = "DSN",
        Documentation.FieldDescription = "A User or System DSN configured in ODBC Administrator. If provided, Host and Port are ignored.",
        Documentation.SampleValues = {"Peaka"}
    ]),
    optional Host as (type text meta [
        Documentation.FieldCaption = "Host",
        Documentation.FieldDescription = "Peaka host. Used only when DSN is empty. Default: dbc.peaka.studio (US) or dbc.eu.peaka.studio (EU).",
        Documentation.SampleValues = {"dbc.peaka.studio"}
    ]),
    optional Port as (type text meta [
        Documentation.FieldCaption = "Port",
        Documentation.FieldDescription = "Peaka port. Used only when DSN is empty. Default: 4567.",
        Documentation.SampleValues = {"4567"}
    ]),
    optional Catalog as (type text meta [
        Documentation.FieldCaption = "Catalog",
        Documentation.FieldDescription = "Catalog / database name. Leave blank to browse all catalogs."
    ]),
    optional options as (type [
        optional AllowSelfSignedCert = (type nullable logical meta [
            Documentation.FieldCaption = "Allow Self-Signed Certificate",
            Documentation.FieldDescription = "When enabled, SSL is turned on and the driver accepts self-signed or otherwise untrusted server certificates. Sets SSL=1, AllowSelfSignedServerCert=1, AllowInvalidCACert=1 and AllowHostNameCNMismatch=1 on the connection. Default: false."
        ])
    ] meta [
        Documentation.FieldCaption = "Advanced options"
    ])
)
as table meta [
    Documentation.Name = "Peaka",
    Documentation.LongDescription = "Peaka Connector for Power BI"
];

InputImpl = (Label as text, optional DSN as text, optional Host as text, optional Port as text, optional Catalog as text, optional options as record) =>
    let
        // Label is a required parameter whose sole purpose is to make the Power BI
        // data source path unique: credentials are stored per Label so different API
        // keys can be used with the same DSN or host by giving each connection a
        // distinct label. The value of Label has no effect on the actual ODBC connection.

        // Determine which authentication method the user chose in the Power BI
        // credential dialog:
        //   "Key"      — user entered a Project API Key; pass it as JWT to the driver.
        //   "Implicit" — use whatever authentication is already configured in the DSN
        //                (e.g. JWT Authentication with an Access Token set directly in
        //                ODBC Administrator). No credentials are forwarded from Power BI.
        Credential = Extension.CurrentCredential(),
        AuthKind   = Credential[AuthenticationKind],

        // Classify which connection mode to use:
        //   DSN mode    — DSN field is non-empty; Host/Port are ignored.
        //   Direct mode — DSN is empty but Host or Port is provided; connects
        //                 straight to the driver without any DSN entry.
        //   Default     — all three fields are empty; fall back to the "Peaka"
        //                 System DSN that the installer creates automatically.
        //
        // RemoveTypeNameParameters = 1 is required for DirectQuery compatibility with
        // Trino: without it Power BI may pass type-name parameters that Trino cannot
        // handle. Hardcoding it here removes the need for manual ODBC Administrator setup.
        HasDSN  = DSN  <> null and Text.Length(Text.Trim(DSN))  > 0,
        HasHost = Host <> null and Text.Length(Text.Trim(Host)) > 0,
        HasPort = Port <> null and Text.Length(Text.Trim(Port)) > 0,

        EffectiveHost = if HasHost then Text.Trim(Host) else "dbc.peaka.studio",
        EffectivePort = if HasPort then Text.Trim(Port) else "4567",

        BaseConnectionString =
            if HasDSN then
                // DSN mode
                [ DSN = Text.Trim(DSN), RemoveTypeNameParameters = 1 ]
            else if HasHost or HasPort then
                // Direct mode: bypass DSN, connect via driver + host + port
                [ Driver = "Peaka ODBC Driver", Host = EffectiveHost, Port = EffectivePort, RemoveTypeNameParameters = 1 ]
            else
                // Default: use the "Peaka" System DSN created by the installer
                [ DSN = "Peaka", RemoveTypeNameParameters = 1 ],

        // When "Allow Self-Signed Certificate" is checked, enable SSL and instruct
        // the driver to accept self-signed or otherwise untrusted server certificates.
        SelfSigned = options <> null
                     and Record.HasFields(options, "AllowSelfSignedCert")
                     and options[AllowSelfSignedCert] = true,

        SslSettings = if SelfSigned then [
            SSL                      = 1,
            AllowSelfSignedServerCert = 1,
            AllowInvalidCACert        = 1,
            AllowHostNameCNMismatch   = 1
        ] else [],

        ConnectionString =
            BaseConnectionString
            & SslSettings
            & (if Catalog <> null and Text.Length(Text.Trim(Catalog)) > 0
               then [Catalog = Catalog]
               else []),

        // Base ODBC options, independent of authentication method.
        BaseOptions = [
            HierarchicalNavigation  = true,
            HideNativeQuery         = false,
            TolerateConcatOverflow  = true,
            SqlCompatibleWindowsAuth = false,
            ClientConnectionPooling = true,
            SoftNumbers             = true,
            SqlCapabilities = [
                PrepareStatements            = true,
                SupportsTop                  = true,
                Sql92Conformance             = 8,
                SupportsNumericLiterals      = true,
                SupportsStringLiterals       = true,
                SupportsOdbcDateLiterals     = true,
                SupportsOdbcTimeLiterals     = true,
                SupportsOdbcTimestampLiterals = true,
                Sql92Translation             = "PassThrough"
            ]
        ],

        // When "API Key" is chosen: forward the key as a JWT token so the driver
        // authenticates with Peaka regardless of what the DSN has configured.
        // When "Anonymous" is chosen: omit CredentialConnectionString entirely so
        // the driver falls back to the authentication settings stored in the DSN.
        CredentialOptions =
            if AuthKind = "Key" then [
                CredentialConnectionString = [
                    AuthenticationType = "JWT Authentication",
                    AccessToken        = Credential[Key]
                ]
            ]
            else [],

        Connect = Odbc.DataSource(ConnectionString, BaseOptions & CredentialOptions)
    in
        Connect;

// Data Source Kind description
Peaka = [

    TestConnection = (dataSourcePath) =>
        let
            json    = Json.Document(dataSourcePath),
            Label   = json[Label],
            DSN     = if Record.HasFields(json, "DSN")     then json[DSN]     else null,
            Host    = if Record.HasFields(json, "Host")    then json[Host]    else null,
            Port    = if Record.HasFields(json, "Port")    then json[Port]    else null,
            Catalog = if Record.HasFields(json, "Catalog") then json[Catalog] else null
        in
            { "Peaka.Databases", Label, DSN, Host, Port, Catalog },

    // Two authentication options are offered in Power BI's credential dialog:
    //
    //   "API Key"   — Power BI securely stores the Project API Key and forwards it
    //                 to the driver as a JWT token on every connection. Recommended
    //                 when the DSN is shared or does not have credentials configured.
    //
    //   "Anonymous" — Power BI sends no credentials. The Simba driver uses whatever
    //                 authentication is configured directly in the DSN (e.g. JWT
    //                 Authentication with an Access Token set in ODBC Administrator).
    //                 Useful when credentials are managed at the DSN level.
    Authentication = [
        Key = [
            KeyLabel = "Project API Key"
        ],
        Implicit = []
    ]
];

// Data Source UI publishing description
Peaka.UI = [
    Beta = false,
    Category = "Database",
    ButtonText = { "Peaka", "Connect to Peaka" },
    SupportsDirectQuery = true,
    SourceImage = Peaka.Icons,
    SourceTypeImage = Peaka.Icons,
    NativeQueryProperties = [
        NavigationSteps = {
            [
                Indices = {
                    [
                        FieldDisplayName = "Database",
                        IndexName = "Name"
                    ],
                    [
                        ConstantValue = "Database",
                        IndexName = "Kind"
                    ]
                },
                FieldAccess = "Data"
            ]
        }
    ]
];

Peaka.Icons = [
    Icon16 = { Extension.Contents("peaka-icon.png"), Extension.Contents("peaka-icon.png"), Extension.Contents("peaka-icon.png"), Extension.Contents("peaka-icon.png") },
    Icon32 = { Extension.Contents("peaka-icon.png"), Extension.Contents("peaka-icon.png"), Extension.Contents("peaka-icon.png"), Extension.Contents("peaka-icon.png") }
];
