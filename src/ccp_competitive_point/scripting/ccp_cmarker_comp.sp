#pragma newdecls required

#include ccprocessor

#include sdkhooks
#include sdktools

int m_iCompTeammateColor = -1;

int ColorArray[MAXPLAYERS+1];

bool IsMapEnd, EnColor;

char szStatusSmb[STATUS_LENGTH];
int Level;

public Plugin myinfo = 
{
    name        = "[CCP, CSGO] CMarker",
    author      = "nullent?",
    description = "Competitive color marker into chat",
    version     = "1.5.0",
    url         = "discord.gg/ChTyPUG"
};


public APLRes AskPluginLoad2(Handle myself, bool late, char[] error, int err_max)
{ 
    return (GetEngineVersion() != Engine_CSGO /*|| FindConVar("game_mode").IntValue != 1*/) ? APLRes_SilentFailure : APLRes_Success;
}

public void OnPluginStart()
{
    m_iCompTeammateColor = FindSendPropInfo("CCSPlayerResource", "m_iCompTeammateColor");

    CreateConVar("cmarker_priority_level", "1", "Replacement Priority", _, true, 0.0).AddChangeHook(OnLevelChanged);
    CreateConVar("cmarker_status_symbol", "●", "Any character").AddChangeHook(OnSymbolChanged);
    CreateConVar("cmarker_added_color", "1", "Enable/Disable color").AddChangeHook(OnColorChanged);

    AutoExecConfig(true, "cmarker_comp", "ccprocessor");
}

public void OnLevelChanged(ConVar cvar, const char[] szOldVal, const char[] szNewVal)
{
    Level = cvar.IntValue;
}

public void OnColorChanged(ConVar cvar, const char[] szOldVal, const char[] szNewVal)
{
    EnColor = cvar.BoolValue;
}

public void OnSymbolChanged(ConVar cvar, const char[] szOldVal, const char[] szNewVal)
{
    cvar.GetString(szStatusSmb, sizeof(szStatusSmb));
}

public void OnMapStart()
{
    cc_proc_APIHandShake(cc_get_APIKey());

    OnLevelChanged(FindConVar("cmarker_priority_level"), NULL_STRING, NULL_STRING);
    OnSymbolChanged(FindConVar("cmarker_status_symbol"), NULL_STRING, NULL_STRING);
    OnColorChanged(FindConVar("cmarker_added_color"), NULL_STRING, NULL_STRING);

    IsMapEnd = false;

    SDKHook(GetPlayerResourceEntity(), SDKHook_ThinkPost, OnThinkPost); 
}

public void OnMapEnd()
{
    IsMapEnd = true;
}

public void OnThinkPost(int entity)
{
    if(entity == -1)
        return;
    
    else if(IsMapEnd)
        SDKUnhook(entity, SDKHook_ThinkPost, OnThinkPost);
    
    GetEntDataArray(entity, m_iCompTeammateColor, ColorArray, sizeof(ColorArray));
}

public Action cc_proc_RebuildString(const int mType, int sender, int recipient, int part, int &pLevel, char[] buffer, int size)
{
    if(mType > eMsg_ALL || (part != BIND_STATUS && part != BIND_STATUS_CO) || pLevel > Level)
        return Plugin_Continue;

    if((part == BIND_STATUS && !szStatusSmb[0]) || (part == BIND_STATUS_CO && !EnColor))
        return Plugin_Continue;

    pLevel = Level;

    if(part == BIND_STATUS)
        FormatEx(buffer, size, szStatusSmb);
    
    else FormatEx(buffer, size, "%c", GetColor(sender));

    return Plugin_Continue;
}

int GetColor(int iClient)
{
    static const int colors[] = {9, 14, 4, 11, 16};

    return (ColorArray[iClient] >= sizeof(colors) || ColorArray[iClient] < 0) ? 1 : colors[ColorArray[iClient]];
}
