import '../models/models.dart';

class DataService {
  static final List<Weapon> allWeapons = [
    Weapon("mortar60", "هاون 60 ملم M224", "M224 60mm", "60mm", "هاون", 6400, 100.0, 2000.0, "أمريكي"),
    Weapon("mortar81", "هاون 81 ملم M252", "M252 81mm", "81mm", "هاون", 6400, 100.0, 3200.0, "أمريكي"),
    Weapon("mortar82", "هاون 82 ملم 2B14 Podnos", "2B14 Podnos", "82mm", "هاون", 6000, 100.0, 3200.0, "روسي"),
    Weapon("mortar120", "هاون 120 ملم M120/M220", "M120/220 120mm", "120mm", "هاون", 6400, 500.0, 6000.0, "أمريكي"),
    Weapon("mortar120s", "هاون 120 ملم 2S12 Sani", "2S12 Sani", "120mm", "هاون", 6000, 500.0, 6000.0, "روسي"),
    Weapon("m109a6", "مدفعية 155 ملم M109A6 Paladin", "M109A6 Paladin", "155mm", "ذاتية الحركة", 6400, 3000.0, 30000.0, "أمريكي"),
    Weapon("2s1", "مدفعية 122 ملم 2S1 Gvozdika", "2S1 Gvozdika", "122mm", "ذاتية الحركة", 6000, 1000.0, 15000.0, "روسي"),
    Weapon("m198", "مدفعية 155 ملم M198", "M198 155mm", "155mm", "مجرورة", 6400, 3000.0, 30000.0, "أمريكي"),
    Weapon("d30", "مدفعية 122 ملم D-30", "D-30 122mm", "122mm", "مجرورة", 6000, 1000.0, 16000.0, "روسي"),
    Weapon("type59", "مدفعية 130 ملم Type 59-1", "Type 59-1 130mm", "130mm", "مجرورة", 6000, 2000.0, 27000.0, "صيني"),
    Weapon("grad", "راجمة BM-21 Grad", "BM-21 Grad", "122mm", "راجمة صواريخ", 6000, 5000.0, 40000.0, "روسي"),
    Weapon("tos1a", "راجمة TOS-1A", "TOS-1A", "220mm", "راجمة صواريخ", 6000, 600.0, 6000.0, "روسي")
  ];

  static final List<Shell> allShells = [
    Shell("he", "متفجر / HE", "HE", "HE"),
    Shell("smoke", "دخان / WP", "Smoke WP", "SMOKE"),
    Shell("illum", "تنوير / Illum", "Illumination", "ILLUM")
  ];

  static Weapon? getWeaponById(String id) {
    try {
      return allWeapons.firstWhere((w) => w.id == id);
    } catch (e) {
      return null;
    }
  }
}