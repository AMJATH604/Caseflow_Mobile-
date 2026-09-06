import 'package:flutter/material.dart';

class RightsCategory {
  final String id;
  final String title;
  final String icon;
  final List<Color> gradient;

  const RightsCategory({
    required this.id,
    required this.title,
    required this.icon,
    required this.gradient,
  });
}

class LaymanCard {
  final String id;
  final String categoryId;
  final String title;
  final String sectionOrStatute;
  final String coreLaw;
  final String whenItApplies;
  final String immediateRemedy;
  final String contactInfo;

  const LaymanCard({
    required this.id,
    required this.categoryId,
    required this.title,
    required this.sectionOrStatute,
    required this.coreLaw,
    required this.whenItApplies,
    required this.immediateRemedy,
    required this.contactInfo,
  });
}

class KnowYourRightsData {
  static const List<RightsCategory> categories = [
    RightsCategory(
      id: 'police',
      title: 'Police & Arrests',
      icon: '👮‍♂️',
      gradient: [Color(0xFF1E3A8A), Color(0xFF3B82F6)],
    ),
    RightsCategory(
      id: 'cybercrime',
      title: 'Theft & Cybercrime',
      icon: '📱',
      gradient: [Color(0xFF5B21B6), Color(0xFF8B5CF6)],
    ),
    RightsCategory(
      id: 'tenancy',
      title: 'Tenant & Landlord',
      icon: '🏠',
      gradient: [Color(0xFF065F46), Color(0xFF10B981)],
    ),
    RightsCategory(
      id: 'consumer',
      title: 'Consumer Forum',
      icon: '🛍️',
      gradient: [Color(0xFF9A3412), Color(0xFFF97316)],
    ),
    RightsCategory(
      id: 'workplace',
      title: 'Work & Labor',
      icon: '💼',
      gradient: [Color(0xFF374151), Color(0xFF6B7280)],
    ),
    RightsCategory(
      id: 'family',
      title: 'Family & Women',
      icon: '👩‍👩‍👧',
      gradient: [Color(0xFF9D174D), Color(0xFFEC4899)],
    ),
  ];

  static const List<LaymanCard> cards = [
    // POLICE & ARRESTS
    LaymanCard(
      id: 'police_fir',
      categoryId: 'police',
      title: 'Filing an FIR (First Information Report)',
      sectionOrStatute: 'Section 154 CrPC / Section 173 BNSS',
      coreLaw:
          'If a major crime occurs, the police are legally required to write it down in an FIR. They cannot refuse to write it. You are entitled to a FREE copy of this FIR immediately.',
      whenItApplies:
          'When you are a victim of or witness to a major crime like theft, physical assault, cyber fraud, burglary, or accident.',
      immediateRemedy:
          '1. Visit the nearest police station immediately.\n2. Verbally tell your complaint or give a written letter. The officer MUST write it down.\n3. Read the written FIR carefully to ensure all details are correct before signing.\n4. Ask for your FREE copy. If the officer refuses to write the FIR, you can send the complaint in writing to the Superintendent of Police (SP) by registered post.',
      contactInfo: 'National Emergency Number: 112 | Police Station: 100',
    ),
    LaymanCard(
      id: 'police_arrest_women',
      categoryId: 'police',
      title: 'Arrest Rights for Women',
      sectionOrStatute: 'Section 46(4) CrPC / Section 43(5) BNSS',
      coreLaw:
          'A woman cannot be arrested after sunset (6 PM) and before sunrise (6 AM) except under highly exceptional situations. Even then, the arrest can only be made by a WOMAN police officer, and only with the prior written permission of a Judicial Magistrate.',
      whenItApplies:
          'If female suspects are called, questioned, or arrested during night hours by the police.',
      immediateRemedy:
          '1. Politely inform the police that as a woman, you cannot be arrested at night.\n2. Insist that a woman officer must be present during any interrogation or custody.\n3. If forced or threatened, call 112 or the Women Helpline (1091) immediately.\n4. Inform family members or a lawyer to contact a Judicial Magistrate to highlight the illegal detention.',
      contactInfo: 'Women Helpline: 1091 or 181 | Police Emergency: 112',
    ),
    LaymanCard(
      id: 'police_traffic_encounters',
      categoryId: 'police',
      title: 'Traffic Police Encounters',
      sectionOrStatute: 'Motor Vehicles Act, 1988',
      coreLaw:
          'Only a police officer of the rank of Sub-Inspector or above can fine you on the spot. Constables can only note down your vehicle number. An officer cannot confiscate your car keys or force you out of the vehicle unless you are driving under the influence. Digital documents on DigiLocker/mParivahan are completely legal.',
      whenItApplies:
          'When you are stopped by traffic police for document checks, alleged speed violations, or standard traffic stops.',
      immediateRemedy:
          '1. Safely pull over and remain calm.\n2. Ask the officer to show their ID card and verify their nameplate.\n3. Show your DL, RC, Insurance, and PUC digitally via the government DigiLocker app.\n4. If fined on the spot, ask for an official printed challan or receipt. If harassed, take a video and report it to the Traffic Police Commissioner.',
      contactInfo: 'National Highway Helpline: 1033 | National Police: 112',
    ),

    // THEFT & CYBERCRIME
    LaymanCard(
      id: 'cyber_theft',
      categoryId: 'cybercrime',
      title: 'Theft of Personal Property',
      sectionOrStatute: 'Section 379 IPC / Section 303 BNS',
      coreLaw:
          'If anyone takes your phone, wallet, bag, vehicle, or any personal moveable property from your possession without your permission, it is theft.',
      whenItApplies:
          'When pickpocketed on a bus, your parked motorcycle is stolen, or a phone is snatched from your hand.',
      immediateRemedy:
          '1. Go to the nearest police station to file a Theft FIR immediately.\n2. For stolen phones: Obtain the FIR copy, block your IMEI code on the Central Equipment Identity Registry (ceir.gov.in) to render the device useless.\n3. For vehicles: Inform your insurance company within 24 hours of the theft along with the FIR copy.',
      contactInfo: 'CEIR Portal: ceir.gov.in | National Police Helpline: 112',
    ),
    LaymanCard(
      id: 'cyber_online_fraud',
      categoryId: 'cybercrime',
      title: 'Online Bank & UPI Fraud',
      sectionOrStatute: 'Information Technology Act / RBI Regulations',
      coreLaw:
          'If someone steals money from your bank account or credit card without your fault or sharing OTP/credentials, and you report it within 3 days, the bank is legally liable to refund the entire amount (Zero Liability rule).',
      whenItApplies:
          'When you receive phishing links, credit card fraud calls, or unauthorized money transfers occur from your bank or UPI apps.',
      immediateRemedy:
          '1. Call the national Cyber Crime Helpline 1930 within the golden first hour to block the fraud transaction.\n2. Report the incident online at cybercrime.gov.in.\n3. Inform your bank immediately to freeze your account/cards, and request an official dispute ticket.\n4. File a written complaint at the bank branch within 3 days.',
      contactInfo: 'National Cyber Crime Helpline: 1930 | cybercrime.gov.in',
    ),

    // TENANT & LANDLORD
    LaymanCard(
      id: 'tenancy_illegal_eviction',
      categoryId: 'tenancy',
      title: 'Protection Against Forceful Eviction',
      sectionOrStatute: 'Model Tenancy Act / State Rent Control Acts',
      coreLaw:
          'A landlord cannot throw a tenant out of the house forcefully, lock the doors, or cut off essential services like electricity or water supply without a court order, even if there is a rent dispute or the lease has expired.',
      whenItApplies:
          'When a landlord threatens to throw your luggage out, locks the premises, or cuts water/electricity to force you to vacate.',
      immediateRemedy:
          '1. Call 112 or visit the local police station to report the harassment. Cutting essential services is a police offense.\n2. Show your active Rent Agreement to the police.\n3. If threatened with eviction, consult an advocate to file a suit for "Temporary Injunction" in the local civil court to legally stop the landlord from touching your residency.',
      contactInfo: 'National Police: 112 | Local Rent Authority Office',
    ),
    LaymanCard(
      id: 'tenancy_deposit_dispute',
      categoryId: 'tenancy',
      title: 'Getting Back Security Deposit',
      sectionOrStatute: 'Model Tenancy Act, Section 11',
      coreLaw:
          'The security deposit paid to the landlord must be refunded to the tenant on the day the tenant vacates the house and hands over keys. The landlord can only deduct actual unpaid bills or pre-agreed painting charges, not arbitrary amounts.',
      whenItApplies:
          'When you are vacating the apartment and the landlord makes excuses or refuses to return your security deposit.',
      immediateRemedy:
          '1. Take high-quality photos/videos of the empty apartment as proof of its clean condition.\n2. Send a formal written request via WhatsApp/Email demanding deposit return.\n3. If they refuse, send a formal Legal Notice via an advocate. This solves 90% of deposit disputes immediately.\n4. File a petition before the Rent Court under the Model Tenancy Act.',
      contactInfo: 'Rent Court / Local SDM (Sub-Divisional Magistrate)',
    ),

    // CONSUMER FORUM
    LaymanCard(
      id: 'consumer_defective_goods',
      categoryId: 'consumer',
      title: 'Defective Products & Services',
      sectionOrStatute: 'Consumer Protection Act, 2019',
      coreLaw:
          'As a consumer, you have the right to get products that work correctly. If a product is defective, expired, or a service is extremely poor, you are legally entitled to get a replacement, repair, or full refund.',
      whenItApplies:
          'When you buy a brand new television that does not turn on, order a product online but receive a brick, or get overcharged beyond the MRP.',
      immediateRemedy:
          '1. Keep the invoice/bill and warranty card safe.\n2. Take photos of the defective product.\n3. Call the National Consumer Helpline at 1915 or register your complaint on consumerhelpline.gov.in.\n4. If the brand does not resolve it, file an official case online via the e-Daakhil portal (edaakhil.nic.in) to the Consumer Commission without needing a lawyer!',
      contactInfo: 'National Consumer Helpline: 1915 | edaakhil.nic.in',
    ),

    // WORK & LABOR
    LaymanCard(
      id: 'work_salary_withheld',
      categoryId: 'workplace',
      title: 'Unpaid Wages & Salary Withheld',
      sectionOrStatute: 'Payment of Wages Act, 1936',
      coreLaw:
          'Your employer cannot withhold your salary or deduct wages arbitrarily. You must be paid your salary on time (usually by the 7th or 10th of every month). Even if fired, your full and final settlement must be cleared.',
      whenItApplies:
          'When your company refuses to pay your salary for months, delays payments without reason, or fires you without clearing dues.',
      immediateRemedy:
          '1. Compile all proof of employment (Offer letter, payslips, bank statements, company emails).\n2. Send a formal demand letter via Email/Post to the HR/Owner.\n3. If unanswered, send a formal Legal Notice through an advocate.\n4. File an official complaint with the local Labor Commissioner office or file a wage recovery suit in the Labor Court.',
      contactInfo: 'Ministry of Labor and Employment | Local Labor Court',
    ),

    // FAMILY & WOMEN
    LaymanCard(
      id: 'family_domestic_violence',
      categoryId: 'family',
      title: 'Protection from Domestic Violence',
      sectionOrStatute: 'Protection of Women from Domestic Violence Act, 2005',
      coreLaw:
          'Any physical, emotional, sexual, or financial abuse of a woman inside a household by a husband or relative is a serious crime. The law guarantees protection orders, right to reside in the shared household, and monthly maintenance.',
      whenItApplies:
          'When a woman experiences hitting, threats, verbal insults, locking inside rooms, or starvation from her family/in-laws.',
      immediateRemedy:
          '1. Call the national domestic abuse hotline 181 immediately for safety and counseling.\n2. Visit the nearest police station or contact the designated "Protection Officer" in your district.\n3. You can file a petition under the DV Act before a Magistrate to get immediate "Interim Orders" for protection and financial support.\n4. Free legal aid is legally guaranteed for all victims.',
      contactInfo: 'Women Helpline: 181 or 1091 | Legal Aid Helpline: 15100',
    ),
  ];
}
