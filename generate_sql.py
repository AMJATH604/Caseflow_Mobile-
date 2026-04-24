import json
import uuid

# Read JSON
with open('ni_act.json', 'r', encoding='utf-8') as f:
    data = json.load(f)

act_id = '04ac82bd-f734-4fa8-9dbd-d697cfbfcadb'

sql_statements = []
sql_statements.append("INSERT INTO bare_act_sections (id, act_id, sequence_order, chapter_number, chapter_title, section_number, section_title, section_text, title, content) VALUES ")

values = []
for index, item in enumerate(data):
    if len(item) == 6:
        # Expected format: ["act name", "chapter num", "chapter title", "section num", "section title", "section text"]
        chapter_number = item[1].replace("'", "''")
        chapter_title = item[2].replace("'", "''")
        section_number = item[3].replace("'", "''")
        section_title = item[4].replace("'", "''")
        section_text = item[5].replace("'", "''")
        title = section_title
        content = section_text
        
        sequence_order = index + 1
        section_id = str(uuid.uuid4())
        
        val = f"('{section_id}', '{act_id}', {sequence_order}, '{chapter_number}', '{chapter_title}', '{section_number}', '{section_title}', '{section_text}', '{title}', '{content}')"
        values.append(val)

sql_statements.append(",\n".join(values) + ";")

with open('ni_act_insert.sql', 'w', encoding='utf-8') as f:
    f.write("".join(sql_statements))
    
print(f"Generated {len(values)} insert values.")
