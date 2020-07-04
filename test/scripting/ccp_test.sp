#pragma newdecls required

#include ccprocessor

#define LEVEL_PRIOR     1

bool EnableSkip;
char testPrefix[PREFIX_LENGTH];

#if defined API_KEY

#define API_KEY_OOD "The plugin module uses an outdated API. You must update it."

public void cc_proc_APIHandShake(const char[] APIKey)
{
    if(!StrEqual(APIKey, API_KEY, true))
        SetFailState(API_KEY_OOD);
}

#endif

public void OnPluginStart()
{
    #if defined API_KEY
    
    if(CanTestFeatures() && GetFeatureStatus(FeatureType_Native, "cc_is_APIEqual") == FeatureStatus_Available && !cc_is_APIEqual(API_KEY))
        cc_proc_APIHandShake(NULL_STRING);

    #endif

    RegConsoleCmd("sm_skipcolors", CmdSkip);
    RegConsoleCmd("sm_testserver", CmdTestServer);
    RegConsoleCmd("sm_testprefix", CmdTestPrefix);
}

Action CmdSkip(int Client, int args)
{
    if(Client && IsClientInGame(Client))
        PrintToChatAll("The color skip status was changed to {G}%s", (EnableSkip = !EnableSkip) ? "true" : "false");
    
    return Plugin_Handled;
}

public bool cc_proc_SkipColorsInMsg(int Client)
{
    return EnableSkip;
}

Action CmdTestServer(int Client, int args)
{
    PrintToChatAll("{PI}[Console] {G}Hello, i am a {PI}Server!");
    return Plugin_Handled;
}

Action CmdTestPrefix(int Client, int Args)
{
    if(!testPrefix[0])
        testPrefix = "{PI}[TEST] ";
    else testPrefix[0] = 0;

    PrintToChatAll("The test prefix now is {G}%s", (testPrefix[0]) ? "enabled" : "disabled");

    return Plugin_Handled;
}

int iType;

public void cc_proc_MsgBroadType(const int typeMsg)
{
    iType = typeMsg;
}

public void cc_proc_RebuildString(int iClient, int &pLevel, const char[] szBind, char[] szBuffer, int iSize)
{
    if(iType > eMsg_ALL)
        return;
    
    if(!StrEqual(szBind, "{PREFIX}") || !testPrefix[0])
        return;

    if(pLevel > LEVEL_PRIOR)
        return;
    
    pLevel = LEVEL_PRIOR;

    FormatEx(szBuffer, iSize, testPrefix);
}