/*
    Leaves an entry in the log about the engine message key, 
    in the case when it does not exist or does not have a translation for the server language in the library of phrases
*/

#pragma newdecls required

#include ccprocessor

#if defined API_KEY

#define API_KEY_OOD "The plugin module uses an outdated API. You must update it."

public void OnPluginStart()
{
    if(CanTestFeatures() && GetFeatureStatus(FeatureType_Native, "cc_is_APIEqual") == FeatureStatus_Available && !cc_is_APIEqual(API_KEY))
        cc_proc_APIHandShake(NULL_STRING);
}

public void cc_proc_APIHandShake(const char[] APIKey)
{
    if(!StrEqual(APIKey, API_KEY, true))
        SetFailState(API_KEY_OOD);
}

#endif

public Action cc_proc_OnDefMsg(const char[] szMessage, bool IsPhraseExists, bool IsTranslated)
{
    if(!IsPhraseExists || !IsTranslated)
        LogMessage("Engine message key: %s | Is phrase exists: %b | Is translated for SERVER_LANG: %b", szMessage, IsPhraseExists, IsTranslated);

    return (IsPhraseExists && IsTranslated) ? Plugin_Changed : Plugin_Continue;
}