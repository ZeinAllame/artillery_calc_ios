-- جدول الأسلحة (المدافع والهاونات)
CREATE TABLE weapons (
    id TEXT PRIMARY KEY,
    name TEXT,
    caliber TEXT,
    max_range REAL,
    mils_full_circle INTEGER,
    barrel_wear_factor REAL -- معامل تآكل السبطانة
);

-- جدول الذخيرة (الأنواع)
CREATE TABLE ammo_types (
    id TEXT PRIMARY KEY,
    name TEXT,
    type TEXT -- HE, SMOKE, ILLUM
);

-- جدول حزم الذخيرة (LOTs)
CREATE TABLE ammo_lots (
    lot_id TEXT PRIMARY KEY,
    ammo_id TEXT,
    manufacture_date TEXT,
    velocity_variance REAL, -- فرق السرعة الابتدائية للحزمة
    FOREIGN KEY (ammo_id) REFERENCES ammo_types(id)
);

-- جدول سجل الرميات (BDA - Battle Damage Assessment)
CREATE TABLE fire_missions (
    id INTEGER PRIMARY KEY AUTOINCREMENT,
    timestamp TEXT,
    weapon_id TEXT,
    target_mgrs TEXT,
    azimuth REAL,
    elevation REAL,
    charge INTEGER,
    result_notes TEXT
);

-- جدول الأهداف المحفوظة
CREATE TABLE saved_targets (
    id INTEGER PRIMARY KEY AUTOINCREMENT,
    name TEXT,
    mgrs TEXT,
    elevation REAL,
    notes TEXT
);