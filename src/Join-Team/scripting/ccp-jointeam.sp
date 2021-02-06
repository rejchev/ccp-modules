#include <UTF-8-string>

#pragma newdecls required

#include <ccprocessor>

public Plugin myinfo = 
{
	name = "[CCP] Join team",
	author = "nullent?",
	description = "...",
	version = "1.0.5",
	url = "https://t.me/nyoood"
};

// Imitation
// params: {1} - name, {2} - team
#define KEY "#Game_team_change"

UserMessageType umType;

int initiatorTeam;

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
    event.BroadcastDisabled = true;

    if(event.GetInt("disconnect")) {
        return Plugin_Changed;
    }

    int iClient = GetClientOfUserId(event.GetInt("userid"));
    int iTeam = event.GetInt("team");

    char szName[NAME_LENGTH];
    GetClientName(iClient, szName, sizeof(szName));

    // {1} - username
    // {2} - team key
    TriggerUMessage(iTeam, szName, (iTeam < 2) ? "spectators" : (iTeam == 2) ? "terrorists" : "counter-terrorists");

    return Plugin_Changed;
}

void TriggerUMessage(int iTeam, const char[] username, const char[] teamname)
{
    static const char um[] = "TextMsg";

    Handle msg;
    if(!(msg = StartMessageAll(um, USERMSG_RELIABLE))) {
        return;
    }

    initiatorTeam = iTeam;

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

public Action cc_proc_OnRebuildString(
    int mid, const char[] indent, int sender,
    int recipient, int part, int &level, 
    char[] buffer, int size
) {
    if(strcmp(indent, "TM") != 0 || initiatorTeam == -1 || part != BIND_MSG)
        return Plugin_Continue;
    
    // after prepareDefMessage();
    ReplaceStringEx(buffer, size, "%s2", GetTeamName(initiatorTeam, recipient));
    return Plugin_Continue;
}

public void cc_proc_OnMessageEnd(
    int mid, const char[] indent, int sender
) {
    if(strcmp(indent, "TM") == 0 && initiatorTeam != -1) {
        initiatorTeam = -1;
    }
}

char[] GetTeamName(int team, int lang)
{
    char szTeam[TEAM_LENGTH];

    FormatEx(szTeam, sizeof(szTeam), "%T",
        (team < 2)
            ? "spectators"
            : (team == 2)
                ? "terrorists"
                : "counter-terrorists",
        lang
    );

    return szTeam;
}