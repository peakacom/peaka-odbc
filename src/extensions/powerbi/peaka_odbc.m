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
    DSN as (type text meta [
        Documentation.FieldCaption = "DSN",
        Documentation.FieldDescription = "A User or System DSN configured for Peaka in ODBC Administrator.",
        Documentation.SampleValues = {"Peaka"}
    ]),
    optional Catalog as (type text meta [
        Documentation.FieldCaption = "Catalog",
        Documentation.FieldDescription = "Catalog / database name. Leave blank to browse all catalogs."
    ]),
    optional options as (type [
    ] meta [
        Documentation.FieldCaption = "Advanced options"
    ])
)
as table meta [
    Documentation.Name = "Peaka",
    Documentation.LongDescription = "Peaka Connector for Power BI"
];

InputImpl = (DSN as text, optional Catalog as text, optional options as record) =>
    let
        // Determine which authentication method the user chose in the Power BI
        // credential dialog:
        //   "Key"      — user entered a Project API Key; pass it as JWT to the driver.
        //   "Implicit" — use whatever authentication is already configured in the DSN
        //                (e.g. JWT Authentication with an Access Token set directly in
        //                ODBC Administrator). No credentials are forwarded from Power BI.
        Credential = Extension.CurrentCredential(),
        AuthKind   = Credential[AuthenticationKind],

        // Build the base connection string from the DSN.
        // RemoveTypeNameParameters = 1 is required for DirectQuery compatibility with Trino:
        // without it Power BI may pass type-name parameters that Trino cannot handle.
        // Hardcoding it here removes the need for users to configure it manually in ODBC Administrator.
        ConnectionString =
            [
                DSN = DSN,
                RemoveTypeNameParameters = 1
            ]
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
            json = Json.Document(dataSourcePath),
            DSN = json[DSN],
            Catalog = if Record.HasFields(json, "Catalog") then json[Catalog] else null
        in
            if Catalog <> null then
                { "Peaka.Databases", DSN, Catalog }
            else
                { "Peaka.Databases", DSN },

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
