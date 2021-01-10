#pragma newdecls required

#include <ccprocessor>

static const char trigger[] = "#";

bool IsAdminChannel;

public Plugin myinfo = 
{
	name = "[CCP] Admin channel",
	author = "nu11ent",
	description = "...",
	version = "1.0.0",
	url = "https://t.me/nyoood"
};

public void OnPluginStart() {
    LoadTranslations("admin-channel.phrases");
}

public void cc_proc_MsgUniqueId(int mType, int sender, int msgId, const char[] message, const int[] clients, int count) {
    IsAdminChannel = false;

    if(mType > eMsg_ALL || !sender) {
        return;
    }

    IsAdminChannel = (message[0] == trigger[0] && GetUserAdmin(sender) != INVALID_ADMIN_ID);
}

public void cc_proc_RebuildClients(const int mType, int iClient, int[] clients, int &numClients) {
    if(!IsAdminChannel || !numClients || IsClientSourceTV(clients[0])) {
        return;
    }

    numClients = 0;
    for(int i = 1; i <= MaxClients; i++) {
        if(IsClientInGame(i) && !IsFakeClient(i) && GetUserAdmin(i) != INVALID_ADMIN_ID) {
            clients[numClients++] = i;
        }
    }
}

public Action cc_proc_RebuildString(const int mType, int sender, int recipient, int part, int &pLevel, char[] buffer, int size) {
    if(IsAdminChannel) {

        if(part == BIND_TEAM) {
            FormatEx(buffer, size, "%T", "team_admin", recipient);
        } else if(part == BIND_TEAM_CO) {
            FormatEx(buffer, size, "%T", "team_color", recipient);
        } else if(part == BIND_MSG) {
            ReplaceStringEx(buffer, size, trigger, "", -1, -1, false);
        }

    }
}