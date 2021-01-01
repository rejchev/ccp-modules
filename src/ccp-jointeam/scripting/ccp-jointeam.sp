#include <UTF-8-string>

#pragma newdecls required

#include <ccprocessor>

public Plugin myinfo = 
{
	name = "[CCP] Join team",
	author = "nullent?",
	description = "...",
	version = "1.0.2",
	url = "https://t.me/nyoood"
};

// Imitation
// params: {1} - name, {2} - team
#define KEY "#Game_team_change"

// #define T  "#terrorists"
// #define CT "#counter-terrorists"

UserMessageType umType;

int msgCaller;

public APLRes AskPluginLoad2(Handle myself, bool late, char[] error, int err_max)
{ 
    umType = GetUserMessageType();
    return APLRes_Success;
}

public void OnPluginStart() {
    // Temporary solution
    LoadTranslations("ccp-jointeam.phrases");

    HookEvent("player_team", EventTeam, EventHookMode_Pre);
}

Action EventTeam(Event event, const char[] name, bool dbc) {
        
    // this is too bad thing...
    // i'll fix it later
    event.BroadcastDisabled = true;

    if(event.GetInt("disconnect")) {
        return Plugin_Changed;
    }

    int iClient = GetClientOfUserId(event.GetInt("userid"));
    int iTeam = event.GetInt("team");

    char szName[NAME_LENGTH];
    GetClientName(iClient, szName, sizeof(szName));

    // char szTeam[NAME_LENGTH];
    // GetTeamName(iTeam, iClient, szTeam, sizeof(szTeam));

    // {1} - username
    // {2} - team key
    TriggerUMessage(iClient, szName, (iTeam < 2) ? "spectators" : (iTeam == 2) ? "terrorists" : "counter-terrorists");

    return Plugin_Changed;
}

void TriggerUMessage(int iClient, const char[] username, const char[] teamname)
{
    static const char um[] = "TextMsg";

    // The handler will do the rest.
    Handle msg =
        StartMessageAll(um, USERMSG_RELIABLE);

    if(!msg) {
        return;
    }

    msgCaller = iClient;

    if(!umType) {
        BfWriteByte(msg, 3);
        BfWriteString(msg, KEY);
        BfWriteString(msg, username);
        BfWriteString(msg, teamname);
    } else {
        // 5 params = max
        PbSetInt(msg, "msg_dst", 3);
        PbAddString(msg, "params", KEY);
        PbAddString(msg, "params", username);
        PbAddString(msg, "params", teamname);

        PbAddString(msg, "params", NULL_STRING);
        PbAddString(msg, "params", NULL_STRING);
    }

    EndMessage();
}

public Action cc_proc_RebuildString(const int mType, int sender, int recipient, int part, int &pLevel, char[] buffer, int size) {
    if(mType != eMsg_SERVER || part != BIND_MSG || !msgCaller)
        return Plugin_Continue;
    
    // ....
    char team[PREFIX_LENGTH];
    GetTeamName(GetClientTeam(msgCaller), recipient, team, sizeof(team));

    msgCaller = 0;

    // after prepareDefMessage();
    ReplaceStringEx(buffer, size, "%s2", team);

    return Plugin_Continue;
}

void GetTeamName(int team, int lang, char[] buffer, int size)
{
    if(team < 2) {
        FormatEx(buffer, size, "%T", "spectators", lang);
    } else {
        FormatEx(buffer, size, "%T", (
            (team == 2) ? "terrorists" : "counter-terrorists"
        ), lang);
    }

    // ccp_replaceColors(buffer, false);
}