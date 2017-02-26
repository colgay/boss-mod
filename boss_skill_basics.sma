#include <amxmodx>
#include <fakemeta>
#include <hamsandwich>
#include <boss_skill>
#include <xs>

#define VERSION "0.1"

#define TASK_SPRINT 0
#define TASK_GODMODE 50

new g_jump;
new g_leap;
new g_sprint;
new g_godmode;
new g_teleport;

new bool:g_isSprinting[33];
new bool:g_isGodMode[33];

public plugin_init()
{
	register_plugin("[Boss] Basic Skills", VERSION, "penguinux");
	
	RegisterHam(Ham_CS_Player_ResetMaxSpeed, "player", "OnResetMaxSpeed_Post", 1);
	RegisterHam(Ham_Killed, "player", "OnPlayerKilled");
	RegisterHam(Ham_TraceAttack, "player", "OnTraceAttack");
	RegisterHam(Ham_TakeDamage, "player", "OnTakeDamage");
	
	g_jump = boss_RegisterSkill("高跳", "跳高", "skill_jump", 200, 10.0);
	g_leap = boss_RegisterSkill("飛撲", "", "skill_leap", 250, 12.5);
	g_sprint = boss_RegisterSkill("暴走", "5秒", "skill_sprint", 300, 15.0);
	g_godmode = boss_RegisterSkill("無敵", "3秒", "skill_godmode", 600, 30.0);
	g_teleport = boss_RegisterSkill("瞬移", "", "skill_teleport", 100, 5.0);
}

public client_disconnected(id)
{
	TaskSprintOver(id+TASK_SPRINT);
	TaskGodModeOver(id+TASK_GODMODE);
}

public OnResetMaxSpeed_Post(id)
{
	if (g_isSprinting[id])
	{
		new Float:speed;
		pev(id, pev_maxspeed, speed);
		set_pev(id, pev_maxspeed, speed * 2.0);
	}
}

public OnPlayerKilled(id)
{
	TaskSprintOver(id+TASK_SPRINT);
	TaskGodModeOver(id+TASK_GODMODE);
}

public OnTraceAttack(id)
{
	if (g_isGodMode[id])
		return HAM_SUPERCEDE;
	
	return HAM_IGNORED;
}

public OnTakeDamage(id)
{
	if (g_isGodMode[id])
		return HAM_SUPERCEDE;
	
	return HAM_IGNORED;
}

public Boss_OnSkillUse(id, skill)
{
	if (skill == g_jump || skill == g_leap)
	{
		if (~pev(id, pev_flags) & FL_ONGROUND)
		{
			client_print(id, print_center, "你必須要在地面使用");
			return PLUGIN_HANDLED;
		}
	}
	
	if (skill == g_teleport)
	{
		new Float:origin[3];
		if (!getTeleportOrigin(id, origin))
		{
			client_print(id, print_center, "你瞄準的位置無效");
			return PLUGIN_HANDLED;
		}
	}

	return PLUGIN_CONTINUE;
}

public Boss_OnSkillUse_Post(id, skill)
{
	if (skill == g_jump)
		doJump(id);
	else if (skill == g_leap)
		doLeap(id);
	else if (skill == g_sprint)
		doSprint(id);
	else if (skill == g_godmode)
		doGodMode(id);
	else if (skill == g_teleport)
		doTeleport(id);
}

public TaskSprintOver(taskid)
{
	remove_task(taskid);

	new id = taskid - TASK_SPRINT;
	g_isSprinting[id] = false;

	if (is_user_alive(id))
		ExecuteHamB(Ham_CS_Player_ResetMaxSpeed, id);
}

public TaskGodModeOver(taskid)
{
	remove_task(taskid);
	
	new id = taskid - TASK_GODMODE;
	g_isGodMode[id] = false;
	set_pev(id, pev_rendermode, kRenderNormal);
}

stock doJump(id)
{
	new Float:velocity[3];
	pev(id, pev_velocity, velocity);
	
	velocity[2] += 1000.0;
	set_pev(id, pev_velocity, velocity);
}

stock doLeap(id)
{
	new Float:velocity[3], Float:angles[3], Float:vector[3];
	pev(id, pev_velocity, velocity);
	pev(id, pev_v_angle, angles);
	
	if (angles[0] > -25.0)
		angles[0] = -25.0;
	
	angle_vector(angles, ANGLEVECTOR_FORWARD, vector);
	
	xs_vec_mul_scalar(vector, 600.0, vector);
	xs_vec_add(velocity, vector, velocity);
	velocity[2] += 200.0;

	set_pev(id, pev_velocity, velocity);
}

stock doSprint(id)
{
	g_isSprinting[id] = true;
	ExecuteHamB(Ham_CS_Player_ResetMaxSpeed, id);
	
	remove_task(id+TASK_SPRINT);
	set_task(5.0, "TaskSprintOver", id+TASK_SPRINT);
}

stock doGodMode(id)
{
	g_isGodMode[id] = true;

	set_pev(id, pev_rendercolor, Float:{255.0, 255.0, 255.0});
	set_pev(id, pev_rendermode, kRenderGlow);
	
	remove_task(id+TASK_GODMODE);
	set_task(3.0, "TaskGodModeOver", id+TASK_GODMODE);
}

stock doTeleport(id)
{
	new Float:origin[3];
	getTeleportOrigin(id, origin);
	engfunc(EngFunc_SetOrigin, id, origin);
}

stock getTeleportOrigin(id, Float:output[3])
{
	new Float:start[3], Float:end[3];
	pev(id, pev_origin, start);

	velocity_by_aim(id, 1000, end);
	xs_vec_add(start, end, end);
	
	engfunc(EngFunc_TraceHull, start, end, DONT_IGNORE_MONSTERS, HULL_HEAD, id, 0);
	
	get_tr2(0, TR_vecEndPos, output);
	
	if (isPlayerStuck(id, output, DONT_IGNORE_MONSTERS))
	{
		output[2] += 36.0;
		
		if (isPlayerStuck(id, output, DONT_IGNORE_MONSTERS))
		{
			output[2] -= 72.0;
			
			if (isPlayerStuck(id, output, DONT_IGNORE_MONSTERS))
				return false;
		}
	}
	
	return true;
}

stock bool:isPlayerStuck(id, Float:origin[3], noMonsters)
{
	new hull = (pev(id, pev_flags) & FL_DUCKING) ? HULL_HEAD : HULL_HUMAN;
	engfunc(EngFunc_TraceHull, origin, origin, noMonsters, hull, id, 0);
	
	if (get_tr2(0, TR_StartSolid) || get_tr2(0, TR_AllSolid) || !get_tr2(0, TR_InOpen))
		return true;

	return false;
}