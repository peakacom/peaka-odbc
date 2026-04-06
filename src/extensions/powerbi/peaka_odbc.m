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
        Documentation.FieldDescription = "A short name that identifies this connection. Power BI stores credentials per label, so use a different label whenever you need a separate API key (e.g. ""ProjectA"", ""Production"").",
        Documentation.SampleValues = {"default"}
    ]),
    optional DSN as (type text meta [
        Documentation.FieldCaption = "DSN",
        Documentation.FieldDescription = "A User or System DSN configured in ODBC Administrator. If provided, Host and Port inside Advanced options are ignored.",
        Documentation.SampleValues = {"Peaka"}
    ]),
    optional options as (type [
        optional Host = (type nullable text meta [
            Documentation.FieldCaption = "Host",
            Documentation.FieldDescription = "Peaka host. Used only when DSN is empty. Default: dbc.peaka.studio (US) or dbc.eu.peaka.studio (EU).",
            Documentation.SampleValues = {"dbc.peaka.studio"}
        ]),
        optional Port = (type nullable text meta [
            Documentation.FieldCaption = "Port",
            Documentation.FieldDescription = "Peaka port. Used only when DSN is empty. Default: 4567.",
            Documentation.SampleValues = {"4567"}
        ]),
        optional Catalog = (type nullable text meta [
            Documentation.FieldCaption = "Catalog",
            Documentation.FieldDescription = "Catalog / database name. Leave blank to browse all catalogs."
        ]),
        optional ConnectionString = (type nullable text meta [
            Documentation.FieldCaption = "Connection String (non-credential properties)",
            Documentation.FieldDescription = "Additional ODBC connection string properties in Key=Value; format. These are merged into the connection after Host/Port, before SSL settings. SSL-related keys are overridden when Allow Self-Signed Certificate is enabled.",
            Documentation.SampleValues = {"RemoveTypeNameParameters=1;"}
        ]),
        optional AllowSelfSignedCert = (type nullable logical meta [
            Documentation.FieldCaption = "Allow Self-Signed Certificate",
            Documentation.FieldDescription = "When enabled, SSL is turned on and the driver accepts self-signed or otherwise untrusted server certificates. Sets SSL=1, AllowSelfSignedServerCert=1, AllowInvalidCACert=1 and AllowHostNameCNMismatch=1. These override any SSL keys supplied in the Connection String field. Default: false."
        ])
    ] meta [
        Documentation.FieldCaption = "Advanced options"
    ])
)
as table meta [
    Documentation.Name = "Peaka",
    Documentation.LongDescription = "Peaka Connector for Power BI"
];

InputImpl = (Label as text, optional DSN as text, optional options as record) =>
    let
        // Label is a required parameter whose sole purpose is to make the Power BI
        // data source path unique: credentials are stored per label so different API
        // keys can be used by giving each connection a distinct label.
        // The value of Label has no effect on the actual ODBC connection.

        // Determine which authentication method the user chose in the Power BI
        // credential dialog:
        //   "Key"      — user entered a Project API Key; pass it as JWT to the driver.
        //   "Implicit" — use whatever authentication is already configured in the DSN
        //                (e.g. JWT Authentication with an Access Token set directly in
        //                ODBC Administrator). No credentials are forwarded from Power BI.
        Credential = Extension.CurrentCredential(),
        AuthKind   = Credential[AuthenticationKind],

        // ── Extract values from the optional options record ──────────────────────
        Opt = if options <> null then options else [],

        ExtHost    = if Record.HasFields(Opt, "Host")             then Opt[Host]             else null,
        ExtPort    = if Record.HasFields(Opt, "Port")             then Opt[Port]             else null,
        ExtCatalog = if Record.HasFields(Opt, "Catalog")          then Opt[Catalog]          else null,
        ExtCS      = if Record.HasFields(Opt, "ConnectionString") then Opt[ConnectionString] else null,
        SelfSigned = Record.HasFields(Opt, "AllowSelfSignedCert") and Opt[AllowSelfSignedCert] = true,

        // ── Determine connection mode ─────────────────────────────────────────────
        // Priority:
        //   1. DSN filled                  → DSN mode  (Host/Port ignored)
        //   2. DSN empty, Host or Port set → Direct mode (no DSN needed)
        //   3. All empty                   → Default DSN "Peaka" (created by installer)
        HasDSN  = DSN     <> null and Text.Length(Text.Trim(DSN))     > 0,
        HasHost = ExtHost <> null and Text.Length(Text.Trim(ExtHost)) > 0,
        HasPort = ExtPort <> null and Text.Length(Text.Trim(ExtPort)) > 0,

        EffectiveHost = if HasHost then Text.Trim(ExtHost) else "dbc.peaka.studio",
        EffectivePort = if HasPort then Text.Trim(ExtPort) else "4567",

        BaseConnectionString =
            if HasDSN then
                [ DSN = Text.Trim(DSN) ]
            else if HasHost or HasPort then
                [ Driver = "Peaka ODBC Driver", Host = EffectiveHost, Port = EffectivePort ]
            else
                [ DSN = "Peaka" ],

        // ── Parse the free-text Connection String field ───────────────────────────
        // Accepts semicolon-separated Key=Value pairs, e.g. "RemoveTypeNameParameters=1;"
        // Unknown or misspelled keys are passed through as-is to the driver.
        ParseCSOptions = (cs as nullable text) as record =>
            if cs = null or Text.Length(Text.Trim(cs)) = 0 then
                []
            else
                let
                    Pairs   = List.Select(Text.Split(cs, ";"), each Text.Length(Text.Trim(_)) > 0),
                    KVPairs = List.Transform(Pairs, each
                        let
                            EqPos = Text.PositionOf(_, "="),
                            Key   = Text.Trim(Text.Start(_, EqPos)),
                            Val   = Text.Trim(Text.Middle(_, EqPos + 1))
                        in
                            {Key, Val}
                    ),
                    Result = Record.FromList(
                        List.Transform(KVPairs, each _{1}),
                        List.Transform(KVPairs, each _{0})
                    )
                in
                    Result,

        UserOptions = ParseCSOptions(ExtCS),

        // ── SSL / self-signed certificate settings ────────────────────────────────
        // Applied after UserOptions so they override any SSL keys the user may have
        // set manually in the Connection String field.
        SslSettings = if SelfSigned then [
            SSL                       = "1",
            AllowSelfSignedServerCert = "1",
            AllowInvalidCACert        = "1",
            AllowHostNameCNMismatch   = "1"
        ] else [],

        CatalogSettings =
            if ExtCatalog <> null and Text.Length(Text.Trim(ExtCatalog)) > 0
            then [ Catalog = Text.Trim(ExtCatalog) ]
            else [],

        // Fixed application identifier — hardcoded, not user-configurable.
        AppName = [ ApplicationName = "Power BI Extension Peaka 1.0.0" ],

        // Final connection string: base → app name → user extras → SSL override → catalog
        ConnectionString = BaseConnectionString & AppName & UserOptions & SslSettings & CatalogSettings,

        // ── ODBC base options ─────────────────────────────────────────────────────
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

        // ── Credential options ────────────────────────────────────────────────────
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
            json  = Json.Document(dataSourcePath),
            Label = json[Label],
            DSN   = if Record.HasFields(json, "DSN") then json[DSN] else null
        in
            { "Peaka.Databases", Label, DSN },

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
