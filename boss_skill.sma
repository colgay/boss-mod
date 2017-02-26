#include <amxmodx>
#include <fakemeta>
#include <gamedata_stocks>

#define VERSION "0.1"

new g_maxClients;

new Array:g_skillName;
new Array:g_skillDesc;
new Array:g_skillClass;
new Array:g_skillCost;
new Array:g_skillDelay;
new g_skillCount;

new g_fwSkillUse, g_fwSkillUse_Post;
new g_return;

new g_energy[33];
new Array:g_lastUseTime[33];
new g_menuPage[33];

new CvarRestoreAmt, CvarRestoreMax;

public plugin_init()
{
	register_plugin("Boss Skill API", VERSION, "penguinux");
	
	register_event("HLTV", "OnEventNewRound", "a", "1=0", "2=0");
	
	register_clcmd("drop", "CmdDrop");
	
	g_maxClients = get_maxplayers();

	g_skillName = ArrayCreate(32);
	g_skillDesc = ArrayCreate(32);
	g_skillClass = ArrayCreate(32);
	g_skillCost = ArrayCreate(1);
	g_skillDelay = ArrayCreate(1);

	for (new i = 1; i <= g_maxClients; i++)
	{
		g_lastUseTime[i] = ArrayCreate(1);
	}

	g_fwSkillUse = CreateMultiForward("Boss_OnSkillUse", ET_STOP, FP_CELL, FP_CELL);
	g_fwSkillUse_Post = CreateMultiForward("Boss_OnSkillUse_Post", ET_STOP, FP_CELL, FP_CELL);
	
	new pcvar;
	pcvar = create_cvar("boss_energy_restore_amt", "20");
	bind_pcvar_num(pcvar, CvarRestoreAmt);
	
	pcvar = create_cvar("boss_energy_restore_max", "999");
	bind_pcvar_num(pcvar, CvarRestoreMax);
	
	set_task(1.0, "TaskRestoreEnergy", 2046, _, _, "b");
}

public OnEventNewRound()
{
	for (new i = 1, j; i <= g_maxClients; i++)
	{
		if (is_user_connected(i))
		{
			g_energy[i] = 0;
			
			for (j = 0; j < g_skillCount; j++)
				ArraySetCell(g_lastUseTime[i], j, -999999.0);
		}
	}
}

public client_disconnected(id)
{
	remove_task(id);
}

public CmdDrop(id)
{
	// Not alive
	if (!is_user_alive(id))
		return PLUGIN_CONTINUE;
	
	// Not terrorist
	if (getPlayerData(id, "m_iTeam") != 1)
		return PLUGIN_CONTINUE;
	
	ShowSkillMenu(id);
	return PLUGIN_HANDLED;
}

public ShowSkillMenu(id)
{
	new text[64];
	formatex(text, charsmax(text), "使用技能 \r[能量:\w%d\r]", g_energy[id]);
	new menu = menu_create(text, "HandleSkillMenu");
	
	new Float:coolDown;
	for (new i = 0; i < g_skillCount; i++)
	{
		coolDown = Float:ArrayGetCell(g_lastUseTime[id], i) + Float:ArrayGetCell(g_skillDelay, i) - get_gametime();

		formatex(text, charsmax(text), "%a\y(COST:\w%d\y)\d(CD:%s%.f\ds) \d%a",
			ArrayGetStringHandle(g_skillName, i),
			ArrayGetCell(g_skillCost, i), 
			coolDown > 0.0 ? "\w" : "\d",
			coolDown > 0.0 ? coolDown : Float:ArrayGetCell(g_skillDelay, i),
			ArrayGetStringHandle(g_skillDesc, i));
		
		menu_additem(menu, text);
	}
	
	menu_setprop(menu, MPROP_NUMBER_COLOR, "\y");
	menu_display(id, menu, g_menuPage[id]);
	
	remove_task(id);
	set_task(1.0, "TaskUpdateMenu", id, _, _, "b");
}

public HandleSkillMenu(id, menu, item)
{
	if (item == MENU_EXIT)
	{
		remove_task(id);
		g_menuPage[id] = 0;
		menu_destroy(menu);
		return;
	}
	
	new dummy;
	player_menu_info(id, dummy, dummy, g_menuPage[id]);

	remove_task(id);
	menu_destroy(menu);
	UseSkill(id, item);
}

public TaskUpdateMenu(id)
{
	if (!is_user_alive(id) || getPlayerData(id, "m_iTeam") != 1)
	{
		remove_task(id);
		return;
	}
	
	ShowSkillMenu(id);
}

public TaskRestoreEnergy()
{
	for (new i = 1; i < g_maxClients; i++)
	{
		if (!is_user_alive(i))
			continue;
		
		if (getPlayerData(i, "m_iTeam") == 1)
		{
			g_energy[i] = min(g_energy[i] + CvarRestoreAmt, CvarRestoreMax);
		}
	}
}

public plugin_natives()
{
	register_library("boss_skill");
	
	register_native("boss_RegisterSkill", "native_RegisterSkill");
	register_native("boss_GetSkillName", "native_GetSkillName");
	register_native("boss_GetSkillClass", "native_GetSkillClass");
	register_native("boss_GetSkillByClass", "native_GetSkillByClass");
	register_native("boss_GetSkillCost", "native_GetSkillCost");
	register_native("boss_GetSkillDelay", "native_GetSkillDelay");
	register_native("boss_GetSkillCount", "native_GetSkillCount");
	register_native("boss_GetEnergy", "native_GetEnergy");
	register_native("boss_SetEnergy", "native_SetEnergy");
	register_native("boss_GetSkillCooldown", "native_GetSkillCooldown");
	register_native("boss_UseSkill", "native_UseSkill");
}

public native_RegisterSkill()
{
	new name[32], desc[32], class[32];
	get_string(1, name, charsmax(name));
	get_string(2, desc, charsmax(desc));
	get_string(3, class, charsmax(class));
	
	new cost = get_param(4);
	new Float:delay = get_param_f(5);
	
	ArrayPushString(g_skillName, name);
	ArrayPushString(g_skillDesc, desc);
	ArrayPushString(g_skillClass, class);
	
	ArrayPushCell(g_skillCost, cost);
	ArrayPushCell(g_skillDelay, delay);
	
	for (new i = 1; i <= g_maxClients; i++)
	{
		ArrayPushCell(g_lastUseTime[i], -999999.0);
	}

	g_skillCount++;
	
	return g_skillCount - 1;
}

public native_GetSkillName()
{
	new skill = get_param(1);
	
	new name[32];
	ArrayGetString(g_skillName, skill, name, charsmax(name));
	
	set_string(2, name, get_param(3));
}

public native_GetSkillClass()
{
	new skill = get_param(1);
	
	new class[32];
	ArrayGetString(g_skillClass, skill, class, charsmax(class));
	
	set_string(2, class, get_param(3));
}

public native_GetSkillByClass()
{
	new class[32];
	get_string(1, class, charsmax(class));
	
	new class2[32];
	for (new i = 0; i < g_skillCount; i++)
	{
		ArrayGetString(g_skillClass, i, class2, charsmax(class2));
		
		if (equal(class, class2))
			return i;
	}
	
	return -1;
}

public native_GetSkillCost()
{
	new skill = get_param(1);
	
	return ArrayGetCell(g_skillCost, skill);
}

public Float:native_GetSkillDelay()
{
	new skill = get_param(1);
	
	return Float:ArrayGetCell(g_skillDelay, skill);
}

public native_GetSkillCount()
{
	return g_skillCount;
}

public native_GetEnergy()
{
	new id = get_param(1);
	
	return g_energy[id];
}

public native_SetEnergy()
{
	new id = get_param(1);
	new value = get_param(2);
	
	g_energy[id] = value;
}

public Float:native_GetSkillCooldown()
{
	new id = get_param(1);
	new skill = get_param(2);
	
	return Float:ArrayGetCell(g_lastUseTime[id], skill) + Float:ArrayGetCell(g_skillDelay, skill) - get_gametime();
}

public native_UseSkill()
{
	new id = get_param(1);
	new skill = get_param(2);
	new bool:noConditions = bool:get_param(3);
	
	UseSkill(id, skill, noConditions);
}

// Make boss uses a skill
UseSkill(id, skill, bool:noConditions=false)
{
	if (!noConditions)
	{
		if (!is_user_alive(id))
			return;
		
		// Not terrorist
		if (getPlayerData(id, "m_iTeam") != 1)
			return;
		
		if (g_energy[id] < ArrayGetCell(g_skillCost, skill))
		{
			client_print(id, print_center, "能量不足");
			return;
		}
		
		new Float:coolDown = Float:ArrayGetCell(g_lastUseTime[id], skill) + Float:ArrayGetCell(g_skillDelay, skill) - get_gametime();
		if (coolDown > 0.0)
		{
			client_print(id, print_center, "技能冷卻中 (剩餘 %.f 秒)", coolDown);
			return;
		}
	}

	ExecuteForward(g_fwSkillUse, g_return, id, skill);

	// Stop
	if (g_return == PLUGIN_HANDLED)
		return;
	
	// Use skill
	g_energy[id] -= ArrayGetCell(g_skillCost, skill);
	ArraySetCell(g_lastUseTime[id], skill, get_gametime());
	
	// Execute forward for other plugins
	ExecuteForward(g_fwSkillUse_Post, g_return, id, skill);

	// Stop
	if (g_return == PLUGIN_HANDLED)
		return;
	
	// Notice
	set_dhudmessage(50, 100, 200, -1.0, 0.2, 0, 0.0, 2.0, 1.0, 1.0);
	show_dhudmessage(0, "魔王 %n^n使用%a!", id, ArrayGetStringHandle(g_skillName, skill));
}