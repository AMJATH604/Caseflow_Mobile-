const fs = require('fs');

const user_new_sections = [
  ["TRANSFER OF PROPERTY ACT, 1882", "CHAPTER IV", "OF MORTGAGES OF IMMOVABLE PROPERTY AND CHARGES", "91", "Persons who may sue for redemption.", "Besides the mortgagor, any of the following persons may redeem, or institute a suit for redemption of, the mortgaged property, namely:— (a) any person (other than the mortgagee of the interest sought to be redeemed) who has any interest in, or charge upon, the property mortgaged or in or upon the right to redeem the same; (b) any surety for the payment of the mortgage-debt or any part thereof; or (c) any creditor of the mortgagor who has in a suit for the administration of his estate obtained a decree for sale of the mortgaged property."],
  ["TRANSFER OF PROPERTY ACT, 1882", "CHAPTER IV", "OF MORTGAGES OF IMMOVABLE PROPERTY AND CHARGES", "92", "Subrogation.", "Any of the persons referred to in section 91 (other than the mortgagor) and any co-mortgagor shall, on redeeming property subject to the mortgage, have, so far as regards redemption, foreclosure or sale of such property, the same rights as the mortgagee whose mortgage he redeems may have against the mortgagor or any other mortgagee. The same rights, in the same order, against the same properties, as the mortgagee whose mortgage is redeemed may have against the mortgagor or any other mortgagee. The provisions of section 81 shall, so far as may be, apply in the case of subrogation under this section."],
  ["TRANSFER OF PROPERTY ACT, 1882", "CHAPTER IV", "OF MORTGAGES OF IMMOVABLE PROPERTY AND CHARGES", "93", "Prohibition of tacking.", "No mortgagee paying off a prior mortgage, whether with or without notice of an intermediate mortgage, shall thereby acquire any priority in respect of his original security; and, except in the case provided for by section 79, no mortgagee making a subsequent advance to the mortgagor, whether with or without notice of an intermediate mortgage, shall thereby acquire any priority in respect of his security for such subsequent advance."],
  ["TRANSFER OF PROPERTY ACT, 1882", "CHAPTER IV", "OF MORTGAGES OF IMMOVABLE PROPERTY AND CHARGES", "94", "Rights of mesne mortgagee.", "Where property is mortgaged to two or more persons in succession and the successive mortgagees have different rights or priorities, the rights of the mesne mortgagee shall be the same as if he were the owner of the property mortgaged to him, subject to the rights of the prior mortgagee and the liabilities of the mortgagor."],
  ["TRANSFER OF PROPERTY ACT, 1882", "CHAPTER IV", "OF MORTGAGES OF IMMOVABLE PROPERTY AND CHARGES", "95", "Right of redeeming co-mortgagor to expenses.", "Where one of several mortgagors redeems the mortgaged property, he shall, in the absence of a contract to the contrary, be entitled to recover from his co-mortgagors their shares of the expenses properly incurred in so redeeming the property, and such shares shall be proportioned according to their respective shares in the property."],
  ["TRANSFER OF PROPERTY ACT, 1882", "CHAPTER IV", "OF MORTGAGES OF IMMOVABLE PROPERTY AND CHARGES", "96", "Mortgage by deposit of title-deeds.", "The provisions of this Chapter applicable to simple mortgages shall, so far as may be, apply to a mortgage by deposit of title-deeds."],
  ["TRANSFER OF PROPERTY ACT, 1882", "CHAPTER IV", "OF MORTGAGES OF IMMOVABLE PROPERTY AND CHARGES", "97", "[Repealed.]", "Repealed by the Code of Civil Procedure, 1908 (5 of 1908), Section 156 and Schedule V."],
  ["TRANSFER OF PROPERTY ACT, 1882", "CHAPTER IV", "OF MORTGAGES OF IMMOVABLE PROPERTY AND CHARGES", "98", "Rights and liabilities of parties to anomalous mortgages.", "In the case of an anomalous mortgage, the rights and liabilities of the parties shall be determined by their contract as evidenced in the mortgage-deed, and, so far as such contract does not extend, by local usage."],
  ["TRANSFER OF PROPERTY ACT, 1882", "CHAPTER IV", "OF MORTGAGES OF IMMOVABLE PROPERTY AND CHARGES", "99", "[Repealed.]", "Repealed by the Code of Civil Procedure, 1908 (5 of 1908), Section 156 and Schedule V."],
  ["TRANSFER OF PROPERTY ACT, 1882", "CHAPTER IV", "OF MORTGAGES OF IMMOVABLE PROPERTY AND CHARGES", "100", "Charges.", "Where immovable property of one person is by act of parties or operation of law made security for the payment of money to another, and the transaction does not amount to a mortgage, the latter person is said to have a charge on the property; and all the provisions hereinbefore contained which apply to a simple mortgage shall, so far as may be, apply to such charge. Nothing in this section applies to the charge of a trustee on the trust-property for expenses properly incurred in the execution of his trust, and, save as otherwise expressly provided by any law for the time being in force, no charge shall be enforced against any property in the hands of a person to whom such property has been transferred for consideration and without notice of the charge."],
  ["TRANSFER OF PROPERTY ACT, 1882", "CHAPTER IV", "OF MORTGAGES OF IMMOVABLE PROPERTY AND CHARGES", "101", "No merger in case of subsequent encumbrance.", "Any mortgagee of, or person having a charge upon, immovable property, or any transferee from such mortgagee or charge-holder, may purchase or otherwise acquire the rights in the property of the mortgagor or owner, as the case may be, without thereby causing the mortgage or charge to be merged as between himself and any subsequent mortgagee of, or person having a subsequent charge upon, the same property; and no such subsequent mortgagee or charge-holder shall be entitled to foreclose or sell such property without redeeming the prior mortgage or charge, or otherwise than subject thereto."],
  ["TRANSFER OF PROPERTY ACT, 1882", "CHAPTER IV", "OF MORTGAGES OF IMMOVABLE PROPERTY AND CHARGES", "102", "Service or tender on or to agent.", "Where the person on or to whom any notice or tender is to be served or made under this Chapter does not reside in the district in which the mortgaged property or any part thereof is situate, service or tender on or to an agent holding a general power of attorney from such person or otherwise duly authorised to accept such service or tender shall be deemed sufficient. Where no such agent is known, service or tender may be made on or to any agent of the person to be served or on or to any adult male member of his family who is residing with him."],
  ["TRANSFER OF PROPERTY ACT, 1882", "CHAPTER IV", "OF MORTGAGES OF IMMOVABLE PROPERTY AND CHARGES", "103", "Notice, etc., to or by person incompetent to contract.", "Where, under the provisions of this Chapter, a notice is to be served on or by, or a tender or deposit is to be made or accepted by, any person incompetent to contract, such notice may be served on or by or tender or deposit made or accepted by the legal curator of the property of such person; but where there is no such curator, and it is requisite that a notice should be served or a tender or deposit made under the provisions of this Chapter, such notice may be served or tender or deposit made on or by or to any person with whom the Court may appoint in this behalf."],
  ["TRANSFER OF PROPERTY ACT, 1882", "CHAPTER IV", "OF MORTGAGES OF IMMOVABLE PROPERTY AND CHARGES", "104", "Power to make rules.", "The High Court may, from time to time, make rules consistent with this Act for carrying out the provisions of this Chapter."]
];

const ACT_ID = '23e84a8c-5980-4787-866e-a157feef5089';

function cleanSql() {
    const content = fs.readFileSync('c:\\Users\\amjat\\OneDrive\\Desktop\\CASEFLOW\\scratch\\insert_tpa_sections.sql', 'utf8');
    
    // Simple parser for values
    const regex = /\('([^']*)', '([^']*)', '([^']*)', '([^']*)', '([^']*)', '(.*?)', (\d+)\)/gs;
    let match;
    const sections = [];
    
    while ((match = regex.exec(content)) !== null) {
        const [_, act_id, ch_num, ch_title, sec_num, sec_title, sec_text, seq] = match;
        
        if (sec_num === '54' || sec_num === '55') {
            if (ch_num === 'CHAPTER III') continue;
        }
        
        if (sec_num === '86 to 90') continue;
        
        sections.push({
            ch_num,
            ch_title,
            sec_num,
            sec_title,
            sec_text: sec_text.replace(/''/g, "'")
        });
    }
    
    // Add 86-90 Repealed
    for (let i = 86; i <= 90; i++) {
        sections.push({
            ch_num: 'CHAPTER IV',
            ch_title: 'OF MORTGAGES OF IMMOVABLE PROPERTY AND CHARGES',
            sec_num: i.toString(),
            sec_title: '[Repealed.]',
            sec_text: 'Repealed by the Code of Civil Procedure, 1908 (5 of 1908), Section 156 and Schedule V.'
        });
    }
    
    // Add user's 91-104
    for (const u of user_new_sections) {
        sections.push({
            ch_num: u[1],
            ch_title: u[2],
            sec_num: u[3],
            sec_title: u[4],
            sec_text: u[5]
        });
    }
    
    // Natural sort
    const naturalSort = (a, b) => {
        return a.sec_num.localeCompare(b.sec_num, undefined, { numeric: true, sensitivity: 'base' });
    };
    
    const uniqueSections = {};
    for (const s of sections) {
        if (s.sec_num === 'THE SCHEDULE') {
            uniqueSections['ZZZ'] = s;
        } else {
            uniqueSections[s.sec_num] = s;
        }
    }
    
    const sortedKeys = Object.keys(uniqueSections).sort((a, b) => {
        if (a === 'ZZZ') return 1;
        if (b === 'ZZZ') return -1;
        return a.localeCompare(b, undefined, { numeric: true });
    });
    
    let sqlLines = [];
    sortedKeys.forEach((key, index) => {
        const s = uniqueSections[key];
        const txt = s.sec_text.replace(/'/g, "''");
        const tit = s.sec_title.replace(/'/g, "''");
        sqlLines.push(`('${ACT_ID}', '${s.ch_num}', '${s.ch_title}', '${s.sec_num}', '${tit}', '${txt}', ${index + 1})`);
    });
    
    let finalSql = `DELETE FROM bare_act_sections WHERE act_id = '${ACT_ID}';\n\n`;
    finalSql += `INSERT INTO bare_act_sections (act_id, chapter_number, chapter_title, section_number, section_title, section_text, sequence_order) VALUES\n`;
    finalSql += sqlLines.join(',\n') + ';';
    
    fs.writeFileSync('c:\\Users\\amjat\\OneDrive\\Desktop\\CASEFLOW\\scratch\\fix_tpa_final.sql', finalSql);
    console.log(`Generated SQL with ${sqlLines.length} sections.`);
}

cleanSql();
