#pragma newdecls required

#include ccprocessor

public Plugin myinfo = 
{
	name = "[CCP] No SM prefix",
	author = "nullent?",
	description = "Allows you to replace the standard Sourcemod prefix",
	version = "1.3.0",
	url = "discord.gg/ChTyPUG"
};

#define SM_PREFIX "[SM]"

char szPrefix[TEAM_LENGTH];


public void OnPluginStart()
{
        
    CreateConVar("ccp_nosm_prefix", "", "The new value for the prefix").AddChangeHook(OnCvarChanged);
    AutoExecConfig(true, "nosm", "ccprocessor");
}

public void OnMapStart()
{
    cc_proc_APIHandShake(cc_get_APIKey());

    OnCvarChanged(FindConVar("ccp_nosm_prefix"), NULL_STRING, NULL_STRING);
}

public void OnCvarChanged(ConVar cvar, const char[] oldVal, const char[] newVal)
{
    cvar.GetString(szPrefix, sizeof(szPrefix));
}

int MessageTemplate;

public void cc_proc_MsgBroadType(const int iType)
{
    MessageTemplate = iType;
}

public void cc_proc_RebuildString(int iClient, int &pLevel, const char[] szBind, char[] szBuffer, int iSize)
{
    if(!iClient && !strcmp(szBind, "{MSG}") && MessageTemplate == eMsg_SERVER)
        ReplaceStringEx(szBuffer, iSize, SM_PREFIX, szPrefix, -1, -1, true);
}


