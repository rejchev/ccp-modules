// #include <UTF-8-string>

// #pragma newdecls required

// #include <ccprocessor>

// public Plugin myinfo = 
// {
// 	name = "[CCP] Join team",
// 	author = "nullent?",
// 	description = "...",
// 	version = "1.0.7",
// 	url = "https://t.me/nyoood"
// };

// UserMessageType umType;

// stock const char template[] = "#Game_Chat_Radio"

// static const char szTeams[][] = 
// {
//     "#CCP_Join_Dark", 
//     "#CCP_Join_Spec", 
//     "#CCP_Join_Red",
//     "#CCP_Join_Blue"
// };

// public APLRes AskPluginLoad2(Handle myself, bool late, char[] error, int err_max)
// { 
//     umType = GetUserMessageType();
//     return APLRes_Success;
// }

// public void OnPluginStart() {
//     // Temporary solution
//     LoadTranslations("ccp-jointeam.phrases");

//     HookEvent("player_team", EventTeam, EventHookMode_Pre);
// }

// Action EventTeam(Event event, const char[] name, bool dbc) {
//     static const char um[] = "RadioText";

//     event.BroadcastDisabled = true;

//     if(event.GetInt("disconnect")) {
//         return Plugin_Changed;
//     }

//     int iClient;
//     iClient = GetClientOfUserId(event.GetInt("userid"));

//     int iTeam;
//     iTeam = event.GetInt("team");

//     char szName[NAME_LENGTH];
//     GetClientName(iClient, szName, sizeof(szName));

//     int i = 1;
//     int players[1];
//     Handle msg;
//     while(i <= MaxClients) {
//         if(IsClientConnected(i)) {
//             players[0] = i;

//             if((msg = StartMessage(um, players, 1, USERMSG_RELIABLE)) != null) {
//                 if(!umType) {
//                     BfWriteByte(msg, 3);
//                     BfWriteByte(msg, iClient);
//                     BfWriteString(msg, "#Game_Radio");
//                     BfWriteString(msg, szName);
//                     BfWriteString(msg, szTeams[iTeam]);
//                 } else {
//                     // 5 params = max
//                     PbSetInt(msg, "msg_dst", 3);
//                     PbSetInt(msg, "client", iClient);
//                     PbSetString(msg, "msg_name", "#Game_Radio");

//                     PbAddString(msg, "params", szName);
//                     PbAddString(msg, "params", szTeams[iTeam]);
//                     PbAddString(msg, "params", NULL_STRING);
//                     PbAddString(msg, "params", NULL_STRING);
//                 }

//                 EndMessage();
//             }
//         }

//         i++;
//     }
    
//     return Plugin_Changed;
// }

// // public Processing  cc_proc_OnRebuildString(const int[] props, int part, ArrayList params, int &level, char[] value, int size) {
// //     static const char channel[] = "TM";

// //     char szIdent[64];
// //     params.GetString(0, szIdent, sizeof(szIdent));

// //     char szTemplate[64];
// //     params.GetString(1, szTemplate, sizeof(szTemplate));

// //     LogMessage("Ident: %s, Template: %s, Sender: %d, Rec: %d, Team: %d, Value: %s", szIdent, szTemplate, SENDER_INDEX(props[1]), props[2], joinTeam[SENDER_INDEX(props[1])], value);
    
// //     if(strcmp(szIdent, channel) != 0 || part != BIND_MSG || joinTeam[SENDER_INDEX(props[1])] == -1) {
// //         return Proc_Continue;
// //     }  

// //     if(strcmp(szTemplate, KEY) != 0 && joinTeam[SENDER_INDEX(props[1])] != -1) {
// //         joinTeam[SENDER_INDEX(props[1])] = -1;
// //         return Proc_Continue;
// //     }

// //     ReplaceStringEx(value, size, "%s2", GetTeamName(joinTeam[SENDER_INDEX(props[1])], props[2]));
// //     return Proc_Change;
// // }

// // char[] GetTeamName(int team, int lang)
// // {
// //     char szTeam[TEAM_LENGTH];

// //     FormatEx(szTeam, sizeof(szTeam), "%T",
// //         szTeams[team],
// //         lang
// //     );

// //     return szTeam;
// // }