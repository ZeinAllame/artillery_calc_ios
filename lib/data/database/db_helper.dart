class DbSchema {
  DbSchema._();

  // جدول الأسلحة (المدافع والهاونات)
  static const String createWeaponsTable = '''
    CREATE TABLE IF NOT EXISTS weapons (
      id TEXT PRIMARY KEY,
      name TEXT,
      caliber TEXT,
      max_range REAL,
      mils_full_circle INTEGER,
      barrel_wear_factor REAL
    );
  ''';

  // جدول الذخيرة (الأنواع)
  static const String createAmmoTypesTable = '''
    CREATE TABLE IF NOT EXISTS ammo_types (
      id TEXT PRIMARY KEY,
      name TEXT,
      type TEXT
    );
  ''';

  // جدول حزم الذخيرة (LOTs)
  static const String createAmmoLotsTable = '''
    CREATE TABLE IF NOT EXISTS ammo_lots (
      lot_id TEXT PRIMARY KEY,
      ammo_id TEXT,
      manufacture_date TEXT,
      velocity_variance REAL,
      FOREIGN KEY (ammo_id) REFERENCES ammo_types(id)
    );
  ''';

  // جدول سجل الرميات (BDA - Battle Damage Assessment)
  static const String createFireMissionsTable = '''
    CREATE TABLE IF NOT EXISTS fire_missions (
      id INTEGER PRIMARY KEY AUTOINCREMENT,
      timestamp TEXT,
      weapon_id TEXT,
      target_mgrs TEXT,
      azimuth REAL,
      elevation REAL,
      charge INTEGER,
      result_notes TEXT
    );
  ''';

  // جدول الأهداف المحفوظة
  static const String createSavedTargetsTable = '''
    CREATE TABLE IF NOT EXISTS saved_targets (
      id INTEGER PRIMARY KEY AUTOINCREMENT,
      name TEXT,
      mgrs TEXT,
      elevation REAL,
      notes TEXT
    );
  ''';
}
