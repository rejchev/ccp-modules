#pragma newdecls required

#include ccprocessor

public Plugin myinfo = 
{
	name = "[CCP] ServerChat",
	author = "nullent?",
	description = "Create ur server message template",
	version = "1.0",
	url = "discord.gg/ChTyPUG"
};

enum
{
    STATUS = 0,
    TEAM,
    CPREFIX,
    PREFIX,
    CNAME,
    NAME,
    CMESSAGE,

    EMAX
};

ArrayList ServerChat;

public void OnPluginStart()
{
    ServerChat = new ArrayList(NAME_LENGTH, EMAX);

    RegAdminCmd("ccp_sc_check", CmdUse, ADMFLAG_ROOT);
}

Action CmdUse(int iClient, int args)
{
    if(iClient)
        PrintToChat(iClient, "Test message");

    return Plugin_Handled;
}

SMCParser smParser;

public void OnMapStart()
{
#define PATH "configs/c_var/serverchat/serverchat.ini"
    static char szConfig[MESSAGE_LENGTH];

    if(!szConfig[0])
        BuildPath(Path_SM, szConfig, sizeof(szConfig), PATH);

    if(!FileExists(szConfig))
        SetFailState("Where is my config: %s", szConfig);
    
    DeleteSafly(smParser);

    smParser = new SMCParser();
    smParser.OnKeyValue = OnValueRead;

    int iLine;
    if(smParser.ParseFile(szConfig, iLine) != SMCError_Okay)
        LogError("Faile on parse line: %i", iLine);
}

SMCResult OnValueRead(SMCParser smc, const char[] sKey, const char[] sValue, bool bKey_Quotes, bool bValue_quotes)
{
    if(!sKey[0])
        return SMCParse_Continue;

    char szBuffer[NAME_LENGTH];
    strcopy(szBuffer, sizeof(szBuffer), sValue);

    int part;

    if((part = GetPartByKey(sKey)) != -1)
    {
        BreakPoint(part, szBuffer);
        ServerChat.SetString(part, szBuffer);
    }
        
    return SMCParse_Continue;
}

int MessageType;

public void cc_proc_MsgBroadType(const int iType)
{
    MessageType = iType;
}

public void cc_proc_RebuildString(int iClient, int &pLevel, const char[] szBind, char[] szBuffer, int size)
{
    if(MessageType != eMsg_SERVER)
        return;

#define LEVEL 1    
    if(pLevel > LEVEL)
        return;
    
    static int i;
    i = GetPartByKey(szBind);

    if(i == -1)
        return;
    
    static char szValue[NAME_LENGTH];
    ServerChat.GetString(i, szValue, size);

    if(!szValue[0])
        return;
    
    pLevel = LEVEL;
    FormatEx(szBuffer, size, szValue);
}

int GetPartByKey(const char[] szKey)
{
    return  (!strcmp(szKey, "{STATUS}"))        ?   STATUS      : 
            (!strcmp(szKey, "{TEAM}"))          ?   TEAM        :
            (!strcmp(szKey, "{NAME}"))          ?   NAME        :
            (!strcmp(szKey, "{PREFIX}"))        ?   PREFIX      :
            (!strcmp(szKey, "{PREFIXCO}"))      ?   CPREFIX     :
            (!strcmp(szKey, "{NAMECO}"))        ?   CNAME       :
            (!strcmp(szKey, "{MSGCO}"))         ?   CMESSAGE    :
                                                    -1          ;

}

void DeleteSafly(Handle &hHandle)
{
    if(hHandle == INVALID_HANDLE)
        hHandle = null;
    
    delete hHandle;
}

void BreakPoint(int part, char[] szBuffer)
{
    part    =   (part != NAME && part != PREFIX && part != TEAM)    ?   STATUS_LENGTH   :
                (part == NAME)                                      ?   NAME_LENGTH     :
                (part == PREFIX)                                    ?   PREFIX_LENGTH   :
                                                                        TEAM_LENGTH     ;

    if(strlen(szBuffer) >= part)
        szBuffer[part] = 0;
}