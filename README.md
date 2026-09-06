# Clockify - Power BI Integration
![](ReadMeImages/CPBI.png)

## For inquiries please open an issue:
https://github.com/OscarValerock/Clockify-PowerBI/issues

## Blog Post

If you want to know more about the connector, what you can learn from it, and its development story, I invite you to read my blog post:
[https://www.bibb.pro/post/clockify-power-bi-template](https://www.bibb.pro/post/clockify-power-bi-template)

## Searching for a developed Clockify report and model?
Clockify - Power BI Template - Lifetime updates

https://store.bibb.pro/l/clockify

## What you need

A Clockify account: https://clockify.me/signup

An API key: https://clockify.me/user/settings

Clockify API documentation: https://clockify.me/developers-api

## Walkthrough video

https://github.com/OscarValerock/Clockify-PowerBI/assets/60475729/f9aaacdc-5c4c-4f26-bdea-53c849905f8d

## Clockify Custom Connector

![](ReadMeImages/mez.gif)

For more information on custom connectors: https://learn.microsoft.com/power-query/startingtodevelopcustomconnectors

### Install

a. Get your API key from the Clockify app: https://clockify.me/user/settings

b. Download the `.mez` file:
https://github.com/OscarValerock/Clockify-PowerBI/raw/master/Clockify.mez

c. Save it in:
`C:\Users\{Username}\Documents\Power BI Desktop\Custom Connectors`

d. In Power BI Desktop, **File > Options and settings > Options > Security > Data Extensions**, allow any extension to load.

e. Restart Power BI Desktop. **Get Data**, search for **Clockify**, and connect with your API key.

f. To schedule refresh, you need an on-premises data gateway:
https://learn.microsoft.com/power-bi/connect-data/service-gateway-custom-connectors

### Using the connector

The connector exposes a single function, **`Clockify.Contents`**, which returns a
navigation table with:

`Workspaces`, `Users`, `User Groups`, `Projects`, `Time Entries`, `Clients`,
`Tags`, `Tasks`, `Custom Fields Workspaces`, `Custom Fields Projects`.

Pick tables from the navigator - no parameters are needed for Clockify cloud.

### Self-hosted Clockify

`Clockify.Contents` takes an optional **API URL**. Leave it blank for the
Clockify cloud, or enter your full API base URL (the same host you log in to,
plus `/api/v1`), e.g. `https://clockify.example.com/api/v1`.

## Known limitations

- **Time Entries** are pulled per user, one page at a time. On large workspaces
  this is the slow part of a refresh. A faster bulk pull (Reports API) and
  incremental refresh are in the paid template: https://store.bibb.pro/l/clockify
- `Workspaces` is fetched again by several downstream tables (`Projects`,
  `Clients`, `Tags`, custom fields). Minor redundant calls.
- One credential is shared across the cloud and any self-hosted URL.

## Release notes

### 1.0

- **Breaking:** consolidated the ten `Clockify.*` functions into a single
  `Clockify.Contents` entry point. After upgrading, re-connect through the
  navigator and repoint existing queries.
- Fixed pagination on **every** list endpoint. Previously only Time Entries
  paginated; the other tables fired a single oversized request and silently
  dropped rows past Clockify's page cap.
- Added self-hosted Clockify support via an optional API URL.
- Added automatic retry with backoff on HTTP 429 (rate limit).
- Clearer error messages for bad or unauthorized API keys.
- Migrated the build to the VS Code Power Query SDK.
- Removed the `.pbit` template from this repo. The maintained report and model
  are the paid template: https://store.bibb.pro/l/clockify
