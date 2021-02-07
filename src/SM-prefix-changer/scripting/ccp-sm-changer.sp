#pragma newdecls required

#include ccprocessor

public Plugin myinfo = 
{
	name = "[CCP] SM Prefix Changer",
	author = "nullent?",
	description = "Allows you to replace the standard Sourcemod prefix",
	version = "1.5.2",
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

public Action  cc_proc_OnRebuildString(const int[] props, int part, ArrayList params, int &level, char[] value, int size) {
    char szIndent[64];
    params.GetString(0, szIndent, sizeof(szIndent));
   
    if(!strcmp(szIndent, "TM") && part == BIND_MSG)
        ReplaceStringEx(value, size, SM_PREFIX, szPrefix, -1, -1, true);
}


