#pragma newdecls required

#include <ccprocessor>

public Plugin myinfo = 
{
	name = "[CCP] CCMessage",
	author = "nullent?",
	description = "Custom client message",
	version = "3.0.0",
	url = "discord.gg/ChTyPUG"
};

enum eAccess
{
    eNone = 0,
    eDefault,
    eAuth,
    eFlag,
    eGroup
};

// Now it can work with all binds ;;;
enum struct MessageEnv
{
    eAccess     m_AType;

    StringMap   m_smTemplate;

    char        m_szBuffer[64];

    void Destroy()
    {
        this.m_AType = eNone;
        this.m_szBuffer[0] = 0;
        this.m_smTemplate = null;
    }

    bool IsValid()
    {
        return this.m_AType != eNone && this.m_smTemplate && this.m_smTemplate != INVALID_HANDLE;
    }

    void InitMap()
    {
        this.Destroy();
        this.m_smTemplate = new StringMap();
    }
}

enum struct ClientEnv
{
    MessageEnv  m_EMessage;

    AdminId     m_aId;
    int         m_iFlags;

    char        m_szAuth[64];

    bool IsTeamplateEqual(MessageEnv nMEMessage)
    {
        return this.m_EMessage.m_smTemplate == nMEMessage.m_smTemplate;
    }

    void SetTemplate(MessageEnv nMEMessage)
    {
        this.m_EMessage = nMEMessage;
    }

    bool GetValue(const char[] szBind, char[] szBuffer, int size)
    {
        return this.m_EMessage.m_smTemplate.GetString(szBind, szBuffer, size);
    }

    bool IsValidMap()
    {
        return this.m_EMessage.IsValid();
    }

    eAccess GetTemplateAccess()
    {
        return this.m_EMessage.m_AType;
    }

    void Clear()
    {
        this.m_EMessage.Destroy();
        this.m_aId = INVALID_ADMIN_ID;
        this.m_iFlags = 0;
        this.m_szAuth[0] = 0;
    }
}

ClientEnv clMessage[MAXPLAYERS+1];

ArrayList aProtoBase;

int PLEVEL[BIND_MAX];

ConVar cvPriority[BIND_MAX];

bool
    IsMenuDisabled,
    DisableToDef;

public void OnPluginStart()
{
    LoadTranslations("ccp_customchat.phrases");

    aProtoBase = new ArrayList(NAME_LENGTH, 0);

    CreateConVars();

    RegConsoleCmd("sm_prefix", Cmd_Prefix);
}

void CreateConVars()
{
    char szBuffer[NAME_LENGTH];

    for(int i; i < BIND_MAX; i++)
    {
        FormatEx(szBuffer, sizeof(szBuffer), "ccm_priority_%s", szBinds[i]);

        ReplaceString(szBuffer, sizeof(szBuffer), "{", "");
        ReplaceString(szBuffer, sizeof(szBuffer), "}", "");
        
        (cvPriority[i] = CreateConVar(szBuffer, "1", "Value replacement priority", _, true, 0.0)).AddChangeHook(OnLevelChanged); 
    }

    CreateConVar("ccm_disable_todefault", "1", "Default value as default", _, true, 0.0, true, 1.0).AddChangeHook(OnDefaultChanged);
    CreateConVar("ccm_disable_menu", "0", "Disable menu", _, true, 0.0, true, 1.0).AddChangeHook(OnMenuStateChanged);

    AutoExecConfig(true, "ccp_ccmessage", "ccprocessor");
}

public void OnLevelChanged(ConVar convar, const char[] oldVal, const char[] newVal)
{
    for(int i; i < BIND_MAX; i++)
        PLEVEL[i] = cvPriority[i].IntValue;
}

public void OnDefaultChanged(ConVar convar, const char[] oldVal, const char[] newVal)
{
    DisableToDef = FindConVar("ccm_disable_todefault").BoolValue;
}

public void OnMenuStateChanged(ConVar convar, const char[] oldVal, const char[] newVal)
{
    IsMenuDisabled = FindConVar("ccm_disable_menu").BoolValue;
}

public void OnMapStart()
{
    cc_proc_APIHandShake(cc_get_APIKey());

    OnLevelChanged(null, NULL_STRING, NULL_STRING);
    OnDefaultChanged(null, NULL_STRING, NULL_STRING);
    OnMenuStateChanged(null, NULL_STRING, NULL_STRING);

    static char szFullPath[MESSAGE_LENGTH] = "configs/c_var/customchat/customchat.ini";
    
    if(szFullPath[0] == 'c')
        BuildPath(Path_SM, szFullPath, sizeof(szFullPath), szFullPath);
    
    else if(!FileExists(szFullPath))
        SetFailState("Where is my config: %s", szFullPath);

    aProtoBase.Clear();

    SMCParser smParser = new SMCParser();

    smParser.OnEnterSection = OnNewSection;
    smParser.OnKeyValue = OnValueRead;
    smParser.OnLeaveSection = OnLeaveSection;
    smParser.OnEnd = OnEndRead;

    int iLine;

    if(smParser.ParseFile(szFullPath, iLine) != SMCError_Okay)
        LogError("Error On parse: %s | Line: %i", szFullPath, iLine);
}

MessageEnv g_MEBuffer;

SMCResult OnNewSection(SMCParser smc, const char[] name, bool opt_quotes)
{
    if(strcmp(name, "CustomChat", false))
    {
        g_MEBuffer.InitMap();

        LogMessage("Section: %s", name);
        LogMessage("SMap: %x", g_MEBuffer.m_smTemplate);
    }

    return SMCParse_Continue;
}

SMCResult OnLeaveSection(SMCParser smc)
{
    if(g_MEBuffer.IsValid())
    {
        aProtoBase.PushArray(g_MEBuffer, sizeof(g_MEBuffer));

        g_MEBuffer.Destroy();
    }

    return SMCParse_Continue;
}

SMCResult OnValueRead(SMCParser smc, const char[] sKey, const char[] sValue, bool bKey_Quotes, bool bValue_quotes)
{
    if(!sKey[0])
        return SMCParse_Continue;

    if(!strcmp(sKey, "type"))
        g_MEBuffer.m_AType = CharToAccessType(sValue);
    
    else if(!strcmp(sKey, "type_value"))
        strcopy(g_MEBuffer.m_szBuffer, sizeof(g_MEBuffer.m_szBuffer), sValue);
    
    else if(!strcmp(sKey, "type_prototype"))
        g_MEBuffer.m_smTemplate.SetString(szBinds[BIND_PROTOTYPE], sValue, true);
    
    else if(!strcmp(sKey, "type_status"))
        g_MEBuffer.m_smTemplate.SetString(szBinds[BIND_STATUS], sValue, true);
    
    else if(!strcmp(sKey, "type_team"))
        g_MEBuffer.m_smTemplate.SetString(szBinds[BIND_TEAM], sValue, true);
    
    else if(!strcmp(sKey, "type_prefix_color"))
        g_MEBuffer.m_smTemplate.SetString(szBinds[BIND_PREFIX_CO], sValue, true);
    
    else if(!strcmp(sKey, "type_prefix"))
        g_MEBuffer.m_smTemplate.SetString(szBinds[BIND_PREFIX], sValue, true);

    else if(!strcmp(sKey, "type_name_color"))
        g_MEBuffer.m_smTemplate.SetString(szBinds[BIND_NAME_CO], sValue, true);
    
    else if(!strcmp(sKey, "type_name"))
        g_MEBuffer.m_smTemplate.SetString(szBinds[BIND_NAME], sValue, true);

    else if(!strcmp(sKey, "type_msg_color"))
        g_MEBuffer.m_smTemplate.SetString(szBinds[BIND_MSG_CO], sValue, true);
    
    else if(!strcmp(sKey, "type_msg"))
        g_MEBuffer.m_smTemplate.SetString(szBinds[BIND_MSG], sValue, true);

    return SMCParse_Continue;
}

void OnEndRead(SMCParser smc, bool halted, bool failed)
{
    if(smc == INVALID_HANDLE)
        smc = null;
    
    delete smc;
}

public void OnClientPutInServer(int iClient)
{
    clMessage[iClient].Clear();

    GetClientAuthId(iClient, AuthId_Engine, clMessage[iClient].m_szAuth, sizeof(clMessage[].m_szAuth));

    GetClientProto(iClient);
}

public void OnClientPostAdminCheck(int iClient)
{
    clMessage[iClient].m_iFlags = GetUserFlagBits(iClient);
    clMessage[iClient].m_aId = GetUserAdmin(iClient);

    GetClientProto(iClient);
}

void GetClientProto(int iClient)
{
    MessageEnv EBuffer;

    for(int i; i < aProtoBase.Length; i++)
    {
        aProtoBase.GetArray(i, EBuffer, sizeof(EBuffer));

        if(ClientHasAccess(EBuffer, clMessage[iClient].m_szAuth, clMessage[iClient].m_iFlags, clMessage[iClient].m_aId))
            clMessage[iClient].SetTemplate(EBuffer);
        
        EBuffer.Destroy();
    }
}

public Action Cmd_Prefix(int iClient, int args)
{
    if(iClient && IsClientInGame(iClient) && !IsFakeClient(iClient))
    {
        if(!IsMenuDisabled)
        {
            Menu menu = GetClientPrototypes(iClient);
            if(menu)
                menu.Display(iClient, MENU_TIME_FOREVER);
        }
        else
        {
            switch(clMessage[iClient].GetTemplateAccess())
            {
                case eNone:
                {
                    if(!DisableToDef) GetClientProto(iClient);
                }

                case eDefault:
                {
                    if(DisableToDef) GetClientProto(iClient);
                    else clMessage[iClient].m_EMessage.Destroy();
                }

                default:
                    GetTemplateByAccess(iClient, (DisableToDef) ? eDefault : eNone);
            }
        }
    }
    
    return Plugin_Handled;
}

Menu GetClientPrototypes(int iClient)
{
    Menu hMenu;

    if(aProtoBase.Length)
    {
        hMenu = new Menu(PrefList_CallBack);
        hMenu.SetTitle("%T \n \n", "ccm_proto_list", iClient);

        char szBuffer[PREFIX_LENGTH], szOpt[8];
        int DRAWTYPE, a;
        MessageEnv EBuffer;

        FormatEx(szBuffer, sizeof(szBuffer), "%T \n \n", "ccp_disable", iClient);
        hMenu.AddItem("r", szBuffer, (!clMessage[iClient].IsValidMap() || (DisableToDef && clMessage[iClient].GetTemplateAccess() == eDefault)) ? ITEMDRAW_DISABLED : ITEMDRAW_DEFAULT);

        for(int i; i < aProtoBase.Length; i++)
        {
            EBuffer.Destroy();

            aProtoBase.GetArray(i, EBuffer, sizeof(EBuffer));

            if(!ClientHasAccess(EBuffer, clMessage[iClient].m_szAuth, clMessage[iClient].m_iFlags, clMessage[iClient].m_aId))
                continue;

            DRAWTYPE = (clMessage[iClient].IsTeamplateEqual(EBuffer)) ? ITEMDRAW_DISABLED : ITEMDRAW_DEFAULT;
            
            GetTranslationByAccess(iClient, EBuffer.m_AType, EBuffer.m_szBuffer, szBuffer, sizeof(szBuffer));

            IntToString(i, szOpt, sizeof(szOpt));

            hMenu.AddItem(szOpt, szBuffer, DRAWTYPE);
            a++;
        }

        if(hMenu.ItemCount == 1) delete hMenu;
    }

    return hMenu;
}

void GetTemplateByAccess(int iClient, eAccess AValue)
{
    MessageEnv EBuffer;

    if(AValue == eNone)
    {
        clMessage[iClient].m_EMessage.Destroy();
        return;
    }
        
    for(int i; i < aProtoBase.Length; i++)
    {
        aProtoBase.GetArray(i, EBuffer, sizeof(EBuffer));

        if(EBuffer.m_AType == AValue)
        {
            clMessage[iClient].SetTemplate(EBuffer);
            return;
        }
    }

    EBuffer.Destroy();
}

public int PrefList_CallBack(Menu hMenu, MenuAction action, int iClient, int iOpt2)
{
    switch(action)
    {
        case MenuAction_End: delete hMenu;
        case MenuAction_Select:
        {
            char szOpt[8];
            hMenu.GetItem(iOpt2, szOpt, sizeof(szOpt));
            
            if(szOpt[0] == 'r')
            {
                if(!DisableToDef) clMessage[iClient].m_EMessage.Destroy();
                else GetTemplateByAccess(iClient, eDefault);

                return;
            }

            aProtoBase.GetArray(StringToInt(szOpt), clMessage[iClient].m_EMessage, sizeof(clMessage[].m_EMessage));              
        }
    }
}

int iType;

public void cc_proc_MsgBroadType(const int typeMsg)
{
    iType = typeMsg;
}

public void cc_proc_RebuildString(int iClient, int &pLevel, const char[] szBind, char[] szBuffer, int iSize)
{
    // Only for standart client messages;;;
    if(iType == eMsg_SERVER || iType == eMsg_CNAME || iType == eMsg_RADIO  || !clMessage[iClient].IsValidMap())
        return;
    
    static int i;
    i = CharToNumBind(szBind);
    
    if(PLEVEL[i] < pLevel)
        return;
    
    static char szValue[MESSAGE_LENGTH];
    if(!clMessage[iClient].GetValue(szBind, szValue, sizeof(szValue)))
        return;
    
    pLevel = PLEVEL[i];
    FormatEx(szBuffer, iSize, "%s", szValue);  
}

// define
bool ClientHasAccess(MessageEnv MEMessage, const char[] auth = NULL_STRING, const int flags = 0, const AdminId aid = INVALID_ADMIN_ID)
{
    switch(MEMessage.m_AType)
    {
        case eDefault:  
            return true;

        case eAuth:
            return !strcmp(MEMessage.m_szBuffer, auth);

        case eFlag:
            return flags && (flags & ReadFlagString(MEMessage.m_szBuffer));

        case eGroup:
        {
            if(aid == INVALID_ADMIN_ID)
                return false;
            
            char szBuffer[64];
            
            for(int i; i < aid.GroupCount; i++)
            {
                aid.GetGroup(i, szBuffer, sizeof(szBuffer));
                if(StrEqual(MEMessage.m_szBuffer, szBuffer))
                    return true;
            }
        }
    }

    return false;
}

// auth, flag, group
eAccess CharToAccessType(const char[] szAccess)
{
    return (!strcmp(szAccess, "auth", false)) ? eAuth : (!strcmp(szAccess, "flag", false)) ? eFlag : (!strcmp(szAccess, "group", false)) ? eGroup : (!strcmp(szAccess, "default", false)) ? eDefault : eNone;
}

void GetTranslationByAccess(int iClient, const eAccess accessType, const char[] szValue, char[] szBuffer, int size)
{
    SetGlobalTransTarget(iClient);

    switch(accessType)
    {
        case eDefault: FormatEx(szBuffer, size, "%t", "ccm_default_item");
        case eAuth: FormatEx(szBuffer, size, "%t", "ccm_personal_item");
        case eFlag: FormatEx(szBuffer, size, "%t", "ccm_flag_item", szValue);
        case eGroup: FormatEx(szBuffer, size, "%t", "ccm_group_item", szValue);
    }
}

int CharToNumBind(const char[] szBind)
{
    for(int i; i < BIND_MAX; i++)
        if(!strcmp(szBinds[i], szBind))
            return i;
    
    // But that will never happen :|
    return BIND_MAX;
}

stock char AccessTypeToChar(eAccess eAValue)
{
    char szAccess[12];

    switch(eAValue)
    {
        case eAuth: szAccess = "auth";
        case eFlag: szAccess = "flag";
        case eGroup: szAccess = "group";
        case eDefault: szAccess = "default";
    }

    return szAccess;
}