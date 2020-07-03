#include UTF-8-string

#pragma newdecls required

#include vip_core
#include ccprocessor
#include clientprefs

public Plugin myinfo = 
{
	name = "[CCP] VIP Chat",
	author = "nullent?",
	description = "Chat features for VIP by user R1KO",
	version = "1.5.2",
	url = "discord.gg/ChTyPUG"
};

#define _CONFIG_PATH "data\\vip\\modules\\chat.ini"

#define SZ(%0)	%0, sizeof(%0)
#define BUILD(%0,%1) BuildPath(Path_SM, SZ(%0), %1)
#define _CVAR_INIT_CHANGE(%0,%1) %0(FindConVar(%1), NULL_STRING, NULL_STRING)
#define _CVAR_ON_CHANGE(%0) public void %0(ConVar cvar, const char[] szOldVal, const char[] szNewVal)

#define PMP PLATFORM_MAX_PATH
#define MPL MAXPLAYERS+1

enum
{
    CPREFIX = 0,
    CNAME,
    CMESSAGE,
    VPREFIX,

    E_MAX
};

ArrayList aPalette;

int nLevel[E_MAX];

char ccl_current_feature[MPL][20];

bool bCustom[MPL];

Handle coFeatures[E_MAX];

bool blate;

ArrayList aFeatureList;

static const char g_szFeatures[][] = {"vip_prefix_color", "vip_name_color", "vip_message_color", "vip_prefix"};

enum struct TemplatePart
{
    char m_szValue[PREFIX_LENGTH];

    char GetValue()
    {
        return this.m_szValue;
    }

    void SetValue(const char[] szValue)
    {
        strcopy(this.m_szValue, PREFIX_LENGTH, szValue);
    }

    bool IsValidPart()
    {
        return this.m_szValue[0] != 0;
    }
    
    void ResetPart()
    {
        this.m_szValue[0] = 0;
    }
}

enum struct ClientTemplate
{
    TemplatePart m_tpCPrefix;
    TemplatePart m_tpLPrefix;
    TemplatePart m_tpCName;
    TemplatePart m_tpCMessage;

    TemplatePart m_tpBuffer;

    char m_szVIPGroup[PREFIX_LENGTH];

    char GetGroup()
    {
        return this.m_szVIPGroup;
    }

    void ResetGroup()
    {
        this.m_szVIPGroup[0] = 0;
    }

    void WorkSt(const char[] szFeature)
    {
        this.WorkStEx(FeatureNum(szFeature));
    }

    void WriteValue(const char[] szValue)
    {
        this.m_tpBuffer.SetValue(szValue);
    }

    char GetValue()
    {
        return this.m_tpBuffer.GetValue();
    }

    bool IsValidPart()
    {
        return this.m_tpBuffer.IsValidPart();
    }

    void WritePart(TemplatePart template)
    {
        this.m_tpBuffer = template;
    }

    void ResetPart()
    {
        this.m_tpBuffer.ResetPart();
    }

    void WorkStEx(const int iFeature)
    {
        switch(iFeature)
        {
            case CPREFIX: this.m_tpBuffer = this.m_tpCPrefix;
            case VPREFIX: this.m_tpBuffer = this.m_tpLPrefix;
            case CNAME: this.m_tpBuffer = this.m_tpCName;
            case CMESSAGE: this.m_tpBuffer = this.m_tpCMessage;

            default: this.ResetPart();
        }
    }

    void TransToValue(bool IsPrefix)
    {
        if(IsPrefix)
            Format(this.m_tpBuffer.m_szValue, PREFIX_LENGTH, "%t", this.GetValue());
        
        else this.WriteValue(GetColorOptByKey(aPalette, this.GetValue(), false));
    }

    void WorkFi(const char[] szFeature)
    {
        this.WorkFiEx(FeatureNum(szFeature));
    }

    void WorkFiEx(const int iFeature)
    {
        switch(iFeature)
        {
            case CPREFIX: this.m_tpCPrefix = this.m_tpBuffer;
            case VPREFIX: this.m_tpLPrefix = this.m_tpBuffer;
            case CNAME: this.m_tpCName = this.m_tpBuffer;
            case CMESSAGE: this.m_tpCMessage = this.m_tpBuffer;

            default: this.ResetPart();
        }
    }

    void ResetTemplate()
    {
        for(int i; i < sizeof(g_szFeatures); i++)
        {
            this.WorkStEx(i);
            this.ResetPart();
            this.WorkFiEx(i);
        }
    }
}

ClientTemplate tempClient[MAXPLAYERS+1];

#define CPREFIX_PRIO    "vip_cprefix_priority"
#define LPREFIX_PRIO    "vip_lprefix_priority"
#define CNAME_PRIO      "vip_cname_priority"
#define CMESSAGE_PRIO   "vip_cmessage_priority"

public APLRes AskPluginLoad2(Handle myself, bool late, char[] error, int err_max)
{
    blate = late;
    return APLRes_Success;
}

public void OnPluginStart()
{
    LoadTranslations("ccproc.phrases");
    LoadTranslations("vip_ccpchat.phrases");
    LoadTranslations("vip_modules.phrases");

    aFeatureList = new ArrayList(MESSAGE_LENGTH, 0);

    CreateConVar(CPREFIX_PRIO, "2", "The priority level to change the color of the prefix", _, true, 0.0).AddChangeHook(ChangeCPrefix);
    CreateConVar(LPREFIX_PRIO, "2", "The priority level to change the value of prefix", _, true, 0.0).AddChangeHook(ChangeLPrefix);
    CreateConVar(CNAME_PRIO, "2", "The priority level to change the color of the username", _, true, 0.0).AddChangeHook(ChangeCName);
    CreateConVar(CMESSAGE_PRIO, "2", "The priority level to change the color of the usermessage", _, true, 0.0).AddChangeHook(ChangeCMessage);

    AutoExecConfig(true, "vip_chat", "ccprocessor");

    if(VIP_IsVIPLoaded())
        VIP_OnVIPLoaded(); 

    for(int i; i < sizeof(g_szFeatures); i++)
        coFeatures[i] = RegClientCookie(g_szFeatures[i], g_szFeatures[i], CookieAccess_Private);
}

_CVAR_ON_CHANGE(ChangeCPrefix)
{
    nLevel[CPREFIX] = cvar.IntValue;
}

_CVAR_ON_CHANGE(ChangeLPrefix)
{
    nLevel[VPREFIX] = cvar.IntValue;
}

_CVAR_ON_CHANGE(ChangeCName)
{
    nLevel[CNAME] = cvar.IntValue;
}

_CVAR_ON_CHANGE(ChangeCMessage)
{
    nLevel[CMESSAGE] = cvar.IntValue;
}

SMCParser smParser;

public void OnMapStart()
{
    _CVAR_INIT_CHANGE(ChangeCPrefix,    CPREFIX_PRIO);
    _CVAR_INIT_CHANGE(ChangeLPrefix,    LPREFIX_PRIO);
    _CVAR_INIT_CHANGE(ChangeCName,      CNAME_PRIO);
    _CVAR_INIT_CHANGE(ChangeCMessage,   CMESSAGE_PRIO);

    char path[PMP];
    BUILD(path, _CONFIG_PATH);
    
    if(!FileExists(path))
        SetFailState("Where is my config: %s ???", path);

    aFeatureList.Clear();

    smParser = new SMCParser();
    smParser.OnKeyValue = OnValueRead;
    smParser.OnEnterSection = OnSection;
    smParser.OnLeaveSection = OnLeave;
    smParser.OnEnd = OnParseEnded;

    int iLine;
    if(smParser.ParseFile(path, iLine) != SMCError_Okay)
        LogError("Failed on line: %i", iLine);
}

int Section;

ArrayList aGroups;

SMCResult OnSection(SMCParser smc, const char[] name, bool opt_quotes)
{
    if(FeatureNum(name) != -1)
    {
        aFeatureList.PushString(name);
        
        if(!aGroups)
            aGroups = new ArrayList(128, 0);
    }
        
    Section++;

    return SMCParse_Continue;
}

SMCResult OnLeave(SMCParser smc)
{
    if(Section == 2)
        aFeatureList.Push(aGroups.Clone());

    aGroups.Clear();

    Section--;

    return SMCParse_Continue;
}

SMCResult OnValueRead(SMCParser smc, const char[] sKey, const char[] sValue, bool bKey_Quotes, bool bValue_quotes)
{
    if(!sKey[0] || !sValue[0])
        return SMCParse_Continue;
    
    TemplatePart templatePart;

    aGroups.PushString(sKey);

    ArrayList aValues = new ArrayList(PREFIX_LENGTH, 0);

    char szBuffer[1024];
    strcopy(SZ(szBuffer), sValue);

    int a;
    int len = strlen(szBuffer);

    for(int i; i < len; i++)
    {
        templatePart.m_szValue[a] = szBuffer[i];

        if(szBuffer[i] == ';' || i+1 == len)
        {
            if(i+1 != len)
                templatePart.m_szValue[a] = 0;
            
            aValues.PushArray(SZ(templatePart));

            templatePart.ResetPart();

            a = -1;
        }

        a++;
    }

    templatePart.ResetPart();

    aGroups.Push(aValues.Clone());

    delete aValues;

    return SMCParse_Continue;
}

public void OnParseEnded(SMCParser smc, bool halted, bool failed)
{
    delete aGroups;

    if(blate)
        cc_config_parsed();
}

public void cc_config_parsed()
{
    DeleteSafly(aPalette);

    aPalette = cc_drop_palette();
}

public void VIP_OnVIPLoaded()
{
    for(int i; i < sizeof(g_szFeatures); i++)
        VIP_RegisterFeature(g_szFeatures[i], INT, SELECTABLE, OnSelected_Feature, OnDisplay_Feature);
}

public void OnPluginEnd()
{
    if(!CanTestFeatures() || GetFeatureStatus(FeatureType_Native, "VIP_UnregisterFeature") != FeatureStatus_Available)
        return;
    
    for(int i; i < sizeof(g_szFeatures); i++)
        VIP_UnregisterFeature(g_szFeatures[i]);
}

public bool OnSelected_Feature(int iClient, const char[] szFeature)
{
    bCustom[iClient] = false;

    Menu hMenu = FeatureMenu(iClient, szFeature);
    if(hMenu)   
        hMenu.Display(iClient, MENU_TIME_FOREVER);

    return false;
}

public bool OnDisplay_Feature(int iClient, const char[] szFeature, char[] szDisplay, int iMaxLength)
{
    SetGlobalTransTarget(iClient);

    char szFValue[MESSAGE_LENGTH];
    tempClient[iClient].WorkSt(szFeature);

    if(tempClient[iClient].IsValidPart())
    {   
        strcopy(SZ(szFValue), tempClient[iClient].GetValue());

        if(!StrEqual(szFeature, g_szFeatures[VPREFIX]))
        {
            aPalette.GetString(aPalette.FindString(szFValue)+1, SZ(szFValue));
            Format(SZ(szFValue), "%t", szFValue);
        }

        cc_clear_allcolors(SZ(szFValue));

        TrimString(szFValue);
    }
    
    tempClient[iClient].WorkFiEx(-1);

    if(!szFValue[0])
        FormatEx(SZ(szFValue), "%t", "empty_value");

    FormatEx(szDisplay, iMaxLength, "%t [%s]", szFeature, szFValue);

    return true;
}

public void OnClientPutInServer(int iClient)
{
    tempClient[iClient].ResetTemplate();
    tempClient[iClient].ResetGroup();
}

public void VIP_OnVIPClientLoaded(int iClient)
{
    VIP_GetClientVIPGroup(iClient, tempClient[iClient].m_szVIPGroup, sizeof(tempClient[].m_szVIPGroup));

    for(int i; i < sizeof(g_szFeatures); i++)
        if(VIP_IsClientFeatureUse(iClient, g_szFeatures[i]))
            GetValueFromCookie(iClient, coFeatures[i], g_szFeatures[i]);
}

void GetValueFromCookie(int iClient, Handle coHandle, const char[] szFeature)
{
    if(coHandle && coHandle != INVALID_HANDLE)
    {
        char szBuffer[MESSAGE_LENGTH];
        GetClientCookie(iClient, coHandle, SZ(szBuffer));

        if(!szBuffer[0])
            return;

        tempClient[iClient].WorkSt(szFeature);
        tempClient[iClient].WriteValue(szBuffer);
        
        SetGlobalTransTarget(iClient);

        TemplatePart templatePart;
        
        ArrayList aValues = GetSubList(GetSubList(aFeatureList, szFeature), tempClient[iClient].GetGroup());

        bool bFind;

        if(aValues != null)
        {
            for(int i; i < aValues.Length; i++)
            {
                aValues.GetArray(i, SZ(templatePart));

                if(!StrEqual(szFeature, g_szFeatures[VPREFIX]))
                    szBuffer = GetColorOptByKey(aPalette, templatePart.GetValue(), false);

                else FormatEx(szBuffer, sizeof(szBuffer), "%t", templatePart.GetValue());

                if(UTF8StrEqual(tempClient[iClient].GetValue(), szBuffer, false))
                {
                    tempClient[iClient].WritePart(templatePart);
                    tempClient[iClient].TransToValue(StrEqual(szFeature, g_szFeatures[VPREFIX]));

                    bFind = true;

                    break;
                }
            }
        }

        if(aValues == null || (FindTransKey(aValues, "custom") == -1 && !bFind))
            tempClient[iClient].ResetPart();

        tempClient[iClient].WorkFi(szFeature);        
    }
}

Menu FeatureMenu(int iClient, const char[] szFeature)
{
    Menu hMenu;
    ArrayList aValues;

    if(!(aValues = GetSubList(GetSubList(aFeatureList, szFeature), tempClient[iClient].GetGroup())) || !aValues.Length)
        return hMenu;

    hMenu = new Menu(FeatureMenu_CallBack);

    SetGlobalTransTarget(iClient);

    char szBuffer[MESSAGE_LENGTH];
    FormatEx(SZ(szBuffer), "%s_title", szFeature);

    hMenu.SetTitle("%t \n \n", szBuffer);

    tempClient[iClient].WorkSt(szFeature);

    FormatEx(SZ(szBuffer), "%t \n \n", "disable_this");
    hMenu.AddItem("disable", szBuffer, (tempClient[iClient].IsValidPart()) ? ITEMDRAW_DEFAULT : ITEMDRAW_DISABLED);

    if(FindTransKey(aValues, "custom") != -1)
    {
        FormatEx(SZ(szBuffer), "%t \n \n", "custom");
        hMenu.AddItem("custom", szBuffer);
    }

    int style = ITEMDRAW_DEFAULT;
    char szOpt[8];
    TemplatePart templatePart;

    for(int i; i < aValues.Length; i++)
    {
        aValues.GetArray(i, SZ(templatePart));

        if(StrEqual(templatePart.GetValue(), "custom"))
            continue;

        if(!StrEqual(szFeature, g_szFeatures[VPREFIX]))
            szBuffer = GetColorOptByKey(aPalette, templatePart.GetValue(), false);
        
        else FormatEx(SZ(szBuffer), "%t", templatePart.GetValue());

        style = (UTF8StrEqual(szBuffer, tempClient[iClient].GetValue())) ? ITEMDRAW_DISABLED : ITEMDRAW_DEFAULT;

        if(!StrEqual(szFeature, g_szFeatures[VPREFIX]))
            szBuffer = GetColorOptByKey(aPalette, templatePart.GetValue(), true);
            
        IntToString(i, SZ(szOpt));

        cc_clear_allcolors(SZ(szBuffer));
            
        hMenu.AddItem(szOpt, szBuffer, style);
    }

    strcopy(ccl_current_feature[iClient], sizeof(ccl_current_feature[]), szFeature);

    return hMenu; 
}

public int FeatureMenu_CallBack(Menu hMenu, MenuAction action, int iClient, int iOpt2)
{
    switch(action)
    {
        case MenuAction_End: delete hMenu;
        case MenuAction_Select:
        {
            char opt[8];
            hMenu.GetItem(iOpt2, SZ(opt));

            if((bCustom[iClient] = opt[0] == 'c'))
            {
                PrintToChat(iClient, "%t", "ccp_custom_value");
                return;
            }

            TemplatePart templatePart;

            tempClient[iClient].WorkSt(ccl_current_feature[iClient]);
            tempClient[iClient].WritePart(templatePart);

            if(opt[0] != 'd')
            {
                ArrayList aValues = GetSubList(GetSubList(aFeatureList, ccl_current_feature[iClient]), tempClient[iClient].GetGroup());
                aValues.GetArray(StringToInt(opt), SZ(templatePart));

                tempClient[iClient].WritePart(templatePart);
                tempClient[iClient].TransToValue(StrEqual(ccl_current_feature[iClient], g_szFeatures[VPREFIX]));
            }

            SetClientCookie(iClient, coFeatures[FeatureNum(ccl_current_feature[iClient])], tempClient[iClient].GetValue());

            tempClient[iClient].WorkFi(ccl_current_feature[iClient]);

            VIP_SendClientVIPMenu(iClient, true);
        }
    }
}

public Action OnClientSayCommand(int iClient, const char[] command, const char[] args)
{
    if(!IsClientInGame(iClient) || IsFakeClient(iClient) || IsChatTrigger())
        return Plugin_Continue;

    if(bCustom[iClient])
    {
        char szBuffer[MESSAGE_LENGTH];

        tempClient[iClient].WorkSt(ccl_current_feature[iClient]);

        if(!StrEqual(ccl_current_feature[iClient], g_szFeatures[VPREFIX]))
        {
            szBuffer = GetColorOptByKey(aPalette, args, false);

            if(!szBuffer[0])
            {
                tempClient[iClient].ResetPart();

                PrintToChat(iClient, "%t", "ccp_invalid_colorkey");
                return Plugin_Handled;
            }
        }

        else strcopy(SZ(szBuffer), args);
        
        tempClient[iClient].WriteValue(szBuffer);
        tempClient[iClient].WorkFi(ccl_current_feature[iClient]);
        SetClientCookie(iClient, coFeatures[FeatureNum(ccl_current_feature[iClient])], szBuffer);

        bCustom[iClient] = false;

        PrintToChat(iClient, "%t", "ccp_custom_success");

        return Plugin_Handled;
    }

    return Plugin_Continue;
}

int iMsgType;

public void cc_proc_MsgBroadType(const int iType)
{
    iMsgType = iType;
}

public void cc_proc_RebuildString(int iClient, int &plevel, const char[] szBind, char[] szBuffer, int iSize)
{
    if(iMsgType < eMsg_SERVER)
    {
        if(!VIP_IsClientVIP(iClient))
            return;

        static int i;
        i = (!strcmp(szBind, "{NAMECO}")) ? CNAME : (!strcmp(szBind, "{PREFIX}")) ? VPREFIX : (!strcmp(szBind, "{MSGCO}")) ? CMESSAGE : (!strcmp(szBind, "{PREFIXCO}")) ? CPREFIX : -1;

        if(i == -1)
            return;
        
        if(nLevel[i] < plevel)
            return;

        tempClient[iClient].WorkStEx(i);

        if(tempClient[iClient].IsValidPart())
        {
            plevel = nLevel[i];
                    
            FormatEx(szBuffer, iSize, "%s", tempClient[iClient].GetValue());
        }
        
        tempClient[iClient].ResetPart();
    } 
}

void DeleteSafly(Handle &hValue)
{
    // if we use `delete` on an already invalid descriptor, we will get an exception

    /*
        `delete` is equivalent to:

        if(handle != null)
            handle.Close()
        
        handle = null;
    */

    if(hValue == INVALID_HANDLE)
        hValue = null;
    
    delete hValue;
}

int FeatureNum(const char[] szFeature)
{
    for(int i; i < sizeof(g_szFeatures); i++)
        if(StrEqual(szFeature, g_szFeatures[i]))
            return i;

    return -1;
}

ArrayList GetSubList(ArrayList inputList, const char[] szFind)
{
    if(inputList == null)
        return inputList;

    ArrayList arr;
    int pos;

    if((pos = inputList.FindString(szFind)) != -1)
        arr = view_as<ArrayList>(inputList.Get(pos+1));

    return arr;
}

int FindTransKey(ArrayList inputList, const char[] key)
{
    TemplatePart templatePart;

    for(int i; i < inputList.Length; i++)
    {
        inputList.GetArray(i, SZ(templatePart));

        if(StrEqual(templatePart.GetValue(), key))
            return i;
        
        templatePart.ResetPart();
    }

    return -1;
}

char GetColorOptByKey(ArrayList palette, const char[] szKey, bool bTranslation)
{
    char szBuffer[MESSAGE_LENGTH];

    int pos = palette.FindString(szKey);
    if(pos != -1)
    {
        pos = ((bTranslation) ? pos + 2 : pos + 1);
        palette.GetString(pos, szBuffer, sizeof(szBuffer));

        if(bTranslation)
            Format(szBuffer, sizeof(szBuffer), "%t", szBuffer);
    }
    
    return szBuffer;
}