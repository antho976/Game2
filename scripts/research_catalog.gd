class_name ResearchCatalog
extends RefCounted
const TREES := ["Character", "Equipment", "Trade", "Scholarship", "Hub · WIP"]
static func study(id: String,title: String,tree: int,pos: Vector2,requires: Dictionary,gold: Array,diamonds: Array,times: Array,effects: Dictionary,description: String,wip := false) -> Dictionary:
	return {"id":id,"name":title,"tree":tree,"pos":pos,"requires":requires,"gold":gold,"diamonds":diamonds,"times":times,"effects":effects,"description":description,"ranks":times.size(),"wip":wip}
static func all() -> Array[Dictionary]:
	return [
		study("conditioning","Conditioning",0,Vector2(160,20),{},[50],[0],[15],{},"The foundation for training body and breath."),
		study("vitality","Vitality",0,Vector2(20,170),{"conditioning":1},[80,140,220],[0,2,4],[30,60,120],{"health":10},"Each rank adds 10 maximum health."),
		study("endurance","Endurance",0,Vector2(300,170),{"conditioning":1},[80,140,220],[0,2,4],[30,60,120],{"stamina":8},"Each rank adds 8 maximum stamina."),
		study("recovery","Measured breathing",0,Vector2(300,320),{"endurance":1},[180,300],[3,6],[90,180],{"recovery":.10},"Each rank increases stamina recovery by 10%."),
		study("resolve","Unbroken resolve",0,Vector2(160,470),{"vitality":1,"recovery":1},[500],[12],[300],{"health":20,"stamina":10},"A final discipline: +20 maximum health and +10 maximum stamina. Combat will use these recorded bonuses."),
		study("metallurgy","Metallurgy",1,Vector2(160,20),{},[60],[0],[20],{},"Study how steel responds to enchantment."),
		study("potency","Deeper enchantments",1,Vector2(20,170),{"metallurgy":1},[100,180,280,420],[0,2,5,8],[30,60,120,240],{"potency":.025},"Each rank adds 2.5 percentage points of base stats to future successful upgrades. Existing upgrades keep their original gains."),
		study("tempering","Stable tempering",1,Vector2(300,170),{"metallurgy":1},[100,180,280,420],[0,2,5,8],[30,60,120,240],{"survival":.08},"Each rank adds 8 percentage points to item survival. Early upgrades can become safe; higher upgrades retain risk."),
		study("limits","Beyond the limit",1,Vector2(160,320),{"potency":1,"tempering":1},[250,450,700],[4,8,14],[120,240,420],{"upgrade_cap":1},"Each rank unlocks one more item upgrade, taking the limit from +5 to +8. Later attempts have lower base survival."),
		study("masterwork","Masterwork theory",1,Vector2(160,470),{"potency":1,"tempering":1,"limits":1},[1000],[20],[600],{"potency":.05,"survival":.08},"The final equipment study: +5 percentage points to future upgrade gains and +8 points to survival. The highest upgrade can never be guaranteed."),
		study("appraisal","Appraisal",2,Vector2(160,20),{},[50],[0],[15],{},"Learn the value of materials and finished equipment."),
		study("bargaining","Trusted customer",2,Vector2(20,170),{"appraisal":1},[100,170,260],[0,2,5],[30,60,120],{"shop_discount":.05},"Each rank reduces blacksmith purchase prices by 5%."),
		study("efficiency","Efficient forging",2,Vector2(300,170),{"appraisal":1},[100,170,260],[0,2,5],[30,60,120],{"forge_discount":.05},"Each rank reduces the gold cost of item upgrades by 5%."),
		study("charter","Guild charter",2,Vector2(160,320),{"bargaining":1,"efficiency":1},[600],[12],[300],{"shop_discount":.10,"forge_discount":.10},"A permanent agreement: another 10% off purchases and forging, for a total 25% discount in each."),
		study("organization","Organized study",3,Vector2(160,20),{},[60],[0],[20],{},"Prepare the archive for a larger research team."),
		study("assistant","Third research desk",3,Vector2(20,170),{"organization":1},[200],[3],[90],{"slots":1},"Unlock a third simultaneous research project."),
		study("fieldnotes","Detailed field notes",3,Vector2(300,170),{"organization":1},[130,240],[1,4],[45,90],{"offline":.125},"Each rank adds 12.5 percentage points to offline research speed, up to half of normal speed."),
		study("fellowship","Fourth research desk",3,Vector2(160,320),{"assistant":1,"fieldnotes":1},[650],[14],[480],{"slots":1},"Unlock the fourth and final simultaneous research project."),
		study("hub_plan","Village planning",4,Vector2(160,20),{},[],[],[0],{},"Planned: reshape and expand the hub through research. This branch cannot be purchased yet.",true),
		study("hub_garden","Community gardens",4,Vector2(20,170),{"hub_plan":1},[],[],[0],{},"Planned: new garden spaces and activities for the village.",true),
		study("hub_workshop","Expanded workshops",4,Vector2(300,170),{"hub_plan":1},[],[],[0],{},"Planned: improve village facilities and unlock more things to do.",true)]
static func find(id: String) -> Dictionary:
	for def in all():
		if def.id==id: return def
	return {}
