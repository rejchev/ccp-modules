#pragma newdecls required

#include <ccprocessor>

public Plugin myinfo = 
{
	name = "[CCP] Join team",
	author = "nullent?",
	description = "...",
	version = "1.0.1",
	url = "https://t.me/nyoood"
};

// Imitation
// params: {1} - name, {2} - team
#define KEY "#Game_team_change"

// #define T  "#terrorists"
// #define CT "#counter-terrorists"

UserMessageType umType;

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

    char szTeam[NAME_LENGTH];
    GetTeamName(iTeam, szTeam, sizeof(szTeam));

    TriggerUMessage(szName, szTeam);

    return Plugin_Changed;
}

void TriggerUMessage(const char[] username, const char[] teamname)
{
    static const char um[] = "TextMsg";

    // The handler will do the rest.
    Handle msg =
        StartMessageAll(um, USERMSG_RELIABLE);

    if(!msg) {
        return;
    }

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

void GetTeamName(int team, char[] buffer, int size)
{
    if(team < 2) {
        FormatEx(buffer, size, "%T", "spectators", 0);
    } else {
        FormatEx(buffer, size, "%T", (
            (team == 2) ? "terrorists" : "counter-terrorists"
        ), 0);
    }

    ccp_replaceColors(buffer, false);
}