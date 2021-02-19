#pragma newdecls required

#include <ccprocessor>

#define SENDER(%0) (%0 >> 3)

public Plugin myinfo = 
{
	name = "[CCP] Fake Username",
	author = "nullent?",
	description = "Ability to set a fake username in chat msgs",
	version = "1.5.2",
	url = "discord.gg/ChTyPUG"
};

#define SZ(%0)	%0, sizeof(%0)
#define _CVAR_INIT_CHANGE(%0,%1) %0(FindConVar(%1), NULL_STRING, NULL_STRING)
#define _CVAR_ON_CHANGE(%0) public void %0(ConVar cvar, const char[] szOldVal, const char[] szNewVal)

#define PMP PLATFORM_MAX_PATH
#define MPL MAXPLAYERS+1

char fakename[MPL][NAME_LENGTH];

int AccessFlag, ROOT;
int ClientFlags[MPL];

int nLevel;

public void OnPluginStart()
{    
    ROOT = ReadFlagString("z");

    RegConsoleCmd("sm_fakename", OnCmdUse);

    CreateConVar("ccp_fakename_accessflag", "a", "Access flag or empty, other than the 'z' flag").AddChangeHook(OnAccessChanged);
    CreateConVar("ccp_fakename_priority", "9", "The priority level to change the username", _, true, 0.0).AddChangeHook(OnChangePName);

    AutoExecConfig(true, "ccp_fakename", "ccprocessor");
}

public void OnMapStart()
{
    cc_proc_APIHandShake(cc_get_APIKey());
    
    _CVAR_INIT_CHANGE(OnAccessChanged, "ccp_fakename_accessflag");
    _CVAR_INIT_CHANGE(OnChangePName, "ccp_fakename_priority");
}

_CVAR_ON_CHANGE(OnAccessChanged)
{
    if(!cvar)
        return;
    
    char szFlag[4];
    cvar.GetString(SZ(szFlag));

    AccessFlag = ReadFlagString(szFlag);
}

_CVAR_ON_CHANGE(OnChangePName)
{
    if(cvar)
        nLevel = cvar.IntValue;
}

public Action OnCmdUse(int iClient, int args)
{
    if(args == 1 && iClient && IsClientInGame(iClient) && IsValidClient(iClient))
        GetCmdArg(1, fakename[iClient], sizeof(fakename[]));

    return Plugin_Handled;
}

public void OnClientPutInServer(int iClient)
{
    fakename[iClient][0] = 0;
    ClientFlags[iClient] = 0;
}

public void OnClientPostAdminCheck(int iClient)
{
    ClientFlags[iClient] = GetUserFlagBits(iClient);
}

public Processing  cc_proc_OnRebuildString(const int[] props, int part, ArrayList params, int &level, char[] value, int size) {
    char szIndent[64];
    params.GetString(0, szIndent, sizeof(szIndent));
    
    if((szIndent[0] != 'S' && szIndent[1] != 'T' && strlen(szIndent) < 3) || !SENDER_INDEX(props[1])) {
        return Proc_Continue;
    } 

    if(part == BIND_NAME && fakename[SENDER_INDEX(props[1])][0] && level < nLevel)
    {
        level = nLevel;
        FormatEx(value, size, fakename[SENDER_INDEX(props[1])]);

        return Proc_Change
    }  

    return Proc_Continue
}

bool IsValidClient(int iClient)
{    
    return ((ClientFlags[iClient] && (ClientFlags[iClient] & ROOT)) || (AccessFlag && (ClientFlags[iClient] & AccessFlag)));
}

