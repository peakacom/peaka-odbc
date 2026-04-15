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
    Documentation.LongDescription = "Peaka Connector for Power BI — build __BUILD_DATE__"
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

        // ── Driver defaults ───────────────────────────────────────────────
        // RemoveTypeNameParameters strips precision/scale suffixes from type
        // names reported by SQLGetTypeInfo (e.g. "varchar(65535)" → "varchar").
        // Without this, Power BI cannot match driver types to its own type
        // system and query folding breaks in Direct Query mode.
        DriverDefaults = [
            RemoveTypeNameParameters = "1"
        ],

        // Final connection string: base → app name → driver defaults → user extras → SSL override → catalog
        // User extras come AFTER driver defaults so that the user can still
        // override RemoveTypeNameParameters if they have a reason to.
        ConnectionString = BaseConnectionString & AppName & DriverDefaults & UserOptions & SslSettings & CatalogSettings,

        // ── SQLColumns override ───────────────────────────────────────────
        // Two problems are solved here:
        //
        // 1. TYPE_NAME cleanup — The Simba ODBC driver may report type names
        //    with precision/scale suffixes (e.g. "varchar(65535)",
        //    "decimal(38,18)", "timestamp with time zone (6)").  Power BI
        //    needs pure type names to match SQLGetTypeInfo entries.
        //
        // 2. Trino-only types mapped to ODBC equivalents — Types like uuid,
        //    "timestamp with time zone" and "time with time zone" have no
        //    entry in Power BI's type map.  We remap them to well-known ODBC
        //    types so that query folding can succeed:
        //      uuid                       → varchar   (text)
        //      timestamp with time zone   → timestamp (datetime)
        //      time with time zone        → time      (time)
        //
        // NOTE: We intentionally do NOT modify DATA_TYPE or other numeric
        // columns.  Power BI reads SQLColumns results by ordinal position;
        // any column reordering (e.g. via AddColumn/RemoveColumns) causes
        // FormatException in OdbcColumnInfoCollection.EnsureInitialized.
        // Only Table.TransformColumns (in-place, order-preserving) is safe.
        SQLColumns = (catalogName, schemaName, tableName, columnName, source) =>
            let
                FixTypeName = (typeName) =>
                    if Text.StartsWith(typeName, "array") then
                        "array"
                    else if Text.StartsWith(typeName, "row") then
                        "row"
                    else if Text.StartsWith(typeName, "json") then
                        "json"
                    else if Text.StartsWith(typeName, "map") then
                        "map"
                    else if Text.StartsWith(typeName, "uuid") then
                        "varchar"
                    else if Text.StartsWith(typeName, "varchar") then
                        "varchar"
                    else if Text.StartsWith(typeName, "char") then
                        "char"
                    else if Text.StartsWith(typeName, "decimal") then
                        "decimal"
                    else if Text.StartsWith(typeName, "timestamp") and Text.Contains(typeName, "with time zone") then
                        "varchar"
                    else if Text.StartsWith(typeName, "time") and Text.Contains(typeName, "with time zone") then
                        "varchar"
                    else if Text.StartsWith(typeName, "timestamp") then
                        "timestamp"
                    else if Text.StartsWith(typeName, "time") then
                        "time"
                    else
                        typeName,

                #"FixedTypeNameTable" = Table.TransformColumns(source, {
                    { "TYPE_NAME", FixTypeName }
                })
            in
                #"FixedTypeNameTable",

        // ── SQLGetTypeInfo override ───────────────────────────────────────
        // Power BI matches SQLColumns rows to SQLGetTypeInfo rows by BOTH
        // TYPE_NAME and DATA_TYPE.  The Simba driver reports timestamp with
        // time zone and time with time zone as STRING types (DATA_TYPE 12,
        // ProviderType 13).  If we renamed them to "timestamp" / "time",
        // Power BI would find the real "timestamp" entry (DATA_TYPE 93)
        // first, hit a DATA_TYPE mismatch, and refuse to fold.
        //
        // Since the driver already returns these values as strings (e.g.
        // "2024-01-27 18:59:33.000000 UTC"), the correct mapping is
        // "varchar" — matching the driver's actual behavior.  The same
        // rename must happen in BOTH SQLGetTypeInfo and SQLColumns so
        // that TYPE_NAME + DATA_TYPE pair matches on both sides.
        SQLGetTypeInfo = (types) =>
            let
                FixTypeName = (typeName) =>
                    if Text.StartsWith(typeName, "timestamp") and Text.Contains(typeName, "with time zone") then
                        "varchar"
                    else if Text.StartsWith(typeName, "time") and Text.Contains(typeName, "with time zone") then
                        "varchar"
                    else if Text.StartsWith(typeName, "uuid") then
                        "varchar"
                    else
                        typeName,

                #"FixedTypes" = Table.TransformColumns(types, {
                    { "TYPE_NAME", FixTypeName }
                })
            in
                #"FixedTypes",

        // ── AstVisitor ───────────────────────────────────────────────────────
        // Trino does not support the T-SQL TOP clause; it uses LIMIT/OFFSET.
        // Power BI generates TOP when SupportsTop is true.  This visitor
        // rewrites TOP N into LIMIT N (with optional OFFSET) so that the
        // generated SQL is valid Trino syntax and query folding succeeds.
        AstVisitor = [
            LimitClause = (skip, take) =>
                let
                    offset = if (skip <> null and skip > 0) then Text.Format("OFFSET #{0} ROWS", {skip}) else "",
                    limit  = if (take <> null) then Text.Format("LIMIT #{0}", {take}) else ""
                in
                    [
                        Text = Text.Format("#{0} #{1}", {offset, limit}),
                        Location = "AfterQuerySpecification"
                    ]
        ],

        // ── ODBC base options ─────────────────────────────────────────────────────
        BaseOptions = [
            HierarchicalNavigation  = true,
            HideNativeQuery         = false,
            TolerateConcatOverflow  = true,
            SqlCompatibleWindowsAuth = false,
            ClientConnectionPooling = true,
            SoftNumbers             = true,

            // Handlers for ODBC driver capabilities
            AstVisitor = AstVisitor,
            SQLColumns = SQLColumns,
            SQLGetTypeInfo = SQLGetTypeInfo,

            // Let Power BI call SQLCancel/SQLFreeHandle instead of abandoning
            // the connection when a query is no longer needed.
            CancelQueryExplicitly = true,

            SqlCapabilities = [
                PrepareStatements            = true,
                SupportsTop                  = true,
                Sql92Conformance             = 8,
                SupportsNumericLiterals      = true,
                SupportsStringLiterals       = true,
                SupportsOdbcDateLiterals     = true,
                SupportsOdbcTimeLiterals     = true,
                SupportsOdbcTimestampLiterals = true,
                Sql92Translation             = "PassThrough",
                // FractionalSecondsScale tells Power BI the maximum precision
                // for fractional seconds in TIMESTAMP literals.  Without this,
                // Power BI may refuse to fold timestamp comparisons because it
                // cannot determine the driver's precision capability.
                FractionalSecondsScale       = 3
            ],

            // SQLGetInfo overrides — inform Power BI about the full set of
            // predicates and aggregate functions supported by Trino so that
            // more expressions can be folded to the data source.
            SQLGetInfo = [
                SQL_SQL92_PREDICATES   = 0x00003F07,
                SQL_AGGREGATE_FUNCTIONS = 0x7F
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
    ButtonText = { "Peaka", "Connect to Peaka — build __BUILD_DATE__" },
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
