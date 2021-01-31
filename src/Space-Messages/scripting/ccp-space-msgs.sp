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
	version = "1.0.0",
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

public bool cc_proc_RebuildString_Post(const int mType, int sender, int recipient, int part, int pLevel, const char[] szValue) {
    if(part != BIND_MSG) {
        return false;
    }

    if(!objConfig.GetBool(szMsgTypes[mType])) {
        for(int i; i < strlen(szValue); i++) {
            if(szValue[i] >= 33) {
                return false;
            }
        }

        return true;
    }

    return false;
}

