#pragma newdecls required

#include <ccprocessor>

public Plugin myinfo = 
{
	name = "[CCP] ChatWheel Fix",
	author = "nullent?",
	description = "...",
	version = "1.0.1",
	url = "https://t.me/nyoood"
};

public Action cc_proc_OnRebuildString(const int[] props, int part, ArrayList params, int &level, char[] value, int size) {
	char indent[64];
	params.GetString(0, indent, sizeof(indent));

	if(indent[0] == 'R' && indent[1] == 'T' && strlen(indent) == 2) {
		if(part == BIND_NAME && !value[0]) {
			GetClientName(props[2], value, size);
		}
	}

    return Plugin_Continue;
}