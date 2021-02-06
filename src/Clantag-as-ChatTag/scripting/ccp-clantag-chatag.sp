#pragma newdecls required

#include <ccprocessor>

#include <cstrike>

public Plugin myinfo = 
{
	name = "[CCP] Clan Tag as Chat Tag",
	author = "nullent?",
	description = "...",
	version = "1.3.1",
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

public Action cc_proc_OnRebuildString(
    int mid, const char[] indent, int sender,
    int recipient, int part, int &level, 
    char[] buffer, int size
) {
    if(indent[0] != 'S' && indent[1] != 'T' && strlen(indent) < 3) {
        return Plugin_Continue;
    }

    if(!sender || part != BIND_PREFIX || level > plevel)
        return Plugin_Continue;
    
    char szPrefix[PREFIX_LENGTH];
    szPrefix = GetClientClanTag(sender);

    if(!szPrefix[0])
        return Plugin_Continue;
    
    level = plevel;
    FormatEx(buffer, size, szPrefix);

    return Plugin_Continue;
}

char GetClientClanTag(int iClient)
{
    char szTag[PREFIX_LENGTH];

    CS_GetClientClanTag(iClient, szTag, sizeof(szTag));

    return szTag;
}