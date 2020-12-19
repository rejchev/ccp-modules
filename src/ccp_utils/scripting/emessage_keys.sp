/*
    Leaves an entry in the log about the engine message key, 
    in the case when it does not exist or does not have a translation for the server language in the library of phrases
*/

#pragma newdecls required

#include ccprocessor

public void OnMapStart()
{
    cc_proc_APIHandShake(cc_get_APIKey());
}

public Action cc_proc_OnDefMsg(const char[] szMessage, bool IsPhraseExists)
{
    if(!IsPhraseExists)
        LogMessage("Engine message key: %s | Is phrase exists: %b ", szMessage, IsPhraseExists);
}