///////////////////////////////////////////////////////////////////////////////////////////
///////////////////////////////////////////////////////////////////////////////////////////
/////////////                                                                 /////////////
/////////////    Title: Clockify API Connector for Power BI                   /////////////
/////////////    Created by: Oscar Martinez (https://bit.ly/OscarMtzValero)   /////////////
/////////////    Website: https://bit.ly/OscarMartinez-GitHub                 /////////////
/////////////                                                                 /////////////
///////////////////////////////////////////////////////////////////////////////////////////
///////////////////////////////////////////////////////////////////////////////////////////

// This file contains your Data Connector logic
section Clockify;

baseurl = "https://api.clockify.me/api/v1";
pagesize = "1000000";

[DataSource.Kind="Clockify", Publish="Clockify.Publish"]

// Navitagion Tables
shared Clockify.Navigation = () as table =>
let
        objects = #table(
            {"Name","Key","Data","ItemKind","ItemName","IsLeaf"},{
            {"Workspaces","Workspaces",Clockify.Workspaces(),"Table","Table",true},
            {"Users","Users",Clockify.Users(),"Table","Table",true},
            {"Projects","Projects",Clockify.Projects(),"Table","Table",true},
            {"Time Entries","Time Entries",Clockify.TimeEntries(),"Table","Table",true},
            {"Customers","Customers",Clockify.Customers(),"Table","Table",true},
            {"Tags","Tags",Clockify.Tags(),"Table","Table",true},
            {"Tasks","Tasks",Clockify.Tasks(),"Table","Table",true}

        }),
        NavTable = NavTable.to(objects,{"Key"},"Name","Data","ItemKind","ItemName","IsLeaf")
in
        NavTable;

// Data Tables
Clockify.Workspaces = () =>
let
    apiKey = Extension.CurrentCredential()[Key],
    headers = [
        #"X-Api-Key" = apiKey
    ],
    Source = Json.Document(
        Web.Contents(
            baseurl,
            [
                RelativePath = "/workspaces", 
                Headers=headers,
                ManualCredentials = true
            ]
        )
    ),
    Source1 = Source{0},
    memberships = Source1[memberships],
    #"Converted to Table" = Table.FromList(memberships, Splitter.SplitByNothing(), null, null, ExtraValues.Error),
    #"Expanded Column" = Table.ExpandRecordColumn(#"Converted to Table", "Column1", {"targetId"}, {"Workspaces"}),
    #"Removed Duplicates" = Table.Distinct(#"Expanded Column")

in
    #"Removed Duplicates";

Clockify.Users = () =>

let
    apiKey = Extension.CurrentCredential()[Key],
    headers = [
        #"X-Api-Key" = apiKey
    ],
    source = Clockify.Workspaces(),
    users = Table.AddColumn(
        source,
        "Users",
        each 
            Json.Document(
                Web.Contents(
                    baseurl,
                    [
                        RelativePath = "/workspaces/" & [Workspaces] &"/users?page-size="&pagesize, 
                        Headers = headers,
                         ManualCredentials = true
                    ]
                )
            )
            ),
    #"Expanded Users" = Table.ExpandListColumn(users, "Users"),
    #"Expanded Users1" = Table.ExpandRecordColumn(#"Expanded Users", "Users", {"id", "email", "name", "memberships", "profilePicture", "activeWorkspace", "defaultWorkspace", "settings", "status"}, {"User ID", "User Email", "User Name", "User Memberships", "Profile Picture", "Active Workspace", "Default Workspace", "Settings", "Status"})
in
    #"Expanded Users1";

Clockify.Projects  = () =>

let

    apiKey = Extension.CurrentCredential()[Key],
    headers = [
        #"X-Api-Key" = apiKey
    ],
    source = Clockify.Workspaces(),
    projects = Table.AddColumn(
        source,
        "Projects",
        each
            Json.Document(
                Web.Contents(
                    baseurl,
                    [
                        RelativePath = "/workspaces/" & [Workspaces] &"/projects?page-size="&pagesize, 
                        Headers = headers,
                        ManualCredentials = true
                    ]
                )
            )
            ),
    #"Expanded Projects" = Table.ExpandListColumn(projects, "Projects"),
    #"Expanded Projects1" = Table.ExpandRecordColumn(#"Expanded Projects", "Projects", {"id", "name", "hourlyRate", "clientId", "workspaceId", "billable", "memberships", "color", "estimate", "archived", "duration", "clientName", "note", "template", "public"}, {"Project ID", "Project Name", "Hourly Rate", "Clien tId", "Workspace ID", "Billable", "Memberships", "Color", "Estimate", "Archived", "Duration", "Client Name", "Note", "Template", "Public"})


in
    #"Expanded Projects1";

Clockify.TimeEntries =  () =>

let
    apiKey = Extension.CurrentCredential()[Key],
    headers = [
        #"X-Api-Key" = apiKey
    ],
    source = Clockify.Users(),
    #"Select Columns" = Table.SelectColumns(source,{"User ID","Active Workspace"}),
    timeentries = Table.AddColumn(
        #"Select Columns",
        "Time Entries",
        each
            Json.Document(
                Web.Contents(
                    baseurl,
                    [
                        RelativePath = "/workspaces/" & [Active Workspace] &"/user/"&[User ID]&"/time-entries?page-size="&pagesize, 
                        Headers = headers,
                        ManualCredentials = true
                    ]
                )
            )
            ),
    #"Expanded Time Entries" = Table.ExpandListColumn(timeentries, "Time Entries"),
    #"Expanded Time Entries1" = Table.ExpandRecordColumn(#"Expanded Time Entries", "Time Entries", {"id", "description", "tagIds", "billable", "taskId", "projectId", "timeInterval", "workspaceId", "isLocked", "customFieldValues"}, {"Time Entry ID", "Description", "Tags IDs", "Billable", "Task Id", "Project Id", "Time Interval", "Workspace Id", "Is Locked", "Custom Fields"}),
    #"Expanded timeInterval" = Table.ExpandRecordColumn(#"Expanded Time Entries1", "Time Interval", {"start", "end", "duration"}, {"Interval Start", "Interval End", "Interval Duration"})
in
    #"Expanded timeInterval";

Clockify.Customers =  () =>

let

    apiKey = Extension.CurrentCredential()[Key],
    headers = [
        #"X-Api-Key" = apiKey
    ],
    source = Clockify.Workspaces(),
    customers = Table.AddColumn(
        source,
        "Projects",
        each
            Json.Document(
                Web.Contents(
                    baseurl,
                    [
                        RelativePath = "/workspaces/" & [Workspaces] &"/clients?page-size="&pagesize, 
                        Headers = headers,
                        ManualCredentials = true
                    ]
                )
            )
            ),
    #"Expanded Customers" = Table.ExpandListColumn(customers, "Projects"),
    #"Expanded Customers1" = Table.ExpandRecordColumn(#"Expanded Customers", "Projects", {"id", "name", "workspaceId", "archived", "address"}, {"Customer ID", "Customer Name", "Workspace ID", "Is Archived", "Address"})
in
    #"Expanded Customers1";

Clockify.Tags =  () =>

let

    apiKey = Extension.CurrentCredential()[Key],
    headers = [
        #"X-Api-Key" = apiKey
    ],
    source = Clockify.Workspaces(),
    tags = Table.AddColumn(
        source,
        "Tags",
        each
            Json.Document(
                Web.Contents(
                    baseurl,
                    [
                        RelativePath = "/workspaces/" & [Workspaces] &"/tags?page-size="&pagesize, 
                        Headers = headers,
                        ManualCredentials = true
                    ]
                )
            )
            ),
    #"Expanded Customers" = Table.ExpandListColumn(tags, "Tags")
in
    #"Expanded Customers";

Clockify.Tasks = () =>

let

    apiKey = Extension.CurrentCredential()[Key],
    headers = [
        #"X-Api-Key" = apiKey
        ],
    source = Clockify.Projects(),
    selectcolumns = Table.SelectColumns(source,{"Workspace ID", "Project ID"}),
    timeentries = Table.AddColumn(
        selectcolumns,
        "Tasks",
        each
            Json.Document(
                Web.Contents(
                    baseurl,
                    [
                        RelativePath = "/workspaces/" & [Workspace ID] &"/projects/"&[Project ID]&"/tasks?page-size="&pagesize,
                        Headers = headers,
                        ManualCredentials = true
                    ]
                )
            )
            ),
    #"Expanded Tasks" = Table.ExpandListColumn(timeentries, "Tasks"),
    #"Expanded Tasks1" = Table.ExpandRecordColumn(#"Expanded Tasks", "Tasks", {"id", "name", "assigneeIds", "assigneeId", "estimate", "status", "duration"}, {"Task ID", "Task Name", "Assignee IDs", "Assignee ID", "Estimate", "Status", "Duration"}),
    #"Filtered Rows" = Table.SelectRows(#"Expanded Tasks1", each ([Task ID] <> null))
in
    #"Filtered Rows";

// Data Source Kind description
Clockify = [
    Authentication = [
         Key = []
    ],
    Label = Extension.LoadString("DataSourceLabel")
];

// Data Source UI publishing description
Clockify.Publish = [
    Beta = true,
    Category = "Other",
    ButtonText = { Extension.LoadString("ButtonTitle"), Extension.LoadString("ButtonHelp") },
    LearnMoreUrl = "https://powerbi.microsoft.com/",
    SourceImage = Clockify.Icons,
    SourceTypeImage = Clockify.Icons
];

Clockify.Icons = [
    Icon16 = { Extension.Contents("Clockify16.png"), Extension.Contents("Clockify20.png"), Extension.Contents("Clockify24.png"), Extension.Contents("Clockify32.png") },
    Icon32 = { Extension.Contents("Clockify32.png"), Extension.Contents("Clockify40.png"), Extension.Contents("Clockify48.png"), Extension.Contents("Clockify64.png") }
];

//NavTable
NavTable.to = (
    table as table,
    keyColumns as list,
    nameColumn as text,
    dataColumn as text,
    itemKindColumn as text,
    itemNameColumn as text,
    isLeafColumn as text
) as table =>
    let
        tableType = Value.Type(table),
        newTableType = Type.AddTableKey(tableType, keyColumns, true) meta 
        [
            NavigationTable.NameColumn = nameColumn, 
            NavigationTable.DataColumn = dataColumn,
            NavigationTable.ItemKindColumn = itemKindColumn, 
            Preview.DelayColumn = itemNameColumn, 
            NavigationTable.IsLeafColumn = isLeafColumn
        ],
        navigationTable = Value.ReplaceType(table, newTableType)
    in
        navigationTable;