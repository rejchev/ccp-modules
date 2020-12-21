#pragma newdecls required

#include <ccprocessor>

public Plugin myinfo = 
{
	name = "[CCP] ChatWheel Fix",
	author = "nullent?",
	description = "...",
	version = "1.0.0",
	url = "https://t.me/nyoood"
};

public Action cc_proc_RebuildString(const int mType, int sender, int recipient, int part, int &pLevel, char[] buffer, int size) {
    if(mType == eMsg_RADIO && part == BIND_NAME && !buffer[0]) {
        GetClientName(recipient, buffer, size); // because sender is GoTV/Server...
    } 

    return Plugin_Continue;
}