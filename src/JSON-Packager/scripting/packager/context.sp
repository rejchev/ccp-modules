Processing context(Handle plugin, int iClient, const char[] artifact, JSON value, any level) {
    JSONObject ctx = new JSONObject();

    if(level == CALL_IGNORE) {
        ctx.SetBool("isArtifact", artifact[0] != 0);
        ctx.SetInt("client", (iClient) ? GetClientUserId(iClient) : 0);
        ctx.SetString("field", (artifact[0]) ? artifact : "model");
        ctx.Set((artifact[0]) ? artifact : "model", value);
        ctx.SetInt("caller", view_as<int>(plugin));
    }

    Processing ok;
    JSONObject obj;
    static char szBuffer[PREFIX_LENGTH];

    if(level == CALL_IGNORE || (ok = updatePackage(ctx, level)) < Proc_Reject) {
        FormatEx(szBuffer, sizeof(szBuffer), "%d", iClient);

        obj = (artifact[0]) ? asJSONO(ccp_GetPackage(iClient)) : asJSONO(value);

        if(artifact[0]) {
            if(!value)
                obj.Remove(artifact);

            else obj.Set(artifact, value);
        }

        if(!obj)
            packager.SetNull(szBuffer);

        else packager.Set(szBuffer, obj);
    }

    delete ctx;
    delete obj;

    return ok;
}