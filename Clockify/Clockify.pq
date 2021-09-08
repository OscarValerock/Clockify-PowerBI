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
pagesize = "5000";

[DataSource.Kind="Clockify", Publish="Clockify.Publish"]

//
// Navitagion Tables
shared Clockify.Navigation = () as table =>
let
        objects = #table(
            {"Name","Key","Data","ItemKind","ItemName","IsLeaf"},{
            {"Workspaces","Workspaces",Clockify.Workspaces(),"Table","Table",true},
            {"Users","Users",Clockify.Users(),"Table","Table",true},
            {"User Groups","User Groups",Clockify.UserGroups(),"Table","Table",true},
            {"Projects","Projects",Clockify.Projects(),"Table","Table",true},
            {"Time Entries","Time Entries",Clockify.TimeEntries(),"Table","Table",true},
            {"Clients","Clients",Clockify.Clients(),"Table","Table",true},
            {"Tags","Tags",Clockify.Tags(),"Table","Table",true},
            {"Tasks","Tasks",Clockify.Tasks(),"Table","Table",true},
            {"Custom Fields Workspaces","Custom Fields Workspaces",Clockify.CustomFieldsWorkspaces(),"Table","Table",true},
            {"Custom Fields Projects","Custom Fields Projects",Clockify.CustomFieldsProjects(),"Table","Table",true}

        }),
        NavTable = NavTable.to(objects,{"Key"},"Name","Data","ItemKind","ItemName","IsLeaf")

in
        NavTable;

// Data Tables
shared Clockify.Workspaces = () =>
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
    #"Converted to Table" = Table.FromList(Source, Splitter.SplitByNothing(), null, null, ExtraValues.Error),
    #"Expanded Column1" = Table.ExpandRecordColumn(#"Converted to Table", "Column1", {"id", "name", "hourlyRate", "memberships", "workspaceSettings", "imageUrl", "featureSubscriptionType"}, {"Workspace ID", "Workspace Name", "Workspace Hourly Rate", "Workspace Memberships", "Workspace Settings", "Workspace Image Url", "Workspace Feature Subscription Type"})
in
    #"Expanded Column1";

Clockify.Users = () =>

let
    apiKey = Extension.CurrentCredential()[Key],
    headers = [
        #"X-Api-Key" = apiKey
    ],
    source = Clockify.Workspaces(),
    #"Select Columns" = Table.SelectColumns(source,{"Workspace ID"}),
    users = Table.AddColumn(
        #"Select Columns",
        "Users",
        each 
            Json.Document(
                Web.Contents(
                    baseurl,
                    [
                        RelativePath = "/workspaces/" & [Workspace ID] &"/users?page-size="&pagesize, 
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


Clockify.UserGroups = () =>

let
    apiKey = Extension.CurrentCredential()[Key],
    headers = [
        #"X-Api-Key" = apiKey
    ],
    source = Clockify.Workspaces(),
    #"Select Columns" = Table.SelectColumns(source,{"Workspace ID"}),
    Groups = Table.AddColumn(
        #"Select Columns",
        "Groups",
        each 
            Json.Document(
                Web.Contents(
                    baseurl,
                    [
                        RelativePath = "/workspaces/" & [Workspace ID] &"/user-groups?page-size="&pagesize, 
                        Headers = headers,
                         ManualCredentials = true
                    ]
                )
            )
            ),
    #"Expanded Groups" = Table.ExpandListColumn(Groups, "Groups"),
    #"Expanded Groups1" = Table.ExpandRecordColumn(#"Expanded Groups", "Groups", {"id", "name", "userIds"}, {"User Group ID", "User Group Name", "User IDs"}),
    #"Expanded userIds" = Table.ExpandListColumn(#"Expanded Groups1", "User IDs")
in
    #"Expanded userIds";




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
                        RelativePath = "/workspaces/" & [Workspace ID] &"/projects?page-size="&pagesize, 
                        Headers = headers,
                        ManualCredentials = true
                    ]
                )
            )
            ),
    #"Expanded Projects" = Table.ExpandListColumn(projects, "Projects"),
    #"Expanded Projects1" = Table.ExpandRecordColumn(#"Expanded Projects", "Projects", {"id", "name", "hourlyRate", "clientId", "workspaceId", "billable", "memberships", "color", "estimate", "archived", "duration", "clientName", "note", "template", "public"}, {"Project ID", "Project Name", "Hourly Rate", "Client ID", "Workspace ID2", "Billable", "Memberships", "Color", "Estimate", "Archived", "Duration", "Client Name", "Note", "Template", "Public"})


in
    #"Expanded Projects1";

Clockify.TimeEntries =  () =>

let
    apiKey = Extension.CurrentCredential()[Key],
    headers = [
        #"X-Api-Key" = apiKey
    ],
    source = Clockify.Users(),
    #"Select Columns" = Table.SelectColumns(source,{"User ID","Workspace ID"}),
    timeentries = Table.AddColumn(
        #"Select Columns",
        "Time Entries",
        each
            Json.Document(
                Web.Contents(
                    baseurl,
                    [
                        RelativePath = "/workspaces/" & [Workspace ID] &"/user/"&[User ID]&"/time-entries?page-size="&pagesize, 
                        Headers = headers,
                        ManualCredentials = true
                    ]
                )
            )
            ),
    #"Expanded Time Entries" = Table.ExpandListColumn(timeentries, "Time Entries"),
    #"Expanded Time Entries1" = Table.ExpandRecordColumn(#"Expanded Time Entries", "Time Entries", {"id", "description", "tagIds", "billable", "taskId", "projectId", "timeInterval", "workspaceId", "isLocked", "customFieldValues"}, {"Time Entry ID", "Description", "Tags IDs", "Billable", "Task ID", "Project ID", "Time Interval", "Workspace ID2", "Is Locked", "Custom Fields"}),
    #"Expanded timeInterval" = Table.ExpandRecordColumn(#"Expanded Time Entries1", "Time Interval", {"start", "end", "duration"}, {"Interval Start", "Interval End", "Interval Duration"})
in
    #"Expanded timeInterval";

Clockify.Clients =  () =>

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
                        RelativePath = "/workspaces/" & [Workspace ID] &"/clients?page-size="&pagesize, 
                        Headers = headers,
                        ManualCredentials = true
                    ]
                )
            )
            ),
    #"Expanded Customers" = Table.ExpandListColumn(customers, "Projects"),
    #"Expanded Customers1" = Table.ExpandRecordColumn(#"Expanded Customers", "Projects", {"id", "name", "workspaceId", "archived", "address"}, {"Client ID", "Client Name", "Workspace ID2", "Is Archived", "Address"})
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
                        RelativePath = "/workspaces/" & [Workspace ID] &"/tags?page-size="&pagesize, 
                        Headers = headers,
                        ManualCredentials = true
                    ]
                )
            )
            ),
    #"Expanded Tags" = Table.ExpandListColumn(tags, "Tags"),
    #"Expanded Tags1" = Table.ExpandRecordColumn(#"Expanded Tags", "Tags", {"id", "name", "workspaceId", "archived"}, {"Tag ID", "Tag Name", "Workspace ID2", "Archived"})
in
    #"Expanded Tags1";

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


Clockify.CustomFieldsWorkspaces = () =>

let

    apiKey = Extension.CurrentCredential()[Key],
    headers = [
        #"X-Api-Key" = apiKey
    ],
    source = Clockify.Workspaces(),
    #"Custom Fields" = Table.AddColumn(
        source,
        "Custom Fields",
        each
            Json.Document(
                Web.Contents(
                    baseurl,
                    [
                        RelativePath = "/workspaces/" & [Workspace ID] &"/custom-fields?page-size="&pagesize, 
                        Headers = headers,
                        ManualCredentials = true
                    ]
                )
            )
            ),
    #"Expanded Custom Fields" = Table.ExpandListColumn(#"Custom Fields", "Custom Fields"),
    #"Expanded Custom Fields1" = Table.ExpandRecordColumn(#"Expanded Custom Fields", "Custom Fields", {"id",  "name", "description", "type", "placeholder", "allowedValues", "workspaceDefaultValue", "onlyAdminCanEdit", "required", "status", "projectDefaultValues"}, {"Workspace Custom Field ID", "Workspace Custom Field Name", "Workspace Custom Field Description", "Workspace Custom Field Type", "Workspace Custom Field Placeholder", "Allowed Values", "Workspace Default Value", "Only Admin Can Edit", "Required", "Status", "Project Default Values"})

in

#"Expanded Custom Fields1";


Clockify.CustomFieldsProjects = () =>

let

    apiKey = Extension.CurrentCredential()[Key],
    headers = [
        #"X-Api-Key" = apiKey
        ],
    source = Clockify.Projects(),
    selectcolumns = Table.SelectColumns(source,{"Workspace ID", "Project ID"}),
    #"Custom Fields" = Table.AddColumn(
        selectcolumns,
        "Custom Fields",
        each
            Json.Document(
                Web.Contents(
                    baseurl,
                    [
                        RelativePath = "/workspaces/" & [Workspace ID] &"/projects/"&[Project ID]&"/custom-fields?page-size="&pagesize,
                        Headers = headers,
                        ManualCredentials = true
                    ]
                )
            )
            ),
    #"Expanded Custom Fields Project" = Table.ExpandListColumn(#"Custom Fields", "Custom Fields"),
    #"Expanded Custom Fields Project1" = Table.ExpandRecordColumn(#"Expanded Custom Fields Project", "Custom Fields", 
        {"id",  "name", "description", "type", "placeholder", "allowedValues", "workspaceDefaultValue", "onlyAdminCanEdit", "required", "status", "projectDefaultValues"}, 
        {"Project Custom Field ID",  "Project Custom Field Name", "Project Custom Field Description", "Project Custom Field Type", "Placeholder", "Allowed Values", "Workspace Default Value", "Only Admin Can Edit", "Required", "Status", "Project Default Values"})
in
     #"Expanded Custom Fields Project1" ;



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