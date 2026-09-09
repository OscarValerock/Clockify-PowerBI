// Clockify custom connector for Power BI
// https://github.com/OscarValerock/Clockify-PowerBI
// Created by Oscar Martinez (https://bit.ly/OscarMtzValero)

section Clockify;

DefaultBaseUrl = "https://api.clockify.me/api/v1";
DefaultPageSize = 200; // safe for every Clockify list endpoint

//
// ---------- entry point ----------
//
[DataSource.Kind = "Clockify", Publish = "Clockify.Publish"]
shared Clockify.Contents = Value.ReplaceType(ClockifyImpl, ClockifyType);

ClockifyType = type function (
    optional url as (type text meta [
        Documentation.FieldCaption = "API URL",
        Documentation.FieldDescription = "Leave blank for the Clockify cloud. For a self-hosted Clockify, enter the full API base URL, e.g. https://clockify.example.com/api/v1",
        Documentation.SampleValues = {DefaultBaseUrl}
    ]))
    as table meta [
        Documentation.Name = "Clockify"
    ];

ClockifyImpl = (optional url as text) as table =>
    let
        base = if url = null or url = "" then DefaultBaseUrl else url
    in
        NavTable(base);

//
// ---------- navigation table ----------
//
NavTable = (base as text) as table =>
    let
        objects = #table(
            {"Name", "Key", "Data", "ItemKind", "ItemName", "IsLeaf"},
            {
                {"Workspaces", "Workspaces", Workspaces(base), "Table", "Table", true},
                {"Users", "Users", Users(base), "Table", "Table", true},
                {"User Groups", "User Groups", UserGroups(base), "Table", "Table", true},
                {"Projects", "Projects", Projects(base), "Table", "Table", true},
                {"Time Entries", "Time Entries", TimeEntries(base), "Table", "Table", true},
                {"Clients", "Clients", Clients(base), "Table", "Table", true},
                {"Tags", "Tags", Tags(base), "Table", "Table", true},
                {"Tasks", "Tasks", Tasks(base), "Table", "Table", true},
                {"Custom Fields Workspaces", "Custom Fields Workspaces", CustomFieldsWorkspaces(base), "Table", "Table", true},
                {"Custom Fields Projects", "Custom Fields Projects", CustomFieldsProjects(base), "Table", "Table", true}
            }
        ),
        navTable = Table.ToNavigationTable(objects, {"Key"}, "Name", "Data", "ItemKind", "ItemName", "IsLeaf")
    in
        navTable;

//
// ---------- request + pagination helpers (the core of the fix) ----------
//
Clockify.Request = (base as text, path as text, optional query as record) as record =>
    let
        response = Web.Contents(base, [
            RelativePath = path,
            Query = query ?? [],
            Headers = [#"X-Api-Key" = Extension.CurrentCredential()[Key]],
            ManualStatusHandling = {400, 401, 403, 404, 429, 500, 502, 503},
            ManualCredentials = true
        ]),
        buffered = Binary.Buffer(response),
        responseMeta = Value.Metadata(response),
        headers = try responseMeta[Headers] otherwise []
    in
        [Status = responseMeta[Response.Status], Headers = headers, Body = buffered];

// exponential backoff on 429: 1s, 2s, 4s, 8s, 16s
Clockify.RequestRetry = (base as text, path as text, optional query as record) as record =>
    let
        attempt = (n as number) as record =>
            let
                r = Clockify.Request(base, path, query)
            in
                if r[Status] = 429 and n < 5 then
                    Function.InvokeAfter(() => @attempt(n + 1), #duration(0, 0, 0, Number.Power(2, n)))
                else
                    r
    in
        attempt(0);

// loop pages until the Last-Page response header is "true", a short page, or an empty page
Clockify.GetList = (base as text, path as text, optional query as record) as list =>
    let
        fetch = (n as number, acc as list) as list =>
            let
                pageQuery = Record.Combine({
                    query ?? [],
                    [#"page" = Text.From(n), #"page-size" = Text.From(DefaultPageSize)]
                }),
                r = Clockify.RequestRetry(base, path, pageQuery),
                items =
                    if r[Status] >= 400 then
                        error Clockify.Error(r)
                    else
                        let parsed = Json.Document(r[Body]) in
                            if parsed is list then parsed else {},
                    lastByHeader = try Text.Lower(Record.FieldOrDefault(r[Headers], "Last-Page", "")) = "true" otherwise false,
                    lastBySize = List.Count(items) < DefaultPageSize,
                    acc2 = acc & items
            in
                if List.IsEmpty(items) or lastByHeader or lastBySize then acc2 else @fetch(n + 1, acc2)
    in
        fetch(1, {});

Clockify.Error = (r as record) as record =>
    let
        body = try Text.FromBinary(r[Body]) otherwise "",
        status = r[Status]
    in
        [
            Reason = "DataSource.Error",
            Message =
                if status = 401 then
                    "Clockify rejected the API key (401). Check your saved credential."
                else if status = 403 then
                    "Clockify denied access (403). The API key may lack permission for this workspace or endpoint."
                else if status = 404 then
                    "Clockify resource not found (404). " & body
                else if status = 429 then
                    "Clockify rate limit hit (429); retries exhausted. Try the refresh again later."
                else
                    "Clockify request failed (" & Text.From(status) & "). " & body,
            Detail = body
        ];

//
// ---------- entity functions ----------
// Output column names are kept identical to the previous connector.
//
Workspaces = (base as text) as table =>
    let
        source = Clockify.GetList(base, "/workspaces"),
        toTable = Table.FromList(source, Splitter.SplitByNothing(), null, null, ExtraValues.Error),
        expanded = Table.ExpandRecordColumn(
            toTable,
            "Column1",
            {"id", "name", "hourlyRate", "memberships", "workspaceSettings", "imageUrl", "featureSubscriptionType"},
            {"Workspace ID", "Workspace Name", "Workspace Hourly Rate", "Workspace Memberships", "Workspace Settings", "Workspace Image Url", "Workspace Feature Subscription Type"}
        )
    in
        expanded;

Users = (base as text) as table =>
    let
        source = Table.SelectColumns(Workspaces(base), {"Workspace ID"}),
        withUsers = Table.AddColumn(
            source,
            "Users",
            each Clockify.GetList(base, "/workspaces/" & [Workspace ID] & "/users", [memberships = "ALL"])
        ),
        expandedList = Table.ExpandListColumn(withUsers, "Users"),
        expanded = Table.ExpandRecordColumn(
            expandedList,
            "Users",
            {"id", "email", "name", "memberships", "profilePicture", "activeWorkspace", "defaultWorkspace", "settings", "status"},
            {"User ID", "User Email", "User Name", "User Memberships", "Profile Picture", "Active Workspace", "Default Workspace", "Settings", "Status"}
        )
    in
        expanded;

UserGroups = (base as text) as table =>
    let
        source = Table.SelectColumns(Workspaces(base), {"Workspace ID"}),
        withGroups = Table.AddColumn(
            source,
            "Groups",
            each Clockify.GetList(base, "/workspaces/" & [Workspace ID] & "/user-groups")
        ),
        expandedList = Table.ExpandListColumn(withGroups, "Groups"),
        expanded = Table.ExpandRecordColumn(
            expandedList,
            "Groups",
            {"id", "name", "userIds"},
            {"User Group ID", "User Group Name", "User IDs"}
        ),
        expandedIds = Table.ExpandListColumn(expanded, "User IDs")
    in
        expandedIds;

Projects = (base as text) as table =>
    let
        source = Workspaces(base),
        withProjects = Table.AddColumn(
            source,
            "Projects",
            each Clockify.GetList(base, "/workspaces/" & [Workspace ID] & "/projects")
        ),
        expandedList = Table.ExpandListColumn(withProjects, "Projects"),
        expanded = Table.ExpandRecordColumn(
            expandedList,
            "Projects",
            {"id", "name", "hourlyRate", "clientId", "workspaceId", "billable", "memberships", "color", "estimate", "archived", "duration", "clientName", "note", "template", "public"},
            {"Project ID", "Project Name", "Hourly Rate", "Client ID", "Workspace ID2", "Billable", "Memberships", "Color", "Estimate", "Archived", "Duration", "Client Name", "Note", "Template", "Public"}
        )
    in
        expanded;

TimeEntries = (base as text) as table =>
    let
        source = Table.SelectColumns(Users(base), {"Workspace ID", "User ID"}),
        withEntries = Table.AddColumn(
            source,
            "Time Entries",
            each Clockify.GetList(base, "/workspaces/" & [Workspace ID] & "/user/" & [User ID] & "/time-entries")
        ),
        expandedList = Table.ExpandListColumn(withEntries, "Time Entries"),
        expanded = Table.ExpandRecordColumn(
            expandedList,
            "Time Entries",
            {"id", "description", "tagIds", "billable", "taskId", "projectId", "timeInterval", "workspaceId", "isLocked", "hourlyRate", "customFieldValues"},
            {"Time Entry ID", "Description", "Tags IDs", "Billable", "Task ID", "Project ID", "Time Interval", "Workspace ID2", "Is Locked", "Hourly Rate", "Custom Fields"}
        ),
        filtered = Table.SelectRows(expanded, each [Time Entry ID] <> null),
        expandedRate = Table.ExpandRecordColumn(filtered, "Hourly Rate", {"amount", "currency"}, {"Hourly Rate Amount", "Rate Currency"}),
        transformedRate = Table.TransformColumns(expandedRate, {{"Hourly Rate Amount", each _ / 100, type number}}),
        expandedInterval = Table.ExpandRecordColumn(transformedRate, "Time Interval", {"start", "end", "duration"}, {"Interval Start", "Interval End", "Interval Duration"})
    in
        expandedInterval;

Clients = (base as text) as table =>
    let
        source = Workspaces(base),
        withClients = Table.AddColumn(
            source,
            "Clients",
            each Clockify.GetList(base, "/workspaces/" & [Workspace ID] & "/clients")
        ),
        expandedList = Table.ExpandListColumn(withClients, "Clients"),
        expanded = Table.ExpandRecordColumn(
            expandedList,
            "Clients",
            {"id", "name", "workspaceId", "archived", "address"},
            {"Client ID", "Client Name", "Workspace ID2", "Is Archived", "Address"}
        )
    in
        expanded;

Tags = (base as text) as table =>
    let
        source = Workspaces(base),
        withTags = Table.AddColumn(
            source,
            "Tags",
            each Clockify.GetList(base, "/workspaces/" & [Workspace ID] & "/tags")
        ),
        expandedList = Table.ExpandListColumn(withTags, "Tags"),
        expanded = Table.ExpandRecordColumn(
            expandedList,
            "Tags",
            {"id", "name", "workspaceId", "archived"},
            {"Tag ID", "Tag Name", "Workspace ID2", "Archived"}
        )
    in
        expanded;

Tasks = (base as text) as table =>
    let
        source = Table.SelectColumns(Projects(base), {"Workspace ID", "Project ID"}),
        withTasks = Table.AddColumn(
            source,
            "Tasks",
            each Clockify.GetList(base, "/workspaces/" & [Workspace ID] & "/projects/" & [Project ID] & "/tasks")
        ),
        expandedList = Table.ExpandListColumn(withTasks, "Tasks"),
        expanded = Table.ExpandRecordColumn(
            expandedList,
            "Tasks",
            {"id", "name", "assigneeIds", "assigneeId", "estimate", "status", "duration"},
            {"Task ID", "Task Name", "Assignee IDs", "Assignee ID", "Estimate", "Status", "Duration"}
        ),
        filtered = Table.SelectRows(expanded, each [Task ID] <> null)
    in
        filtered;

CustomFieldsWorkspaces = (base as text) as table =>
    let
        source = Workspaces(base),
        withFields = Table.AddColumn(
            source,
            "Custom Fields",
            each Clockify.GetList(base, "/workspaces/" & [Workspace ID] & "/custom-fields")
        ),
        expandedList = Table.ExpandListColumn(withFields, "Custom Fields"),
        expanded = Table.ExpandRecordColumn(
            expandedList,
            "Custom Fields",
            {"id", "name", "description", "type", "placeholder", "allowedValues", "workspaceDefaultValue", "onlyAdminCanEdit", "required", "status", "projectDefaultValues"},
            {"Workspace Custom Field ID", "Workspace Custom Field Name", "Workspace Custom Field Description", "Workspace Custom Field Type", "Workspace Custom Field Placeholder", "Allowed Values", "Workspace Default Value", "Only Admin Can Edit", "Required", "Status", "Project Default Values"}
        )
    in
        expanded;

CustomFieldsProjects = (base as text) as table =>
    let
        source = Table.SelectColumns(Projects(base), {"Workspace ID", "Project ID"}),
        withFields = Table.AddColumn(
            source,
            "Custom Fields",
            each Clockify.GetList(base, "/workspaces/" & [Workspace ID] & "/projects/" & [Project ID] & "/custom-fields")
        ),
        expandedList = Table.ExpandListColumn(withFields, "Custom Fields"),
        expanded = Table.ExpandRecordColumn(
            expandedList,
            "Custom Fields",
            {"id", "name", "description", "type", "placeholder", "allowedValues", "workspaceDefaultValue", "onlyAdminCanEdit", "required", "status", "projectDefaultValues"},
            {"Project Custom Field ID", "Project Custom Field Name", "Project Custom Field Description", "Project Custom Field Type", "Placeholder", "Allowed Values", "Workspace Default Value", "Only Admin Can Edit", "Required", "Status", "Project Default Values"}
        )
    in
        expanded;

//
// ---------- data source kind + publish ----------
//
Clockify = [
    TestConnection = (dataSourcePath) => {"Clockify.Contents"},
    Authentication = [
        Key = [KeyLabel = "Clockify API Key"]
    ],
    Label = Extension.LoadString("DataSourceLabel")
];

Clockify.Publish = [
    Beta = false,
    Category = "Online Services",
    ButtonText = {Extension.LoadString("ButtonTitle"), Extension.LoadString("ButtonHelp")},
    LearnMoreUrl = "https://bibb.pro/post/clockify-power-bi-template",
    SourceImage = Clockify.Icons,
    SourceTypeImage = Clockify.Icons
];

Clockify.Icons = [
    Icon16 = {Extension.Contents("Clockify16.png"), Extension.Contents("Clockify20.png"), Extension.Contents("Clockify24.png"), Extension.Contents("Clockify32.png")},
    Icon32 = {Extension.Contents("Clockify32.png"), Extension.Contents("Clockify40.png"), Extension.Contents("Clockify48.png"), Extension.Contents("Clockify64.png")}
];

//
// ---------- helpers ----------
//
Table.ToNavigationTable = (
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
        newTableType = Type.AddTableKey(tableType, keyColumns, true) meta [
            NavigationTable.NameColumn = nameColumn,
            NavigationTable.DataColumn = dataColumn,
            NavigationTable.ItemKindColumn = itemKindColumn,
            Preview.DelayColumn = itemNameColumn,
            NavigationTable.IsLeafColumn = isLeafColumn
        ],
        navigationTable = Value.ReplaceType(table, newTableType)
    in
        navigationTable;
