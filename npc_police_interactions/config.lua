--[[
    NPC Police Interactions - Configuration
    All configurable values for the resource.
    Adjust these to fit your server's needs.
]]

Config = {}

-- ============================================================================
-- FRAMEWORK SETTINGS
-- ============================================================================
-- Auto-detect framework: 'auto', 'esx', 'qbcore', 'standalone'
Config.Framework = 'auto'

-- ============================================================================
-- GENERAL SETTINGS
-- ============================================================================
Config.Debug = false
Config.CommandPrefix = 'npcpolice'
Config.UseOxLib = true -- Set false to use built-in NUI menu instead

-- Police job names recognized by the system
Config.PoliceJobs = {
    'police',
    'sheriff',
    'trooper',
    'ranger',
    'marshal',
    'bcso',
    'sahp',
    'lspd',
}

-- Only allow on-duty officers to use the system (framework-dependent)
Config.RequireOnDuty = true

-- ============================================================================
-- NPC TRAFFIC SYSTEM
-- ============================================================================
Config.Traffic = {
    -- How many AI vehicles to manage in the player's vicinity
    MaxActiveVehicles = 8,

    -- Radius around player to spawn/manage NPC traffic (in meters)
    SpawnRadius = 200.0,
    DespawnRadius = 300.0,

    -- How often to check for new NPC spawns (ms)
    SpawnInterval = 8000,

    -- How often to update NPC driving behaviors (ms)
    BehaviorUpdateInterval = 2000,

    -- Traffic density multiplier (0.0 - 1.0) applied to ambient traffic
    DensityMultiplier = 0.7,

    -- Vehicle models that NPCs can drive (uses ambient vehicles if empty)
    VehicleModels = {},

    -- Ped models for NPC drivers
    PedModels = {
        'a_m_y_business_01',
        'a_m_y_downtown_01',
        'a_f_y_business_01',
        'a_m_m_farmer_01',
        'a_m_y_latino_01',
        'a_f_m_downtown_01',
        'a_m_y_genstreet_01',
        'a_f_y_tourist_01',
        'a_m_m_socenlat_01',
        'a_f_y_hipster_01',
        'a_m_y_hipster_01',
        'a_m_m_bevhills_01',
        'a_f_m_bevhills_01',
        'a_m_y_stwhi_01',
        'a_m_m_skater_01',
    },
}

-- ============================================================================
-- VIOLATION CHANCES (0.0 to 1.0)
-- ============================================================================
Config.Violations = {
    Speeding           = 0.25,
    RecklessDriving    = 0.10,
    IllegalTurn        = 0.08,
    RunStopSign        = 0.12,
    RunRedLight        = 0.10,
    Swerving           = 0.08,
    StolenVehicle      = 0.05,
    DUI                = 0.07,
    ExpiredRegistration = 0.15,
    ActiveWarrant      = 0.04,
    NoInsurance        = 0.12,
    BrokenTaillight    = 0.10,
    TintedWindows      = 0.06,
    NoSeatbelt         = 0.08,
}

-- Speed thresholds for speeding detection
Config.SpeedThresholds = {
    MinorSpeeding = 10.0,  -- MPH over limit
    MajorSpeeding = 25.0,  -- MPH over limit
    Reckless      = 40.0,  -- MPH over limit
}

-- ============================================================================
-- PULLOVER SYSTEM
-- ============================================================================
Config.Pullover = {
    -- Max distance behind NPC to initiate a stop
    DetectionRange = 30.0,

    -- How long sirens must be on behind NPC before they respond (ms)
    SirenResponseTime = 3000,

    -- Max distance NPC will travel to find a pullover spot
    PulloverSearchDistance = 100.0,

    -- Chance NPC will flee instead of pulling over (0.0 - 1.0)
    FleeChance = 0.08,

    -- Chance NPC will be aggressive upon approach
    AggressiveChance = 0.05,

    -- Time before NPC gets impatient and drives off (ms)
    PatienceTimeout = 120000,
}

-- ============================================================================
-- NPC REACTION PROFILES
-- ============================================================================
Config.Reactions = {
    Compliant = {
        chance = 0.55,
        cooperates = true,
        nervous = false,
        providesRealID = true,
        exitsOnCommand = true,
        allowsSearch = true,
    },
    Nervous = {
        chance = 0.15,
        cooperates = true,
        nervous = true,
        providesRealID = true,
        exitsOnCommand = true,
        allowsSearch = false,
    },
    Aggressive = {
        chance = 0.05,
        cooperates = false,
        nervous = false,
        providesRealID = false,
        exitsOnCommand = false,
        allowsSearch = false,
        mayAttack = true,
    },
    Intoxicated = {
        chance = 0.07,
        cooperates = true,
        nervous = false,
        providesRealID = true,
        exitsOnCommand = true,
        allowsSearch = true,
        slurredSpeech = true,
    },
    FakeID = {
        chance = 0.06,
        cooperates = true,
        nervous = true,
        providesRealID = false,
        exitsOnCommand = true,
        allowsSearch = false,
    },
    Wanted = {
        chance = 0.04,
        cooperates = false,
        nervous = true,
        providesRealID = false,
        exitsOnCommand = false,
        allowsSearch = false,
        mayFlee = true,
    },
    Armed = {
        chance = 0.03,
        cooperates = false,
        nervous = false,
        providesRealID = false,
        exitsOnCommand = false,
        allowsSearch = false,
        mayAttack = true,
        hasWeapon = true,
    },
    Uninsured = {
        chance = 0.05,
        cooperates = true,
        nervous = true,
        providesRealID = true,
        exitsOnCommand = true,
        allowsSearch = true,
    },
}

-- ============================================================================
-- EVIDENCE SYSTEM
-- ============================================================================
Config.Evidence = {
    -- Chance of finding contraband during vehicle search
    DrugChance       = 0.12,
    WeaponChance     = 0.06,
    StolenItemChance = 0.08,
    AlcoholChance    = 0.10,
    FakeIDChance     = 0.05,

    -- Possible drug types found
    DrugTypes = {
        { name = 'Marijuana',      weight = '2.5g',  severity = 'misdemeanor' },
        { name = 'Cocaine',        weight = '1.0g',  severity = 'felony' },
        { name = 'Methamphetamine', weight = '0.5g', severity = 'felony' },
        { name = 'Heroin',         weight = '0.3g',  severity = 'felony' },
        { name = 'Prescription Pills', weight = '10 pills', severity = 'misdemeanor' },
        { name = 'MDMA',           weight = '3 pills', severity = 'felony' },
    },

    -- Possible weapon types found
    WeaponTypes = {
        { name = 'Pistol',              model = 'WEAPON_PISTOL',       severity = 'felony' },
        { name = 'Knife',               model = 'WEAPON_KNIFE',        severity = 'misdemeanor' },
        { name = 'Switchblade',         model = 'WEAPON_SWITCHBLADE',  severity = 'misdemeanor' },
        { name = 'Sawed-Off Shotgun',   model = 'WEAPON_SAWNOFFSHOTGUN', severity = 'felony' },
        { name = 'Brass Knuckles',      model = 'WEAPON_KNUCKLE',      severity = 'misdemeanor' },
    },

    -- Possible stolen items found
    StolenItems = {
        { name = 'Stolen Laptop',       value = 1200 },
        { name = 'Stolen Jewelry',      value = 3500 },
        { name = 'Stolen Electronics',  value = 800 },
        { name = 'Stolen Purse',        value = 450 },
        { name = 'Counterfeit Bills',   value = 2000 },
    },
}

-- ============================================================================
-- ARREST SYSTEM
-- ============================================================================
Config.Arrest = {
    -- Handcuff animation dictionary and name
    HandcuffAnimDict = 'mp_arrest_paired',
    HandcuffAnimOfficer = 'cop_p2_back_right',
    HandcuffAnimSuspect = 'crook_p2_back_right',

    -- Escort settings
    EscortOffset = vector3(0.45, 0.35, 0.0),
    EscortSpeed = 1.0,

    -- Jail despawn settings
    JailLocation = vector3(1691.47, 2565.93, 45.56), -- Bolingbroke
    DespawnDelay = 5000, -- ms after reaching jail before cleanup

    -- Transport settings
    MaxTransportDistance = 500.0,
}

-- ============================================================================
-- TICKET / FINE AMOUNTS
-- ============================================================================
Config.Fines = {
    Speeding           = { min = 150,  max = 500 },
    RecklessDriving    = { min = 500,  max = 1500 },
    IllegalTurn        = { min = 100,  max = 250 },
    RunStopSign        = { min = 150,  max = 350 },
    RunRedLight        = { min = 200,  max = 500 },
    Swerving           = { min = 200,  max = 600 },
    StolenVehicle      = { min = 5000, max = 10000 },
    DUI                = { min = 1000, max = 5000 },
    ExpiredRegistration = { min = 100, max = 300 },
    NoInsurance        = { min = 250,  max = 750 },
    BrokenTaillight    = { min = 50,   max = 150 },
    TintedWindows      = { min = 100,  max = 250 },
    NoSeatbelt         = { min = 75,   max = 200 },
}

-- ============================================================================
-- NPC IDENTITY GENERATION
-- ============================================================================
Config.Identity = {
    FirstNames = {
        Male = {
            'James', 'John', 'Robert', 'Michael', 'David', 'William', 'Richard',
            'Joseph', 'Thomas', 'Charles', 'Daniel', 'Matthew', 'Anthony', 'Mark',
            'Steven', 'Paul', 'Andrew', 'Joshua', 'Kenneth', 'Kevin', 'Brian',
            'George', 'Timothy', 'Ronald', 'Edward', 'Jason', 'Jeffrey', 'Ryan',
        },
        Female = {
            'Mary', 'Patricia', 'Jennifer', 'Linda', 'Barbara', 'Elizabeth',
            'Susan', 'Jessica', 'Sarah', 'Karen', 'Lisa', 'Nancy', 'Betty',
            'Margaret', 'Sandra', 'Ashley', 'Dorothy', 'Kimberly', 'Emily',
            'Donna', 'Michelle', 'Carol', 'Amanda', 'Melissa', 'Deborah',
        },
    },
    LastNames = {
        'Smith', 'Johnson', 'Williams', 'Brown', 'Jones', 'Garcia', 'Miller',
        'Davis', 'Rodriguez', 'Martinez', 'Hernandez', 'Lopez', 'Gonzalez',
        'Wilson', 'Anderson', 'Thomas', 'Taylor', 'Moore', 'Jackson', 'Martin',
        'Lee', 'Perez', 'Thompson', 'White', 'Harris', 'Sanchez', 'Clark',
        'Ramirez', 'Lewis', 'Robinson', 'Walker', 'Young', 'Allen', 'King',
    },
    -- Age range for generated NPCs
    MinAge = 18,
    MaxAge = 75,
}

-- ============================================================================
-- DIALOGUE SYSTEM
-- ============================================================================
Config.Dialogue = {
    -- Compliant NPC responses
    Compliant = {
        greeting = {
            "Good evening, officer. What seems to be the problem?",
            "Hello, officer. Was I doing something wrong?",
            "Hi there. I'm not sure why you pulled me over.",
            "Good day, officer. How can I help you?",
            "Evening, officer. Is everything alright?",
        },
        idRequest = {
            "Sure, here's my license and registration.",
            "Of course, one moment please.",
            "Absolutely, let me grab that for you.",
            "Here you go, officer.",
            "No problem, it's right here.",
        },
        exitVehicle = {
            "Okay, I'll step out right now.",
            "Sure thing, officer.",
            "Alright, no problem.",
            "Yes sir/ma'am, stepping out now.",
        },
        searchConsent = {
            "Go ahead, I have nothing to hide.",
            "Sure, you can search it.",
            "That's fine with me, officer.",
        },
    },

    -- Nervous NPC responses
    Nervous = {
        greeting = {
            "O-oh... officer... h-hi...",
            "Um... is there a problem, officer?",
            "I... I wasn't doing anything wrong, was I?",
            "*sweating* Hello, officer...",
            "Oh god... I mean, hello officer...",
        },
        idRequest = {
            "*hands shaking* H-here you go...",
            "I... let me find it... one second...",
            "*fumbling through wallet* Sorry, I'm just nervous...",
            "Um... yeah... here... here it is...",
        },
        exitVehicle = {
            "O-okay... am I in trouble?",
            "*hesitantly opens door* Alright...",
            "Did I do something wrong? I'll get out...",
        },
        searchConsent = {
            "I... I'd rather you didn't...",
            "Do you have to? I mean... okay...",
            "I'm not comfortable with that...",
        },
    },

    -- Aggressive NPC responses
    Aggressive = {
        greeting = {
            "What the hell do you want?",
            "You got a reason for pulling me over?",
            "This is harassment!",
            "I know my rights!",
            "Don't you have real criminals to catch?",
        },
        idRequest = {
            "I don't have to show you anything!",
            "Am I being detained?",
            "You can't make me show you that!",
            "I'm not giving you my ID!",
        },
        exitVehicle = {
            "I'm not getting out of my car!",
            "You can't make me get out!",
            "No way! This is illegal!",
            "I refuse to exit this vehicle!",
        },
        searchConsent = {
            "Absolutely not! Get a warrant!",
            "You have no right to search my vehicle!",
            "I do NOT consent to any searches!",
        },
    },

    -- Intoxicated NPC responses
    Intoxicated = {
        greeting = {
            "*slurred* Heyyy ossifer... what's up?",
            "I'm... I'm totally fine, offisher...",
            "*hiccup* Good evening...",
            "Whoa... hey there... *burp*",
            "I only had like... two beers... maybe five...",
        },
        idRequest = {
            "*drops wallet* Oops... hehe... here ya go...",
            "Lemme find... where'd I put... oh here...",
            "*fumbling* I got it... I got it...",
        },
        exitVehicle = {
            "*stumbles out* I'm fine... I'm fine...",
            "Whoa... the ground is moving...",
            "*nearly falls* Yeah I can walk...",
        },
        searchConsent = {
            "Go ahead... I got nothin'... I think...",
            "Sure... whatever you want, ossifer...",
        },
    },

    -- Wanted/Fleeing NPC
    Wanted = {
        greeting = {
            "*looking around nervously* Hey... officer...",
            "Am I free to go? I'm in a hurry...",
            "Look, I really need to get going...",
            "Is this going to take long?",
        },
        idRequest = {
            "I... I left my wallet at home...",
            "I don't have my ID on me...",
            "Can I just give you my name?",
        },
        flee = {
            "*floor it*",
            "*tires screech*",
            "*jumps out and runs*",
        },
    },
}

-- ============================================================================
-- IMMERSION / DISPATCH
-- ============================================================================
Config.Immersion = {
    -- Enable dispatch notifications
    EnableDispatch = true,

    -- Enable subtitle dialogue
    EnableSubtitles = true,

    -- Subtitle display time (ms)
    SubtitleDuration = 5000,

    -- Enable police radio chatter sounds
    EnableRadioChatter = true,

    -- Dispatch message format
    DispatchMessages = {
        trafficStop = "~b~10-38~w~ Traffic stop initiated at ~y~%s",
        pursuit = "~r~10-80~w~ Vehicle pursuit in progress near ~y~%s",
        footPursuit = "~r~10-80~w~ Foot pursuit in progress near ~y~%s",
        arrest = "~b~10-15~w~ Suspect in custody at ~y~%s",
        backup = "~r~10-78~w~ Officer requesting backup at ~y~%s",
        codeRed = "~r~CODE RED~w~ Shots fired at ~y~%s",
        allClear = "~g~10-98~w~ Assignment complete at ~y~%s",
        stolenVehicle = "~r~10-851~w~ Stolen vehicle located near ~y~%s",
        dui = "~o~10-55~w~ Possible DUI driver near ~y~%s",
        warrant = "~r~10-29~w~ Warrant confirmed for detained subject",
    },
}

-- ============================================================================
-- BREATHALYZER / DRUG TEST
-- ============================================================================
Config.Tests = {
    -- BAC levels (Blood Alcohol Content)
    BACLevels = {
        sober    = { min = 0.00, max = 0.02 },
        buzzed   = { min = 0.03, max = 0.07 },
        impaired = { min = 0.08, max = 0.15 },
        drunk    = { min = 0.16, max = 0.30 },
    },

    -- Legal BAC limit
    LegalBACLimit = 0.08,

    -- Drug test possible results
    DrugTestResults = {
        'Negative',
        'THC Positive',
        'Cocaine Positive',
        'Amphetamine Positive',
        'Opiate Positive',
        'Benzodiazepine Positive',
    },
}

-- ============================================================================
-- ANIMATION SETTINGS
-- ============================================================================
Config.Anims = {
    -- Interaction animations
    Clipboard   = { dict = 'veh@busted_std',          name = 'idle_a' },
    Notepad     = { dict = 'missheistdockssetup1',     name = 'wave_goodbye' },
    PointGun    = { dict = 'reaction@intimidation@1h', name = 'intro' },
    Frisk       = { dict = 'missheist_agency2aig_yourside', name = 'yourside_yourside_loop_duo_a' },
    SearchCar   = { dict = 'anim@gangops@facility@server_booths@', name = 'intobooth' },
    Breathalyzer = { dict = 'amb@code_human_wander_drinking@male@idle_a', name = 'idle_a' },
    Surrender   = { dict = 'mp_arresting', name = 'idle' },
    HandsUp     = { dict = 'missminuteman_1ig_2', name = 'handsup_base' },
    Escort      = { dict = 'mp_arresting', name = 'idle' },
}

-- ============================================================================
-- KEYBINDS
-- ============================================================================
Config.Keys = {
    InteractionMenu = 38,  -- E key
    CancelAction    = 73,  -- X key
    Escort          = 47,  -- G key
}

-- ============================================================================
-- PROGRESS BAR SETTINGS
-- ============================================================================
Config.ProgressDurations = {
    RequestID     = 3000,
    RunPlate      = 5000,
    AskQuestions  = 4000,
    Frisk         = 6000,
    SearchVehicle = 8000,
    Breathalyzer  = 5000,
    DrugTest      = 7000,
    WriteTicket   = 4000,
    Handcuff      = 3000,
    PlaceInVehicle = 4000,
    TowVehicle    = 10000,
}
