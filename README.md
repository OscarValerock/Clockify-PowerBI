# Inquiries please to https://www.linkedin.com/in/oscarmartinezv/

# Clockify Power BI

This repository contains two ways to getting data from Clockify into Power BI:

(1) Custom connector
(2) Power BI template. 

# For any of the methods you will need the following:

A clockify account:
https://clockify.me/signup

Once you have the account, you will need the API Key.

An API Key
https://clockify.me/user/settings

If you need more info from the API, here is the link to the documentation.
https://clockify.me/developers-api

# 1. Clockify Custom Connector

For more information on Custom Connectors please visit: https://docs.microsoft.com/en-us/power-query/startingtodevelopcustomconnectors

For using the custom connector, please follow the next steps.

a. Get your API Key from the Clockify app. https://clockify.me/user/settings

b. Download the .mez file from here:
   https://github.com/OscarValerock/Clockify-PowerBI/raw/master/Clockify.mez

c. Save the .mez file in the folder shown below:
   C:\Users\{Username}\Documents\Power BI Desktop\Custom Connectors
   
d. Open Power BI Desktop and in the Get Data window search for the "Clockify" connector; when connecting you will be asked to enter the key.

# 2. Clockify template

For using the template (pbit) file, please follow the next steps:

a. Get your API Key from the Clockify app. https://clockify.me/user/settings

b. Download the pbit file from the linke below:
https://github.com/OscarValerock/Clockify-PowerBI/raw/master/Clockify-PBI-Template-PBIT/00%20Clockify%20-%20O.M.%20-%20v2.00.pbit

c. Open the file, you will be asked for the API Key and a Page Size, for the last parameter use a integer like 100000, this is mostly important for the "Time Entries Table"

# 2.1 Clockify template for self hosted Clockify users

Self-hosted Clockify users, you will need to open the template and go through every query and in the advanced editor and change the URL to your server connection detail where you have Clockify installed, it is the same URL that you use to log in.

![](ReadMeImages/Self%20hosted%20users.png)

--