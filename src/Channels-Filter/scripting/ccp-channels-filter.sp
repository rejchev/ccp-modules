// #pragma newdecls required

// #include <ccprocessor>

// public Plugin myinfo = 
// {
// 	name = "[CCP] Channels Filter",
// 	author = "nu11ent",
// 	description = "...",
// 	version = "1.1.2",
// 	url = "https://t.me/nyoood"
// };

// // ...
// char g_chIgnore[MAXPLAYERS+1][MESSAGE_LENGTH];

// public void OnClientPutInServer(int iClient) {
// 	g_chIgnore[iClient][i] = NULL_STRING;
// }

// Action cmd(int iClient, int args)
// {
// 	if(iClient && IsClientInGame(iClient))
// 	{
// 		Menu hMenu = new Menu(MenuCallBack);

// 		hMenu.SetTitle("%T \n \n", "title", iClient);

// 		char szBuffer[MESSAGE_LENGTH];
// 		for(int i; i < sizeof(keys); i++)
// 		{
// 			FormatEx(szBuffer, sizeof(szBuffer), "%T", (g_chIgnore[iClient][i]) ? "disabled" : "enabled", iClient);
// 			Format(szBuffer, sizeof(szBuffer), "%c%T", i+1, keys[i], iClient, szBuffer);

// 			// [cell]Any words [Enabled/Disabled]
// 			hMenu.AddItem(szBuffer, szBuffer[1]);
// 		}

// 		hMenu.Display(iClient, MENU_TIME_FOREVER);
// 	}

// 	return Plugin_Handled;
// }

// public int MenuCallBack(Menu hMenu, MenuAction action, int iClient, int option)
// {
// 	switch(action)
// 	{
// 		case MenuAction_End: delete hMenu;
// 		case MenuAction_Select: 
// 		{
// 			char szBuffer[4];
// 			hMenu.GetItem(option, szBuffer, sizeof(szBuffer));

// 			int mType = szBuffer[0] - 1;

// 			g_chIgnore[iClient][mType] = !g_chIgnore[iClient][mType];
// 			cmd(iClient, 0);
// 		}
// 	}
// }

// public Action  cc_proc_OnRebuildString(const int[] props, int part, ArrayList params, int &level, char[] value, int size) {
// 	int i;
// 	if((i = GetIndexOfIndent(indent)) != -1 && g_chIgnore[sender][i])
// 		return Plugin_Stop;

// 	return Plugin_Continue;
// }

// stock int GetIndexOfIndent(const char[] indent) {
// 	for(int i; i < sizeof(keys); i++) {
// 		if(!strcmp(keys[i], indent)) {
// 			return i;
// 		}
// 	}

// 	return -1;
// }

// public void cc_proc_OnRebuildClients(
//     int mid, const char[] indent, int sender, 
//     const char[] msg_key, int[] players, int &playersNum 
// ) {
// 	RemoveFromRecepients(GetIndexOfIndent(indent), players, playersNum);
// }

// void RemoveFromRecepients(const int mType, int[] clients, int &numClients)
// {
// 	if(mType == -1) {
// 		return;
// 	}

// 	int size = numClients;
// 	numClients = 0;

// 	for(int i; i < size; i++)
// 	{
// 		if(!g_chIgnore[clients[i]][mType])
// 			clients[numClients++] = clients[i];
// 	}
// }