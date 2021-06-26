#pragma newdecls required

#include <ccprocessor>

#if defined INCLUDE_DEBUG
    #define DEBUG "[Fake-Username]"
#endif

public Plugin myinfo = 
{
	name = "[CCP] Fake Username",
	author = "nullent?",
	description = "Ability to set a fake username in chat msgs",
	version = "1.5.3",
	url = "discord.gg/ChTyPUG"
};

int replacementLevel;
int ROOT;
int accessFlag;

char liars[MAXPLAYERS+1][NAME_LENGTH];

public void OnPluginStart() {    
    ROOT = ReadFlagString("z");

    RegConsoleCmd("sm_fakename", OnCmdUse);
}

public void OnMapStart() {
    #if defined DEBUG
        DBUILD()
    #endif

    cc_proc_APIHandShake(cc_get_APIKey());

    static char config[MESSAGE_LENGTH]  = "configs/ccprocessor/fake-username/settings.ini";

    if(config[0] == 'c')
        BuildPath(Path_SM, config, sizeof(config), config);
    
    if(!FileExists(config))
        SetFailState("Where is my config: %s", config);

    KeyValues kv;
    
    if((kv = new KeyValues("settings")) && kv.ImportFromFile(config)) {
        replacementLevel = kv.GetNum("level", 1);

        char buffer[8];
        kv.GetString("access", buffer, sizeof(buffer), NULL_STRING);

        accessFlag = ReadFlagString(buffer);
    }

    delete kv;

    #if defined DEBUG
    DWRITE("%s: OnMapStart():  \n
            \t\t\t\tConfig: %s \n
            \t\t\t\tLevel: %d  \n
            \t\t\t\tFlag: %s", DEBUG, config, replacementLevel, accessFlag);
    #endif
}

public Action OnCmdUse(int iClient, int args) {
    if(args == 1 && iClient && IsClientInGame(iClient) && isValid(iClient)) {
        GetCmdArg(1, liars[iClient], sizeof(liars[]));

        #if defined DEBUG
        DWRITE("%s: OnCmdUse():    \n
                \t\t\t\tClient: %N \n
                \t\t\t\tValue: %s", DEBUG, iClient, liars[iClient]);
        #endif
    }

    return Plugin_Handled;
}

public void OnClientPutInServer(int iClient) {
    liars[iClient] = NULL_STRING;
}

public Processing  cc_proc_OnRebuildString(const int[] props, int part, ArrayList params, int &level, char[] value, int size) {
    static const char channels[][] = {"STA", "STP"};

    if(part != BIND_NAME || replacementLevel < level) 
        return Proc_Continue;

    char buffer[64];
    params.GetString(0, buffer, sizeof(buffer));

    if(FindChannelInChannels(channels, buffer, true) == -1 || !liars[SENDER_INDEX(props[1])][0])
        return Proc_Continue; 

    level = replacementLevel;
    FormatEx(value, size, "%s", liars[SENDER_INDEX(props[1])]);

    return Proc_Change
}

bool isValid(int iClient) {
    if(!accessFlag)
        return false;

    int bits = GetUserFlagBits(iClient);

    return (bits & accessFlag) || (bits & ROOT);
}