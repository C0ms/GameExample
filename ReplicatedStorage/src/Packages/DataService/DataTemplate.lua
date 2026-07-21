-- @ScriptType: ModuleScript
export type stats = {
	timePlayed : number,
	RobuxSpent : number,
}

export type upgrades = {
	BaseClickValue : number,
	BaseMultiplier : number,
}

export type settings = {
	MusicVolume : number,
	SfxVolume : number,
}

export type tutorial = {
	CompletedTutorial : boolean,	
}

return {
	currency = 0,
	
	stats = {
		RobuxSpent = 0,
		timePlayed = 0,
	};
	
	upgrades = {
		BaseClickValue = 1,
		BaseMultiplier = 1,
	};

	settings = {
		MusicVolume = 1,
		SfxVolume = 1,
		
		ClickFov = true,
	};
}