const fs = require('fs');
const path = require('path');
const { createClient } = require('@supabase/supabase-js');

require('dotenv').config();

const SUPABASE_URL = process.env.SUPABASE_URL;
const SUPABASE_KEY = process.env.SUPABASE_KEY;
const MVA_ACT_ID = '8800cfc2-2e21-477d-844a-9e1e4a1f6d4d';

const rawData = [
  [
    "CHAPTER_I",
    "PRELIMINARY",
    "1",
    "Short title, extent and commencement.",
    "(1) This Act may be called the Motor Vehicles Act, 1988. (2) It extends to the whole of India. (3) It shall come into force on such date as the Central Government may, by notification in the Official Gazette, appoint; and different dates may be appointed for different State and any reference in this Act to the commencement of this Act shall, in relation to a State, be construed as a reference to the coming into force of this Act in that State."
  ],
  [
    "CHAPTER_I",
    "PRELIMINARY",
    "2",
    "Definitions.",
    "In this Act, unless the context otherwise requires,— (1) “area”, in relation to any provision of this Act, means such area as the State Government may, having regard to the requirements of that provision, specify by notification in the Official Gazette; (2) “articulated vehicle” means a motor vehicle to which a semitrailer is attached; (3) “axle weight” means in relation to an axle of a vehicle the total weight transmitted by the several wheels attached to that axle to the surface on which the vehicle rests; (4) “certificate of registration” means the certificate issued by a competent authority to the effect that a motor vehicle has been duly registered in accordance with the provisions of Chapter IV; (5) “conductor”, in relation to a stage carriage, means a person engaged in collecting fares from passengers, regulating their entrance into, or exit from, the stage carriage and performing such other functions as may be prescribed; (6) “conductor’s licence” means the licence issued by a competent authority under Chapter III authorising the person specified therein to act as a conductor; (7) “contract carriage” means a motor vehicle which carries a passenger or passenger or passengers for hire or reward and is engaged under a contract, whether expressed or implied, for the use of such vehicle as a whole for the carriage of passengers mentioned therein and entered into by a person with a holder of a permit in relation to such vehicle or any person authorised by him in this behalf on a fixed or an agreed rate or sum— (a) on a time basis, whether or not with reference to any route or distance; or (b) from one point to another, and in either case, without stopping to pick up or set down passengers not included in the contract anywhere during the journey, and includes— (i) a maxicab; and (ii) a motor cab notwithstanding that separate fares are charged for its passengers; (8) “dealer” includes a person who is engaged— (b) in building bodies for attachment to chassis; or (c) in the repair of motor vehicles; or (d) in the business of hypothecation, leasing or hire-purchase of motor vehicle; (9) “driver” includes, in relation to a motor vehicle which is drawn by another motor vehicle, the person who acts as a steersman of the drawn vehicle; (10) “driving licence” means the licence issued by a competent authority under Chapter II authorising the person specified therein to drive, otherwise than as a learner, a motor vehicle or a motor vehicle of any specified class or description; (11) “educational institution bus” means an omnibus, which is owned by a college, school or other educational institution and used solely for the purpose of transporting students or staff of the educational institution in connection with any of its activities; (12) “fares” includes sums payable for a season ticket or in respect of the hire of a contract carriage; (13) “goods” includes live-stock, and anything (other than equipment ordinarily used with the vehicle) carried by a vehicle except living persons, but does not include luggage or personal effects carried in a motor car or in a trailer attached to a motor car or the personal luggage of passengers travelling in the vehicle; (14) “goods carriage” means any motor vehicle constructed or adapted for use solely for the carriage of goods, or any motor vehicle not so constructed or adapted when used for the carriage of goods; (15) “gross vehicle weight” means in respect of any vehicle the total weight of the vehicle and load certified and registered by the registering authority as permissible for that vehicle; (16) “heavy goods vehicle” means any goods carriage the gross vehicle weight of which, or a tractor or a road-roller the unladen weight of either of which, exceeds 12,000 kilograms; (17) “heavy passenger motor vehicle” means any public service vehicle or private service vehicle or educational institution bus or omnibus the gross vehicle weight of any of which, or a motor car the unladen weight of which, exceeds 12,000 kilograms; (18) “invalid carriage” means a motor vehicle specially designed and constructed, and not merely, adapted, for the use of a person suffering from some physical defect or disability, and used solely by or for such a person; (19) “learner’s licence” means the licence issued by a competent authority under Chapter II authorising the person specified therein to drive as a learner, a motor vehicle or a motor vehicle of any specified class or description; (20) “licensing authority” means an authority empowered to issue licences under Chapter II or, as the case may be, Chapter III; (21) “light motor vehicle” means a transport vehicle or omnibus the gross vehicle weight of either of which or a motor car or tractor or road-roller the unladen weight of any of which, does not exceed 7500 kilograms; (21A) “manufacturer” means a person who is engaged in the manufacture of motor vehicles; (22) “maxicab” means any motor vehicle constructed or adapted to carry more than six passengers, but not more than twelve passengers, excluding the driver, for hire or reward; (23) “medium goods vehicle” means any goods carriage other than a light motor vehicle or a heavy goods vehicle; (24) “medium passenger motor vehicle” means any public service vehicle or private service vehicle, or educational institution bus other than a motor cycle, invalid carriage, light motor vehicle or heavy passenger motor vehicle; (25) “motorcab” means any motor vehicle constructed or adapted to carry not more than six passengers excluding the driver for hire or reward; (26) “motor car” means any motor vehicle other than a transport vehicle, omnibus, road-roller, tractor, motor cycle or invalid carriage; (27) “motor cycle” means a two-wheeled motor vehicle, inclusive of any detachable side-car having an extra wheel, attached to the motor vehicle; (28) “motor vehicle” or “vehicle” means any mechanically propelled vehicle adapted for use upon roads whether the power of propulsion is transmitted thereto from an external or internal source and includes a chassis to which a body has not been attached and a trailer; but does not include a vehicle running upon fixed rails or a vehicle of a special type adapted for use only in a factory or in any other enclosed premises or a vehicle having less than four wheels fitted with engine capacity of not exceeding twenty-five cubic centimetres; (29) “omnibus” means any motor vehicle constructed or adapted to carry more than six persons excluding the driver; (30) “owner” means a person in whose name a motor vehicle stands registered, and where such person is a minor, the guardian of such minor, and in relation to a motor vehicle which is the subject of a hire-purchase, agreement, or an agreement of lease or an agreement of hypothecation, the person in possession of the vehicle under that agreement; (31) “permit” means a permit issued by a State or Regional Transport Authority or an authority prescribed in this behalf under this Act authorising the use of a motor vehicle as a transport vehicle; (32) “prescribed” means prescribed by rules made under this Act; (33) “private service vehicle” means a motor vehicle constructed or adapted to carry more than six persons excluding the driver and ordinarily used by or on behalf of the owner of such vehicle for the purpose of carrying persons for, or in connection with, his trade or business otherwise than for hire or reward but does not include a motor vehicle used for public purposes; (34) “public place” means a road, street, way or other place, whether a thoroughfare or not, to which the public have a right of access, and includes any place or stand at which passengers are picked up or set down by a stage carriage; (35) “public service vehicle” means any motor vehicle used or adapted to be used for the carriage of passengers for hire or reward, and includes a maxicab, a motorcab, contract carriage, and stage carriage; (36) “registered axle weight” means in respect of the axle of any vehicle, the axle weight certified and registered by the registering authority as permissible for that axle; (37) “registering authority” means an authority empowered to register motor vehicles under Chapter IV; (38) “route” means a line of travel which specifies the highway which may be traversed by a motor vehicle between one terminus and another; (39) “semi-trailer” means a vehicle not mechanically propelled (other than a trailer), which is intended to be connected to a motor vehicle and which is so constructed that a portion of it is superimposed on, and a part of whose weight is borne by, that motor vehicle; (40) “stage carriage” means a motor vehicle constructed or adapted to carry more than six passengers excluding the driver for hire or reward at separate fares paid by or for individual passengers, either for the whole journey or for stages of the journey; (41) “State Government” in relation to a Union territory means the Administrator thereof appointed under article 239 of the Constitution; (42) “State transport undertaking” means any undertaking providing road transport service, where such undertaking is carried on by,— (i) the Central Government or a State Government; (ii) any Road Transport Corporation established under section 3 of the Road Transport Corporations Act, 1950 (64 of 1950); (iii) any municipality or any corporation or company owned or controlled by the Central Government or one or more State Governments, or by the Central Government and one or more State Governments; (iv) Zilla Parishad or any other similar local authority. Explanation.—For the purposes of this clause, “road transport service” means a service of motor vehicles carrying passengers or goods or both by road for hire or reward; (43) “tourist vehicle” means a contract carriage constructed or adapted and equipped and maintained in accordance with such specifications as may be prescribed in this behalf; (44) “tractor” means a motor vehicle which is not itself constructed to carry any load (other than equipment used for the purpose of propulsion); but excludes a road-roller; (45) “traffic signs” includes all signals, warning sign posts, direction posts, markings on the road or other devices for the information, guidance or direction of drivers of motor vehicles; (46) “trailer” means any vehicle, other than a semi-trailer and a side-car, drawn or intended to be drawn by a motor vehicle; (47) “transport vehicle” means a public service vehicle, a goods carriage, an educational institution bus or a private service vehicle; (48) “unladen weight” means the weight of a vehicle or trailer including all equipment ordinarily used with the vehicle or trailer when working, but excluding the weight of a driver or attendant; and where alternative parts or bodies are used the unladen weight of the vehicle means the weight of the vehicle with the heaviest such alternative part or body; (49) “weight” means the total weight transmitted for the time being by the wheels of a vehicle to the surface on which the vehicle rests."
  ],
  [
    "CHAPTER_I",
    "PRELIMINARY",
    "2A",
    "e-cart and e-rickshaw.",
    "(1) Save as otherwise provided in the proviso to sub-section (1) of section 7 and sub-section (10) of section 9, the provisions of this Act shall apply to e-cart and e-rickshaw. (2) For the purposes of this section, “e-cart or e-rickshaw” means a special purpose battery powered vehicle of power not exceeding 4000 watts, having three wheels for carrying goods or passengers, as the case may be, for hire or reward, manufactured, constructed or adapted, equipped and maintained in accordance with such specifications, as may be prescribed in this behalf."
  ],
  [
    "CHAPTER_I",
    "PRELIMINARY",
    "3",
    "Necessity for driving licence.",
    "(1) No person shall drive a motor vehicle in any public place unless he holds an effective driving licence issued to him authorising him to drive the vehicle; and no person shall so drive a transport vehicle [other than a motor cab or motor cycle hired for his own use or rented under any scheme made under sub-section (2) of section 75] unless his driving licence specifically entitles him so to do. (2) The conditions subject to which sub-section (1) shall not apply to a person receiving instructions in driving a motor vehicle shall be such as may be prescribed by the Central Government."
  ],
  [
    "CHAPTER_II",
    "LICENSING OF DRIVERS OF MOTOR VEHICLES",
    "4",
    "Age limit in connection with driving of motor vehicles.",
    "(1) No person under the age of eighteen years shall drive a motor vehicle in any public place: Provided that a motor cycle with engine capacity not exceeding 50cc may be driven in a public place by a person after attaining the age of sixteen years. (2) Subject to the provisions of section 18, no person under the age of twenty years shall drive a transport vehicle in any public place. (3) No learner’s licence or driving licence shall be issued to any person to drive a vehicle of the class to which he has made an application unless he is eligible to drive that class of vehicle under this section."
  ],
  [
    "CHAPTER_II",
    "LICENSING OF DRIVERS OF MOTOR VEHICLES",
    "5",
    "Responsibility of owners of motor vehicles for contravention of sections 3 and 4.",
    "No owner or person in charge of a motor vehicle shall cause or permit any person who does not satisfy the provisions of section 3 or section 4 to drive the vehicle."
  ],
  [
    "CHAPTER_II",
    "LICENSING OF DRIVERS OF MOTOR VEHICLES",
    "6",
    "Restrictions on the holding of driving licences.",
    "(1) No person shall, while he holds any driving licence for the time being in force, hold any other driving licence except a learner’s licence or a driving licence issued in accordance with the provisions of section 18 or a document authorising, in accordance with the rules made under section 139, the person specified therein to drive a motor vehicle. (2) No holder of a driving licence or a learner’s licence shall permit it to be used by any other person. (3) Nothing in this section shall prevent a licensing authority having the jurisdiction referred to in sub-section (1) of section 9 from adding to the classes of vehicles which the driving licence authorises the holder to drive."
  ],
  [
    "CHAPTER_II",
    "LICENSING OF DRIVERS OF MOTOR VEHICLES",
    "7",
    "Restrictions on the granting of learner’s licences for certain vehicles.",
    "(1) No person shall be granted a learner's licence to drive a transport vehicle unless he has held a driving licence to drive a light motor vehicle for at least one year: Provided that nothing contained in this sub-section shall apply to an e-cart or e-rickshaw. (2) No person under the age of eighteen years shall be granted a learner’s licence to drive a motor cycle without gear except with the consent in writing of the person having the care of the person desiring the learner’s licence."
  ],
  [
    "CHAPTER_II",
    "LICENSING OF DRIVERS OF MOTOR VEHICLES",
    "8",
    "Grant of learner’s licence.",
    "(1) Any person who is not disqualified under section 4 for driving a motor vehicle and who is not for the time being disqualified for holding or obtaining a driving licence may, subject to the provisions of section 7, apply to the licensing authority having jurisdiction in the area— (i) in which he ordinarily resides or carries on business, or (ii) in which the school or establishment referred to in section 12 from where he intends to receive instruction in driving a motor vehicle is situate, for the issue to him of a learner’s licence. (2) Every application under sub-section (1) shall be in such form and shall be accompanied by such documents and with such fee as may be prescribed by the Central Government. (3) Every application under sub-section (1) shall be accompanied by a medical certificate in such form as may be prescribed by the Central Government and signed by such registered medical practitioner, as the State Government or any person authorised in this behalf by the State Government may, by notification in the Official Gazette, appoint for this purpose: Provided that no such medical certificate is required for licence to drive a vehicle other than a transport vehicle. (4) If, from the application or from the medical certificate referred to in sub-section (3), it appears that the applicant is suffering from any disease or disability which is likely to cause the driving by him of a motor vehicle of the class which he would be authorised by the learner’s licence applied for to drive to be a source of danger to the public or to the passengers, the licensing authority shall refuse to issue the learner’s licence: Provided that a learner’s licence limited to driving an invalid carriage may be issued to the applicant, if the licensing authority is satisfied that he is fit to drive such a carriage. (5) No learner’s licence shall be issued to any applicant unless he passes to the satisfaction of the licensing authority such test as may be prescribed by the Central Government. (6) When an application has been duly made to the appropriate licensing authority and the applicant has satisfied such authority of his physical fitness under sub-section (3) and has passed to the satisfaction of the licensing authority the test referred to in sub-section (5), the licensing authority shall, subject to the provisions of section 7, issue the applicant a learner’s licence unless the applicant is disqualified under section 4 for driving a motor vehicle or is for the time being disqualified for holding or obtaining a licence to drive a motor vehicle: Provided that a licensing authority may issue a learner’s licence to drive a motor cycle or a light motor vehicle notwithstanding that it is not the appropriate licensing authority, if such authority is satisfied that there is good reason for the applicant’s inability to apply to the appropriate licensing authority. (7) Where the Central Government is satisfied that it is necessary or expedient so to do, it may, by rules made in this behalf, exempt generally, either absolutely or subject to such conditions as may be specified in the rules, any class of persons from the provisions of sub-section (3), or sub-section (5), or both. (8) Any learner’s licence for driving a motor cycle in force immediately before the commencement of this Act shall, after such commencement, be deemed to be effective for driving a motor cycle with or without gear."
  ],
  [
    "CHAPTER_II",
    "LICENSING OF DRIVERS OF MOTOR VEHICLES",
    "9",
    "Grant of driving licence.",
    "(1) Any person who is not for the time being disqualified for holding or obtaining a driving licence may apply to the licensing authority having jurisdiction in the area— (i) in which he ordinarily resides or carries on business, or (ii) in which the school or establishment referred to in section 12 from where he is receiving or has received instruction in driving a motor vehicle is situated, for the issue to him of a driving licence. (2) Every application under sub-section (1) shall be in such form and shall be accompanied by such fee and such documents as may be prescribed by the Central Government. (3) If the applicant passes such test as may be prescribed by the Central Government, he shall be issued the driving licence: Provided that no such test shall be necessary where the applicant produces proof to show that— (a) (i) the applicant has previously held a driving licence to drive such class of vehicle and that the period between the date of expiry of that licence and the date of the application does not exceed five years, or (ii) the applicant holds or has previously held a driving licence to drive such class of vehicle issued under section 18, or (iii) the applicant holds a driving licence to drive such class of vehicle issued by a competent authority of any country outside India, subject to the condition that the applicant complies with the provisions of sub-section (3) of section 8, (b) the applicant is not suffering from any disability which is likely to cause the driving by him to be a source of danger to the public; and the licensing authority may, for that purpose, require the applicant to produce a medical certificate in the same form and in the same manner as is referred to in sub-section (3) of section 8: Provided further that where the application is for a driving licence to drive a motor vehicle (not being a transport vehicle), the licensing authority may exempt the applicant from the test of competence to drive a vehicle prescribed under this sub-section, if the applicant possesses a driving certificate issued by any institution recognised in this behalf by the State Government. (4) Where the application is for a licence to drive a transport vehicle, no such authorisation shall be granted to any applicant unless he possesses such minimum educational qualification as may be prescribed by the Central Government and a driving certificate issued by a school or establishment referred to in section 12. (5) Where the applicant does not pass the test, he may be permitted to re-appear for the test after a period of seven days: Provided that where the applicant does not pass the test even after three appearances, he shall not be qualified to re-appear for such test before the expiry of a period of sixty days from the date of last such test. (6) The test of competence to drive shall be carried out in a vehicle of the type to which the application refers: Provided that a person who passed a test in driving a motor cycle with gear shall be deemed also to have passed a test in driving a motor cycle without gear. (7) When any application has been duly made to the appropriate licensing authority and the applicant has satisfied such authority of his competence to drive, the licensing authority shall issue the applicant a driving licence unless the applicant is for the time being disqualified for holding or obtaining a driving licence: Provided that a licensing authority may issue a driving licence to drive a motor cycle or a light motor vehicle notwithstanding that it is not the appropriate licensing authority, if the licensing authority is satisfied that there is good and sufficient reason for the applicant’s inability to apply to the appropriate licensing authority: Provided further that the licensing authority shall not issue a new driving licence to the applicant, if he had previously held a driving licence, unless it is satisfied that there is good and sufficient reason for his inability to obtain a duplicate copy of his former licence. (8) If the licensing authority is satisfied, after giving the applicant an opportunity of being heard, that he— (a) is a habitual criminal or a habitual drunkard; or (b) is a habitual addict to any narcotic drug or psychotropic substance within the meaning of the Narcotic Drugs and Psychotropic Substances Act, 1985 (61 of 1985); or (c) is a person whose licence to drive any motor vehicle has, at any time earlier, been revoked, it may, for reasons to be recorded in writing, make an order refusing to issue a driving licence to such person and any person aggrieved by an order made by a licensing authority under this sub-section may, within thirty days of the receipt of the order, appeal to the prescribed authority. (9) Any driving licence for driving a motor cycle in force immediately before the commencement of this Act shall, after such commencement, be deemed to be effective for driving a motor cycle with or without gear. (10) Notwithstanding anything contained in this section, the driving licence to drive e-cart or e-rickshaw shall be issued in such manner and subject to such conditions, as may be prescribed."
  ],
  [
    "CHAPTER_II",
    "LICENSING OF DRIVERS OF MOTOR VEHICLES",
    "10",
    "Form and contents of licences to drive.",
    "(1) Every learner’s licence and driving licence, except a driving licence issued under section 18, shall be in such form and shall contain such information as may be prescribed by the Central Government. (2) A learner’s licence or, as the case may be, driving licence shall also be expressed as entitling the holder to drive a motor vehicle of one or more of the following classes, namely:— (a) motor cycle without gear; (b) motor cycle with gear; (c) invalid carriage; (d) light motor vehicle; (e) transport vehicle; (i) road-roller; (j) motor vehicle of a specified description."
  ],
  [
    "CHAPTER_II",
    "LICENSING OF DRIVERS OF MOTOR VEHICLES",
    "11",
    "Additions to driving licence.",
    "(1) Any person holding a driving licence to drive any class or description of motor vehicles, who is not for the time being disqualified for holding or obtaining a driving licence to drive any other class or description of motor vehicles, may apply to the licensing authority having jurisdiction in the area in which he resides or carries on his business in such form and accompanied by such documents and with such fees as may be prescribed by the Central Government for the addition of such other class or description of motor vehicles to the licence. (2) Subject to such rules as may be prescribed by the Central Government, the provisions of section 9 shall apply to an application under this section as if the said application were for the grant of a licence under that section to drive the class or description of motor vehicles which the applicant desires to be added to his licence."
  ],
  [
    "CHAPTER_II",
    "LICENSING OF DRIVERS OF MOTOR VEHICLES",
    "12",
    "Licensing and regulation of schools or establishments for imparting instruction in driving of motor vehicles.",
    "(1) The Central Government may make rules for the purpose of licensing and regulating, by the State Governments, schools or establishments (by whatever name called) for imparting instruction in driving of motor vehicles and matters connected therewith. (2) In particular, and without prejudice to the generality of the foregoing power, such rules may provide for all or any of the following matters, namely:— (a) licensing of such schools or establishments including grant, renewal and revocation of such licences; (b) supervision of such schools or establishments; (c) the form of application and the form of licence and the particulars to be contained therein; (d) fee to be paid with the application for such licences; (e) conditions subject to which such licences may be granted; (f) appeals against the orders of refusal to grant or renew such licences; (g) conditions subject to which such licences may be granted, renewed or revoked; (h) appeals against the orders of refusal to grant or renew such licences and appeals against orders revoking such licences; (i) conditions subject to which motor cabs may be rented; (j) maintenance of records and inspection of such records; (k) such other matters as may be necessary to carry out the purposes of this section."
  ],
  [
    "CHAPTER_II",
    "LICENSING OF DRIVERS OF MOTOR VEHICLES",
    "13",
    "Extent of effectiveness of licences, to drive motor vehicles.",
    "The provisions of this Chapter relating to the grant, revocation and suspension of permits shall apply to the grant, revocation and suspension of countersignatures of permits: Provided that it shall not be necessary to follow the procedure laid down in section 80 for the grant of countersignatures of permits, where the permits granted in any one State are required to be countersigned by the State Transport Authority of another State or by the Regional Transport Authority concerned as a result of any agreement arrived at between the States after complying with the requirements of sub-section (5)."
  ],
  [
    "CHAPTER_II",
    "LICENSING OF DRIVERS OF MOTOR VEHICLES",
    "14",
    "Currency of licences to drive motor vehicles.",
    "(1) A driving licence issued under this Act shall be effective for a period of twenty years from the date of issue or until the holder attains the age of fifty years, whichever is earlier: Provided that the Regional Transport Authority may renew a licence issued under this section after the expiry of the period of twenty years from the date of issue or on the holder attaining the age of fifty years, for a further period of five years at a time. (2) A learner’s licence issued under this Act shall be effective for a period of six months from the date of issue."
  ],
  [
    "CHAPTER_II",
    "LICENSING OF DRIVERS OF MOTOR VEHICLES",
    "15",
    "Renewal of driving licences.",
    "(1) Any licensing authority may, on application made to it, renew a driving licence issued under this Act so as to be effective for a further period of five years: Provided that a driving licence may be renewed so as to be effective for a further period of five years at a time. (2) An application for the renewal of a driving licence shall be made in such form and accompanied by such fee as may be prescribed by the Central Government. (3) If the application for renewal of a driving licence is made after the expiry of the period of its validity, the application shall be accompanied by an additional fee as may be prescribed by the Central Government. (4) When the application for renewal has been made, the licensing authority may for reasons to be recorded in writing refuse to renew a driving licence unless the applicant undergoes and passes to its satisfaction the test of competence to drive as prescribed under sub-section (3) of section 9. (5) Every application for renewal of a driving licence shall be accompanied by a medical certificate in such form and containing such particulars as may be prescribed by the Central Government. (6) Where the application for renewal of a driving licence is made after the expiry of the period of its validity, the licensing authority may, for reasons to be recorded in writing, refuse to renew the driving licence unless the applicant undergoes and passes to its satisfaction the test of competence to drive as prescribed under sub-section (3) of section 9. (7) A driving licence renewed under this section shall be effective from the date of its renewal."
  ],
  [
    "CHAPTER_II",
    "LICENSING OF DRIVERS OF MOTOR VEHICLES",
    "16",
    "Revocation of driving licence on grounds of disease or disability.",
    "A driving licence may at any time be revoked by any licensing authority if that authority has reasonable grounds to believe that the holder of the licence is suffering from any disease or disability which is likely to render him permanently unfit to hold such a licence and where the authority revoking a driving licence is not the authority which issued the same, it shall intimate the fact of such revocation to the authority which issued that licence: Provided that before revoking any licence, the licensing authority shall give the person holding such licence a reasonable opportunity of being heard."
  ],
  [
    "CHAPTER_II",
    "LICENSING OF DRIVERS OF MOTOR VEHICLES",
    "17",
    "Orders refusing or revoking driving licences and appeals therefrom.",
    "(1) Where a licensing authority refuses to issue or renew, or revokes any driving licence, it shall do so by an order communicated to the applicant or the holder, as the case may be, giving the reasons in writing for such refusal or revocation. (2) Any person aggrieved by an order made under sub-section (1) may, within thirty days of the service on him of the order, appeal to the prescribed authority which shall decide the appeal after giving such person and the authority which made the order an opportunity of being heard and the decision of the appellate authority shall be binding on the authority which made the order."
  ],
  [
    "CHAPTER_II",
    "LICENSING OF DRIVERS OF MOTOR VEHICLES",
    "18",
    "Driving Licences to drive motor vehicles, belonging to the Central Government.",
    "(1) Such authority as the Central Government may, by notification in the Official Gazette, specify, may grant driving licences valid throughout India to persons employed by the Central Government for driving motor vehicles belonging to the Central Government. (2) A driving licence issued under this section shall specify the class or classes of motor vehicles which the holder is entitled to drive and the period for which the licence is valid. (3) The authority granting a driving licence under this section may attach thereto any condition referred to in sub-section (2) of section 9 and the provisions of sections 9, 11, 13, 15, 16 and 17 shall, so far as may be, apply in relation to the driving licence issued under this section as they apply in relation to the driving licence issued under that section."
  ],
  [
    "CHAPTER_II",
    "LICENSING OF DRIVERS OF MOTOR VEHICLES",
    "19",
    "Power of licensing authority to disqualify from holding a driving licence or revoke such licence.",
    "(1) If a licensing authority is satisfied, after giving the holder of a driving licence an opportunity of being heard, that he— (a) is a habitual criminal or a habitual drunkard; or (b) is a habitual addict to any narcotic drug or psychotropic substance within the meaning of the Narcotic Drugs and Psychotropic Substances Act, 1985 (61 of 1985); or (c) is a person whose licence to drive any motor vehicle has, at any time earlier, been revoked, it may, for reasons to be recorded in writing, make an order disqualifying that person for a specified period for holding or obtaining any driving licence. (2) Upon the issue of any such order, the holder of the driving licence shall forthwith surrender the licence to the authority making the order, if the licence has not already been surrendered, and the authority shall keep the licence until the disqualification has expired or has been removed. (3) Any person in respect of whom any order under sub-section (1) is made may, at any time after the expiry of six months from the date of the order, apply to the licensing authority for the removal of the disqualification. (4) The licensing authority may, after making such enquiry as it may deem fit, remove the disqualification or refuse to remove it. (5) A person in respect of whom any order under sub-section (1) is made shall, so long as the disqualification remains in force, be deemed to be disqualified for holding or obtaining any licence to drive any motor vehicle which he would otherwise have been entitled to hold or obtain. (6) The foregoing provisions of this section shall apply in relation to a conductor’s licence as if the conductor’s licence were a driving licence."
  ],
  [
    "CHAPTER_II",
    "LICENSING OF DRIVERS OF MOTOR VEHICLES",
    "20",
    "Power of Court to disqualify.",
    "(1) Where any person is convicted of an offence under this Act or of an offence in the commission of which a motor vehicle was used, the Court by which such person is convicted may, in addition to imposing any other punishment authorised by law, declare the person so convicted to be disqualified for such period as the Court may specify for holding any driving licence or for holding a driving licence to drive a particular class or description of vehicle. (2) The Court to which an appeal lies from any conviction of an offence under this Act may set aside or vary any order of disqualification made by the Court below, and the Court to which appeals ordinarily lie from such Court, may set aside or vary any order of disqualification made by that Court, notwithstanding that no appeal lies against the conviction in connection with which such order was made."
  ],
  [
    "CHAPTER_II",
    "LICENSING OF DRIVERS OF MOTOR VEHICLES",
    "21",
    "Suspension of driving licence in certain cases.",
    "(1) Where a person is convicted of any offence under this Act or of any offence in the commission of which a motor vehicle was used, the Court by which such person is convicted may, if it is of opinion that it will be dangerous for such person to drive any motor vehicle, suspend the driving licence of such person for such period as the Court may specify in the order. (2) The Court shall send a copy of the order of suspension to the licensing authority which issued the driving licence. (3) The Court may, if it is of opinion that it will be dangerous for such person to drive any motor vehicle, order that the person convicted shall be disqualified for holding or obtaining a driving licence for such period as the Court may specify in the order. (4) The Court shall send a copy of the order of disqualification to the licensing authority which issued the driving licence. (5) Where the Court makes an order of suspension or disqualification under this section, it shall send a copy of the order to the owner of the motor vehicle concerned."
  ],
  [
    "CHAPTER_II",
    "LICENSING OF DRIVERS OF MOTOR VEHICLES",
    "22",
    "Suspension or cancellation of driving licence on conviction.",
    "(1) Where a person is convicted of an offence under this Act or of an offence in the commission of which a motor vehicle was used, the Court by which such person is convicted may, in addition to imposing any other punishment authorised by law, suspend the driving licence of such person for such period as the Court may specify in the order or cancel the driving licence. (2) The Court shall send a copy of the order of suspension or cancellation to the licensing authority which issued the driving licence. (3) The Court may, if it is of opinion that it will be dangerous for such person to drive any motor vehicle, order that the person convicted shall be disqualified for holding or obtaining a driving licence for such period as the Court may specify in the order. (4) The Court shall send a copy of the order of disqualification to the licensing authority which issued the driving licence."
  ],
  [
    "CHAPTER_II",
    "LICENSING OF DRIVERS OF MOTOR VEHICLES",
    "23",
    "Effect of disqualification order.",
    "(1) Where a person is disqualified under this Act for holding or obtaining a driving licence, the licence, if any, held by him shall be deemed to have been suspended so long as the disqualification remains in force. (2) Where a person is disqualified under this Act for holding or obtaining a driving licence, the licensing authority shall, on receipt of a copy of the order of disqualification, endorse the disqualification on the driving licence, if any, held by the person disqualified and keep the licence in its safe custody until the disqualification has expired or has been removed."
  ],
  [
    "CHAPTER_II",
    "LICENSING OF DRIVERS OF MOTOR VEHICLES",
    "24",
    "Endorsement.",
    "(1) The Court or authority making or ordering the endorsement of any disqualification or suspension or cancellation of a driving licence shall send a copy of the order of endorsement to the licensing authority which issued the driving licence. (2) The licensing authority which issued the driving licence shall, on receipt of a copy of the order of endorsement, endorse the disqualification, suspension or cancellation on the driving licence and keep the licence in its safe custody until the disqualification, suspension or cancellation has expired or has been removed."
  ],
  [
    "CHAPTER_II",
    "LICENSING OF DRIVERS OF MOTOR VEHICLES",
    "25",
    "Transfer of endorsement and issue of driving licence free from endorsement.",
    "(1) An endorsement made under section 24 in respect of any person on a driving licence issued by the licensing authority of one State shall operate as if it had been made by the licensing authority of the State in which the person to whom it relates is for the time being resident. (2) Where the driving licence of a person is endorsed under section 24 and such person ceases to be a resident of the State in which the endorsement was made and becomes a resident of another State, the licensing authority of the first mentioned State shall intimate the fact of the endorsement and the nature of the endorsement to the licensing authority of the other State and the licensing authority of the other State shall make the endorsement on the driving licence of such person in accordance with the intimation received by it from the licensing authority of the first mentioned State. (3) Where the driving licence of a person is endorsed under section 24 and such person ceases to be a resident of the State in which the endorsement was made and becomes a resident of another State and the driving licence is surrendered to the licensing authority of the first mentioned State under sub-section (2) of section 9, the licensing authority of the first mentioned State shall transmit the driving licence to the licensing authority of the other State and the licensing authority of the other State shall make the endorsement on the driving licence in accordance with the intimation received by it from the licensing authority of the first mentioned State. (4) Where the driving licence of a person is endorsed under section 24 and such person ceases to be a resident of the State in which the endorsement was made and becomes a resident of another State and the driving licence is not surrendered to the licensing authority of the first mentioned State under sub-section (2) of section 9, the licensing authority of the first mentioned State shall transmit a copy of the driving licence to the licensing authority of the other State and the licensing authority of the other State shall make the endorsement on the driving licence in accordance with the intimation received by it from the licensing authority of the first mentioned State. (5) The driving licence of a person which has been endorsed under section 24 shall be issued free from endorsement if such person produces a certificate from the licensing authority of the State in which he is for the time being resident to the effect that he has not been disqualified for holding or obtaining a driving licence and the period of disqualification, if any, has expired."
  ],
  [
    "CHAPTER_II",
    "LICENSING OF DRIVERS OF MOTOR VEHICLES",
    "26",
    "Maintenance of State Registers of Driving Licences.",
    "(1) Each State Government shall maintain, in such form as may be prescribed by the Central Government, a register to be known as the State Register of Driving Licences, in respect of the driving licences issued and renewed by the licensing authorities in the State, containing the following particulars, namely:— (a) names and addresses of holders of driving licences; (b) the dates of issue or renewal of the licences; (c) the dates of expiry of the licences; (d) the classes and types of vehicles authorised to be driven; and (e) such other particulars as may be prescribed by the Central Government. (2) Each State Government shall supply to the Central Government a printed copy of the State Register of Driving Licences and shall inform the Central Government without delay of all additions to and other amendments in such register made from time to time. (3) The State Register of Driving Licences shall be maintained in such manner as may be prescribed by the State Government."
  ],
  [
    "CHAPTER_II",
    "LICENSING OF DRIVERS OF MOTOR VEHICLES",
    "27",
    "Power of Central Government to make rules.",
    "The Central Government may make rules to provide for all or any of the following matters, namely:— (a) the conditions subject to which sub-section (1) of section 3 shall not apply to a person receiving instruction in driving a motor vehicle; (b) the manner in which the driving licence shall be issued and renewed and the documents, particulars and information it shall contain; (c) the period for which the driving licence shall be effective; (d) the manner in which the learner’s licence shall be issued and renewed and the documents, particulars and information it shall contain; (e) the manner in which the application for driving licence or for its renewal shall be made and the fee to be paid; (f) the form in which and the manner in which the application for driving licence or for its renewal shall be made and the fee to be paid; (g) the form of medical certificate and the particulars and information it shall contain; (h) the form in which and the manner in which the application for driving licence or for its renewal shall be made and the fee to be paid; (i) the form in which and the manner in which the application for driving licence or for its renewal shall be made and the fee to be paid; (j) the form in which and the manner in which the application for driving licence or for its renewal shall be made and the fee to be paid; (k) the form in which and the manner in which the application for driving licence or for its renewal shall be made and the fee to be paid; (l) the form in which and the manner in which the application for driving licence or for its renewal shall be made and the fee to be paid; (m) the form in which and the manner in which the application for driving licence or for its renewal shall be made and the fee to be paid; (n) the form in which and the manner in which the application for driving licence or for its renewal shall be made and the fee to be paid; (o) the form in which and the manner in which the application for driving licence or for its renewal shall be made and the fee to be paid; (p) the form in which and the manner in which the application for driving licence or for its renewal shall be made and the fee to be paid; (q) the form in which and the manner in which the application for driving licence or for its renewal shall be made and the fee to be paid; (r) the form in which and the manner in which the application for driving licence or for its renewal shall be made and the fee to be paid; (s) the form in which and the manner in which the application for driving licence or for its renewal shall be made and the fee to be paid; (t) the form in which and the manner in which the application for driving licence or for its renewal shall be made and the fee to be paid; (u) the form in which and the manner in which the application for driving licence or for its renewal shall be made and the fee to be paid; (v) the form in which and the manner in which the application for driving licence or for its renewal shall be made and the fee to be paid; (w) the form in which and the manner in which the application for driving licence or for its renewal shall be made and the fee to be paid; (x) the form in which and the manner in which the application for driving licence or for its renewal shall be made and the fee to be paid; (y) the form in which and the manner in which the application for driving licence or for its renewal shall be made and the fee to be paid; (z) the form in which and the manner in which the application for driving licence or for its renewal shall be made and the fee to be paid."
  ],
  [
    "CHAPTER_II",
    "LICENSING OF DRIVERS OF MOTOR VEHICLES",
    "28",
    "Power of State Government to make rules.",
    "(1) A State Government may make rules for the purpose of carrying into effect the provisions of this Chapter other than the matters specified in section 27. (2) Without prejudice to the generality of the foregoing power, such rules may provide for— (a) the appointment, jurisdiction, control and functions of licensing authorities and other prescribed authorities; (b) the conduct and hearing of appeals that may be preferred under this Chapter, the fees to be paid in respect of such appeals and the refund of such fees; (c) the issue of duplicate licences to replace licences lost, destroyed or mutilated, the replacement of photographs which have become obsolete and the fees to be charged therefor; (d) the manner in which particulars of endorsements on a licence may be transmitted to the licensing authority which granted the licence; (e) the particulars to be included in the register to be maintained under this Chapter and the manner in which such register shall be maintained and the particulars to be included in the register to be maintained under section 26 and the manner in which such register shall be maintained; (f) the issue or renewal of licences and the forms thereof; (g) the exemption of prescribed persons or prescribed classes of persons from payment of all or any portion of the fees payable under this Chapter; (h) the authorities to whom the appeals may be preferred under this Chapter and the time within which such appeals may be preferred; (i) the exemption of persons or classes of persons from the provisions of this Chapter; (j) the manner in which and the conditions subject to which the driving licence may be endorsed; (k) any other matter which is to be or may be prescribed."
  ],
  [
    "CHAPTER_III",
    "LICENSING OF CONDUCTORS OF STAGE CARRIAGES",
    "29",
    "Necessity for conductor’s licence.",
    "(1) No person shall act as a conductor of a stage carriage unless he holds an effective conductor’s licence issued to him authorising him to act as such conductor; and no person shall employ or permit any person who is not so licensed to act as a conductor of a stage carriage. (2) A State Government may prescribe the conditions subject to which sub-section (1) shall not apply to a person temporarily employed as a conductor of a stage carriage on the occurrence of an emergency."
  ],
  [
    "CHAPTER_III",
    "LICENSING OF CONDUCTORS OF STAGE CARRIAGES",
    "30",
    "Grant of conductor’s licence.",
    "(1) Any person who is not disqualified under section 31 for holding or obtaining a conductor’s licence may apply to the licensing authority having jurisdiction in the area in which he ordinarily resides or carries on business for the issue to him of a conductor’s licence. (2) Every application under sub-section (1) shall be in such form and shall contain such particulars as may be prescribed. (3) Every application for a conductor’s licence shall be accompanied by a medical certificate in such form as may be prescribed, signed by a registered medical practitioner and shall also be accompanied by two clear copies of a recent photograph of the applicant. (4) A conductor’s licence issued under this Chapter shall be in such form and contain such particulars as may be prescribed and shall be effective throughout the State in which it is issued. (5) The fee for a conductor’s licence and for each renewal thereof shall be one-half of that for a driving licence."
  ]
];

function processData() {
  console.log('=== TRANSFORMING DATA ===');
  const transformed = rawData.map((item, index) => ({
    chapter_number: item[0] || '',
    chapter_title: item[1] || '',
    section_number: item[2] || '',
    section_title: item[3] || '',
    section_text: item[4] || ''
  }));

  // 1. Save locally as JSON
  const jsonPath = path.join(__dirname, '../../data/legal/motor_vehicles_act.json');
  console.log(`Writing JSON dataset to ${jsonPath}...`);
  fs.mkdirSync(path.dirname(jsonPath), { recursive: true });
  fs.writeFileSync(jsonPath, JSON.stringify(transformed, null, 2), 'utf8');

  // 2. Generate version-controlled SQL file
  const sqlPath = path.join(__dirname, '../db/import_motor_vehicles_act.sql');
  console.log(`Generating SQL file at ${sqlPath}...`);
  
  let sqlLines = [
    `-- MOTOR VEHICLES ACT, 1988 - REGISTRATION & IMPORT`,
    `INSERT INTO bare_acts (id, title, short_title, year, is_active)`,
    `VALUES (`,
    `    '${MVA_ACT_ID}', `,
    `    'Motor Vehicles Act, 1988', `,
    `    'Motor Vehicles Act',`,
    `    1988,`,
    `    true`,
    `) ON CONFLICT (id) DO NOTHING;`,
    ``,
    `-- Purge old sections if any`,
    `DELETE FROM bare_act_sections WHERE act_id = '${MVA_ACT_ID}';`,
    ``,
    `-- SECTIONS`,
    `INSERT INTO bare_act_sections (section_number, section_title, section_text, chapter_number, chapter_title, sequence_order, act_id, title, content)`,
    `VALUES`
  ];

  const esc = (str) => {
    if (!str) return '';
    return str.replace(/'/g, "''");
  };

  const valueLines = transformed.map((s, index) => {
    const sectionNumber = esc(s.section_number);
    const sectionTitle = esc(s.section_title);
    const sectionText = esc(s.section_text);
    const chapterNumber = esc(s.chapter_number);
    const chapterTitle = esc(s.chapter_title);
    const sequenceOrder = index + 1;

    return `('${sectionNumber}', '${sectionTitle}', '${sectionText}', '${chapterNumber}', '${chapterTitle}', ${sequenceOrder}, '${MVA_ACT_ID}', '${sectionTitle}', '${sectionText}')`;
  });

  const finalSql = sqlLines.join('\n') + '\n' + valueLines.join(',\n') + ';';
  fs.mkdirSync(path.dirname(sqlPath), { recursive: true });
  fs.writeFileSync(sqlPath, finalSql, 'utf8');

  console.log('Conversion and generation completed successfully!');
}

async function uploadToSupabase() {
  console.log('\n=== UPLOADING TO SUPABASE ===');
  if (!SUPABASE_URL || !SUPABASE_KEY) {
    console.error('Error: SUPABASE_URL or SUPABASE_KEY is missing from environment variables!');
    process.exit(1);
  }

  const supabase = createClient(SUPABASE_URL, SUPABASE_KEY);

  const jsonPath = path.join(__dirname, '../../data/legal/motor_vehicles_act.json');
  const sections = JSON.parse(fs.readFileSync(jsonPath, 'utf8'));

  const transformedUpload = sections.map((item, index) => ({
    act_id: MVA_ACT_ID,
    chapter_number: item.chapter_number || '',
    chapter_title: item.chapter_title || '',
    section_number: item.section_number || '',
    section_title: item.section_title || '',
    section_text: item.section_text || '',
    title: item.section_title || '',
    content: item.section_text || '',
    sequence_order: index + 1,
  }));

  console.log(`Purging old MVA sections from bare_act_sections (act_id: ${MVA_ACT_ID})...`);
  const { error: purgeError } = await supabase
    .from('bare_act_sections')
    .delete()
    .eq('act_id', MVA_ACT_ID);

  if (purgeError) {
    console.error('Failed to purge existing records:', purgeError);
    process.exit(1);
  }
  console.log('Successfully purged old records.');

  console.log('Inserting sections in batches of 10...');
  const batchSize = 10;
  let inserted = 0;
  let failed = 0;

  for (let i = 0; i < transformedUpload.length; i += batchSize) {
    const batch = transformedUpload.slice(i, i + batchSize);
    const batchNum = Math.floor(i / batchSize) + 1;
    const totalBatches = Math.ceil(transformedUpload.length / batchSize);
    console.log(`Uploading batch ${batchNum}/${totalBatches} (${batch.length} records)...`);

    const { error } = await supabase
      .from('bare_act_sections')
      .insert(batch);

    if (error) {
      console.error(`  Error in batch ${batchNum}:`, error.message || error);
      failed += batch.length;
    } else {
      inserted += batch.length;
    }
  }

  console.log('\n=== UPLOAD SUMMARY ===');
  console.log(`Successfully inserted: ${inserted}`);
  console.log(`Failed to insert: ${failed}`);
  console.log(`Total processed: ${inserted + failed}/${transformedUpload.length}`);

  if (failed > 0) {
    process.exit(1);
  }
}

// Execute phases
try {
  processData();
  uploadToSupabase().then(() => {
    console.log('Setup successfully completed!');
  }).catch(err => {
    console.error('Failed to upload:', err);
    process.exit(1);
  });
} catch (err) {
  console.error('Error during processing:', err);
  process.exit(1);
}
