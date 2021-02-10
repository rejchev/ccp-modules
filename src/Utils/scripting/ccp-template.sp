// /*
//     Output:

//     # userid name uniqueid connected ping loss state rate
//     # 57 1 "nyoood" STEAM_1:0:453689426 00:24 31 0 active 196608
//     #58 "Grant" BOT active 64
//     #59 "Harold" BOT active 64
//     #60 "Mark" BOT active 64
//     #61 "Steve" BOT active 64
//     #62 "Greg" BOT active 64
//     #63 "Jon" BOT active 64
//     #64 "Pat" BOT active 64
//     #65 "Wyatt" BOT active 64
//     #66 "Dustin" BOT active 64
//     #end

//     ] sm_template #57 1
//     Template: {STATUS} {TEAM} {PREFIXCO}{PREFIX} {NAMECO}{NAME}{W}: {MSGCO}{MSG}
//     ] sm_template #57 2
//     Template: {G}{NAME} {T}changed name to {G}{MSG}
//     ] sm_template #57 3
//     Template: {STATUS} {TEAM} {PREFIXCO}{PREFIX} {NAMECO}{NAME}{W}: {MSGCO}{MSG}
//     ] sm_template #57 4
//     ] sm_template #0 4
//     Template: {MSG}
//     ] sm_template #58 1
//     Template: {STATUS} {TEAM} {PREFIXCO}{PREFIX} {NAMECO}{NAME}{W}: {MSGCO}{MSG}
// */

// #pragma newdecls required

// #include <ccprocessor>

// bool IsViewer[MAXPLAYERS+1];

// public Plugin myinfo = 
// {
// 	name = "[CCP] Template viewer",
// 	author = "nullent?",
// 	description = "...",
// 	version = "1.0.0",
// 	url = "https://t.me/nyoood"
// };

// public void OnPluginStart() {
//     RegAdminCmd("sm_template", cmduse, ADMFLAG_ROOT);
// }

// // sm_template <#uid> <mtype>
// Action cmduse(int iClient, int args) {
//     char szArgs[8];

//     if(args != 2) {
//         return Plugin_Handled;
//     }

//     GetCmdArg(1, szArgs, sizeof(szArgs));

//     int target = GetClientOfUserId(StringToInt(szArgs[1]));

//     if(StringToInt(szArgs[1]) && !IsClientConnected(target)) {
//         ReplyToCommand(iClient, "Invalid user: %s", szArgs);
//         return Plugin_Handled;
//     }

//     GetCmdArg(2, szArgs, sizeof(szArgs));

//     int mtype = StringToInt(szArgs);

//     if(mtype < eMsg_TEAM || mtype >= eMsg_MAX) {
//         return Plugin_Handled;
//     }   

//     if((mtype == eMsg_SERVER && target != 0) || (!target && mtype != eMsg_SERVER)) {
//         return Plugin_Handled;
//     }

//     IsViewer[iClient] = true;
//     cc_call_builder(mtype, target, iClient, "dev", NULL_STRING, NULL_STRING, szArgs, sizeof(szArgs));
//     return Plugin_Handled;
// }

// public bool cc_proc_RebuildString_Post(const int mType, int sender, int recipient, int part, int pLevel, const char[] szValue) {    
//     if(part != BIND_PROTOTYPE) {
//         return false;
//     }

//     for(int i = 1; i <= MaxClients; i++) {
//         if(IsViewer[i]) {
//             ReplyToCommand(i, "Template: %s", szValue);
//             IsViewer[i] = false;
//         }
//     }

//     return false;
// }