import 'package:caseflow/components/ai_chat/markdown_body.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('parseMarkdownBlocks', () {
    test('plain lines become one paragraph', () {
      final blocks = parseMarkdownBlocks('Under Section 138\nof the NI Act.');
      expect(blocks, [
        const MdBlock(MdBlockType.paragraph, 'Under Section 138 of the NI Act.'),
      ]);
    });

    test('a blank line separates paragraphs', () {
      final blocks = parseMarkdownBlocks('First para.\n\nSecond para.');
      expect(blocks.length, 2);
      expect(blocks[0].text, 'First para.');
      expect(blocks[1].text, 'Second para.');
    });

    test('headings carry their level', () {
      final blocks = parseMarkdownBlocks('# One\n## Two\n### Three');
      expect(blocks.map((b) => b.type).toSet(), {MdBlockType.heading});
      expect(blocks.map((b) => b.level).toList(), [1, 2, 3]);
      expect(blocks[1].text, 'Two');
    });

    test('bullets accept -, * and +', () {
      final blocks = parseMarkdownBlocks('- one\n* two\n+ three');
      expect(blocks.every((b) => b.type == MdBlockType.bullet), isTrue);
      expect(blocks.map((b) => b.text).toList(), ['one', 'two', 'three']);
    });

    test('numbered items keep their number', () {
      final blocks = parseMarkdownBlocks('1. first\n2) second\n10. tenth');
      expect(blocks.every((b) => b.type == MdBlockType.numbered), isTrue);
      expect(blocks.map((b) => b.level).toList(), [1, 2, 10]);
    });

    test('fenced code is kept verbatim, including blank lines', () {
      final blocks = parseMarkdownBlocks('text\n```\nline A\n\nline B\n```\nafter');
      expect(blocks[0].type, MdBlockType.paragraph);
      expect(blocks[1].type, MdBlockType.code);
      expect(blocks[1].text, 'line A\n\nline B');
      expect(blocks[2].text, 'after');
    });

    test('an unterminated fence still yields its content', () {
      // A streamed reply can be cut off mid-block; it must not vanish.
      final blocks = parseMarkdownBlocks('```\nhalf a block');
      expect(blocks.length, 1);
      expect(blocks.first.type, MdBlockType.code);
      expect(blocks.first.text, 'half a block');
    });

    test('markers inside a code fence are not parsed as markdown', () {
      final blocks = parseMarkdownBlocks('```\n# not a heading\n- not a bullet\n```');
      expect(blocks.length, 1);
      expect(blocks.first.type, MdBlockType.code);
      expect(blocks.first.text, '# not a heading\n- not a bullet');
    });

    test('quotes and rules are recognised', () {
      final blocks = parseMarkdownBlocks('> quoted\n\n---');
      expect(blocks[0].type, MdBlockType.quote);
      expect(blocks[0].text, 'quoted');
      expect(blocks[1].type, MdBlockType.rule);
    });

    test('empty input yields no blocks', () {
      expect(parseMarkdownBlocks(''), isEmpty);
      expect(parseMarkdownBlocks('   \n\n  '), isEmpty);
    });

    test('a realistic legal answer parses into the right shapes', () {
      const reply = '''
## Section 138 NI Act

The essentials are:

1. A cheque drawn on an account
2. Presented within **three months**

- Notice within 30 days
- Complaint within 30 days of cause of action

> See *Dashrath Rupsingh* on territorial jurisdiction.
''';
      final blocks = parseMarkdownBlocks(reply);
      final types = blocks.map((b) => b.type).toList();
      expect(types.first, MdBlockType.heading);
      expect(types.where((t) => t == MdBlockType.numbered).length, 2);
      expect(types.where((t) => t == MdBlockType.bullet).length, 2);
      expect(types.last, MdBlockType.quote);
      // Inline markers stay in the text; they are resolved at render time.
      expect(blocks[3].text, contains('**three months**'));
    });
  });
}
