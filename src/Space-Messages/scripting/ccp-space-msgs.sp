#pragma newdecls required

#include <ccprocessor>

#undef REQUIRE_EXTENSIONS
#include <ripext_m>
#define REQUIRE_EXTENSIONS

public Plugin myinfo = 
{
	name = "[CCP] Space Messages",
	author = "nullent?",
	description = "...",
	version = "1.0.1",
	url = "discord.gg/ChTyPUG"
};

JSONObject objConfig;

public void OnMapStart() {
    cc_proc_APIHandShake(cc_get_APIKey());

    static char szBuffer[MESSAGE_LENGTH] = "configs/ccprocessor/space-msgs/settings.json";
    if(szBuffer[0] == 'c') {
        BuildPath(Path_SM, szBuffer, sizeof(szBuffer), szBuffer);
    } else if(!FileExists(szBuffer)) {
        SetFailState("Where is my config: %s", szBuffer);
    }

    delete objConfig;
    objConfig = JSONObject.FromFile(szBuffer, 0);
}

public bool cc_proc_OnRebuildString_Post(
    int mid, const char[] indent, int sender,
    int recipient, int part, int level,
    const char[] value
) {
    if(part != BIND_MSG) {
        return false;
    }

    if(!objConfig.GetBool(indent)) {
        for(int i; i < strlen(value); i++) {
            if(value[i] >= 33) {
                return false;
            }
        }

        return true;
    }

    return false;
}

