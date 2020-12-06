#pragma newdecls required

#include <ccprocessor>

#include <cstrike>

public Plugin myinfo = 
{
	name = "[CCP] ClanTag as Chat Prefix",
	author = "nullent?",
	description = "Set ClanTag as chat prefix",
	version = "1.2.2",
	url = "discord.gg/ChTyPUG"
};

public void OnPluginStart()
{
    CreateConVar("ccp_clantag_priority", "1", "Priority for replacing the prefix value", _, true, 0.0).AddChangeHook(OnConVarChanged);

    AutoExecConfig(true, "clantag", "ccprocessor");
}

public void OnMapStart()
{
    cc_proc_APIHandShake(cc_get_APIKey());

    OnConVarChanged(FindConVar("ccp_clantag_priority"), NULL_STRING, NULL_STRING);
}

int plevel;

public void OnConVarChanged(ConVar cvar, const char[] oldVal, const char[] newVal)
{
    plevel = cvar.IntValue;
}


public Action cc_proc_RebuildString(const int mType, int iClient, int &pLevel, const char[] szBind, char[] szBuffer, int iSize)
{
    if(mType == eMsg_CNAME || mType == eMsg_SERVER)
        return Plugin_Continue;

    if(!iClient)
        return Plugin_Continue;
    
    if(strcmp(szBind, szBinds[BIND_PREFIX]))
        return Plugin_Continue;
    
    if(pLevel > plevel)
        return Plugin_Continue;

    char szPrefix[PREFIX_LENGTH];
    szPrefix = GetClientClanTag(iClient);

    if(!szPrefix[0])
        return Plugin_Continue;
    
    pLevel = plevel;
    FormatEx(szBuffer, iSize, szPrefix);

    return Plugin_Continue;
}

char GetClientClanTag(int iClient)
{
    char szTag[PREFIX_LENGTH];

    CS_GetClientClanTag(iClient, szTag, sizeof(szTag));

    return szTag;
}