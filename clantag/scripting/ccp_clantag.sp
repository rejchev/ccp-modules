#pragma newdecls required

#include ccprocessor

char szPrefix[MAXPLAYERS+1][PREFIX_LENGTH];

public Plugin myinfo = 
{
	name = "[CCP] ClanTag to Prefix",
	author = "nullent?",
	description = "Set ClanTag as chat prefix",
	version = "1.0.0",
	url = "discord.gg/ChTyPUG"
};

public void OnPluginStart()
{
    CreateConVar("ccp_clantag_priority", "1", "Priority for replacing the prefix value", _, true, 0.0).AddChangeHook(OnConVarChanged);

    AutoExecConfig(true, "clantag", "ccprocessor");
}

public void OnMapStart()
{
    OnConVarChanged(FindConVar("ccp_clantag_priority"), NULL_STRING, NULL_STRING);
}

int plevel;

public void OnConVarChanged(ConVar cvar, const char[] oldVal, const char[] newVal)
{
    plevel = cvar.IntValue;
}

public Action OnClientCommandKeyValues(int client, KeyValues kv)
{
    char szBuffer[16];
    if(!IsClientInGame(client) || IsFakeClient(client))
        return Plugin_Continue;
    
    if(kv.GetSectionName(szBuffer, sizeof(szBuffer)) && strncmp(szBuffer, "ClanTagChanged", 14) == 0)
        kv.GetString("tag", szPrefix[client], sizeof(szPrefix[]));

    return Plugin_Continue;
}

int iType;

public void cc_proc_MsgBroadType(const int typeMsg)
{
    iType = typeMsg;
}

public void cc_proc_RebuildString(int iClient, int &pLevel, const char[] szBind, char[] szBuffer, int iSize)
{
    if(iType < eMsg_SERVER && plevel > pLevel && szPrefix[iClient][0] && !strcmp(szBind, "{PREFIX}"))
    {
        pLevel = plevel;
        FormatEx(szBuffer, iSize, szPrefix[iClient]);
    }
}