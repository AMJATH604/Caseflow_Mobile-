-- MOHAMMEDAN LAW SECTIONS (FULL EXPANSION)
-- This script imports all sections for Shariat Act, DMMA, Triple Talaq Act, and general principles of Muslim Law.

-- Use the existing Act ID: '11b868c7-9888-4bb7-b431-44d280310e47'

DELETE FROM bare_act_sections WHERE act_id = '11b868c7-9888-4bb7-b431-44d280310e47';

INSERT INTO bare_act_sections (section_number, section_title, section_text, chapter_number, chapter_title, sequence_order, act_id)
VALUES 
('S1', 'Short title and extent', 'This Act may be called the Muslim Personal Law (Shariat) Application Act, 1937. It extends to the whole of India.', 'CH1_SHARIAT_ACT_1937', 'Muslim Personal Law (Shariat) Application Act, 1937', 1, '11b868c7-9888-4bb7-b431-44d280310e47'),
('S2', 'Application of Personal Law to Muslims', 'Shariat shall apply to all questions regarding intestate succession, special property of females, marriage, dissolution of marriage (talaq, ila, zihar, lian, khula and mubaraat), maintenance, dower, guardianship, gifts, trusts, and wakfs.', 'CH1_SHARIAT_ACT_1937', 'Muslim Personal Law (Shariat) Application Act, 1937', 2, '11b868c7-9888-4bb7-b431-44d280310e47'),
('S3', 'Power to make declaration', 'Optional application of Shariat to adoption, wills, and legacies via formal declaration.', 'CH1_SHARIAT_ACT_1937', 'Muslim Personal Law (Shariat) Application Act, 1937', 3, '11b868c7-9888-4bb7-b431-44d280310e47'),

('D2', 'Grounds for decree for dissolution of marriage', 'Grounds: Whereabouts unknown (4yrs), Failure to maintain (2yrs), Imprisonment (7yrs+), Failure of marital duties (3yrs), Impotence, Insanity (2yrs), Option of Puberty (15-18), Cruelty.', 'CH2_DISSOLUTION_1939', 'Dissolution of Muslim Marriages Act, 1939', 4, '11b868c7-9888-4bb7-b431-44d280310e47'),
('D4', 'Effect of conversion to another faith', 'Renunciation of Islam or conversion to another faith shall not by itself operate to dissolve her marriage.', 'CH2_DISSOLUTION_1939', 'Dissolution of Muslim Marriages Act, 1939', 5, '11b868c7-9888-4bb7-b431-44d280310e47'),

('T3', 'Talaq-e-Biddat (Triple Talaq) void', 'Any pronouncement of triple talaq (instant and irrevocable) by a Muslim husband is void and illegal.', 'CH3_TRIPLE_TALAQ_2019', 'Muslim Women (Protection of Rights on Marriage) Act, 2019', 6, '11b868c7-9888-4bb7-b431-44d280310e47'),
('T4', 'Punishment for triple talaq', 'Imprisonment up to 3 years and fine for pronouncing triple talaq.', 'CH3_TRIPLE_TALAQ_2019', 'Muslim Women (Protection of Rights on Marriage) Act, 2019', 7, '11b868c7-9888-4bb7-b431-44d280310e47'),

('P3', 'Mahr and maintenance at divorce', 'Entitlement to reasonable and fair provision, Mahr (Dower), maintenance for children (2yrs) and return of property.', 'CH4_DIVORCE_PROTECTION_1986', 'Muslim Women (Protection of Rights on Divorce) Act, 1986', 8, '11b868c7-9888-4bb7-b431-44d280310e47'),
('P4', 'Maintenance by relatives or Wakf Board', 'If divorced woman cannot maintain herself after Iddat, relatives or State Wakf Board shall provide maintenance.', 'CH4_DIVORCE_PROTECTION_1986', 'Muslim Women (Protection of Rights on Divorce) Act, 1986', 9, '11b868c7-9888-4bb7-b431-44d280310e47'),

('M1', 'Nature of Nikah (Marriage)', 'Nikah is a civil contract requiring Proposal (Ijab) and Acceptance (Qubul) in one sitting, presence of witnesses and capacity (sound mind, puberty).', 'CH5_MARRIAGE_NIKAH', 'Principles of Marriage (Nikah)', 10, '11b868c7-9888-4bb7-b431-44d280310e47'),
('MH1', 'Dower (Mahr)', 'Mahr is the sum/property wife is entitled to from husband. Prompt (Mu''ajjal) is on demand; Deferred (Muwajjal) on death/divorce.', 'CH6_DOWER_MAHR', 'Principles of Dower (Mahr)', 11, '11b868c7-9888-4bb7-b431-44d280310e47'),
('DV1', 'Modes of Divorce', 'Talaq Ahsan (Single), Talaq Hasan (Three), Talaq-e-Tafweez (Delegated), Khula (By wife for consideration), Mubarat (Mutual consent).', 'CH7_DIVORCE_TALAQ', 'Principles of Divorce', 12, '11b868c7-9888-4bb7-b431-44d280310e47'),
('G1', 'Guardianship (Hizanat)', 'Mother has right to Hizanat (custody) of son until 7 and daughter until puberty. Father is natural guardian of property.', 'CH8_GUARDIANSHIP', 'Principles of Guardianship', 13, '11b868c7-9888-4bb7-b431-44d280310e47'),
('I1', 'Inheritance (Succession)', 'Male gets double share of female. Sharers include Husband (1/4 or 1/2), Wife (1/8 or 1/4), Daughter (1/2 or 2/3 or residuary).', 'CH9_INHERITANCE', 'Principles of Inheritance', 14, '11b868c7-9888-4bb7-b431-44d280310e47'),
('GF1', 'Gifts (Hiba)', 'Valid Hiba requires Declaration, Acceptance and Delivery of possession. Writing is not mandatory.', 'CH10_GIFTS_HIBA', 'Principles of Gifts (Hiba)', 15, '11b868c7-9888-4bb7-b431-44d280310e47'),
('W1', 'Wills (Wasiyat)', 'A Muslim can bequeath only 1/3 of estate via will. Excess requires heirs'' consent.', 'CH11_WILLS_WASIYAT', 'Principles of Wills', 16, '11b868c7-9888-4bb7-b431-44d280310e47'),
('WK1', 'Wakf', 'Permanent dedication of property for religious/charitable purposes. Managed by Mutawalli.', 'CH12_WAKF', 'Principles of Wakf', 17, '11b868c7-9888-4bb7-b431-44d280310e47');
