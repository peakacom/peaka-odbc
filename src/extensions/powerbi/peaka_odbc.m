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
        // Retrieve the Project API Key entered by the user in the authentication dialog.
        ApiKey = Extension.CurrentCredential()[Key],

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

        Connect = Odbc.DataSource(ConnectionString, [
            HierarchicalNavigation = true,
            HideNativeQuery = false,
            TolerateConcatOverflow = true,
            SqlCompatibleWindowsAuth = false,
            ClientConnectionPooling = true,
            SoftNumbers = true,

            // Pass JWT credentials securely from Power BI's credential store.
            // AuthenticationType must be set explicitly so the driver uses JWT auth
            // regardless of what the DSN has configured for authentication.
            CredentialConnectionString = [
                AuthenticationType = "JWT Authentication",
                AccessToken = ApiKey
            ],

            SqlCapabilities = [
                PrepareStatements = true,
                SupportsTop = true,
                Sql92Conformance = 8,
                SupportsNumericLiterals = true,
                SupportsStringLiterals = true,
                SupportsOdbcDateLiterals = true,
                SupportsOdbcTimeLiterals = true,
                SupportsOdbcTimestampLiterals = true,
                Sql92Translation = "PassThrough"
            ]
        ])
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

    // Key authentication: Power BI shows a single "API Key" text field
    // labeled "Project API Key" in the connection dialog.
    Authentication = [
        Key = [
            KeyLabel = "Project API Key"
        ]
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
