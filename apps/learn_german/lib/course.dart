import 'package:flutter/material.dart';

/// One German word or phrase with meanings in the app's languages.
class Word {
  const Word(this.de, this.en, this.hi, this.gu);
  final String de;
  final String en;
  final String hi;
  final String gu;

  String meaning(String lang) => switch (lang) {
        'hi' => hi,
        'gu' => gu,
        _ => en,
      };

  /// der / die / das, used to colour nouns (a classic memory trick).
  String? get article {
    final first = de.split(' ').first;
    return const {'der', 'die', 'das'}.contains(first) ? first : null;
  }
}

class Unit {
  const Unit(this.id, this.icon, this.words);
  final String id;
  final IconData icon;
  final List<Word> words;
}

const articleColors = {
  'der': Color(0xFF2D5DA8),
  'die': Color(0xFFC8412F),
  'das': Color(0xFF2F7D4F),
};

const course = <Unit>[
  Unit('greetings', Icons.waving_hand_outlined, [
    Word('Hallo', 'Hello', 'नमस्ते', 'નમસ્તે'),
    Word('Guten Morgen', 'Good morning', 'सुप्रभात', 'સુપ્રભાત'),
    Word('Guten Tag', 'Good day / Hello', 'नमस्कार (दिन में)', 'નમસ્કાર (દિવસે)'),
    Word('Guten Abend', 'Good evening', 'शुभ संध्या', 'શુભ સાંજ'),
    Word('Gute Nacht', 'Good night', 'शुभ रात्रि', 'શુભ રાત્રિ'),
    Word('Tschüss', 'Bye', 'बाय', 'આવજો'),
    Word('Auf Wiedersehen', 'Goodbye', 'फिर मिलेंगे', 'ફરી મળીશું'),
    Word('Danke', 'Thank you', 'धन्यवाद', 'આભાર'),
    Word('Bitte', 'Please / You’re welcome', 'कृपया / कोई बात नहीं', 'કૃપા કરીને / કંઈ વાંધો નહીં'),
    Word('Entschuldigung', 'Excuse me / Sorry', 'माफ़ कीजिए', 'માફ કરશો'),
    Word('Ja', 'Yes', 'हाँ', 'હા'),
    Word('Nein', 'No', 'नहीं', 'ના'),
    Word('Wie geht’s?', 'How are you?', 'आप कैसे हैं?', 'તમે કેમ છો?'),
    Word('Mir geht’s gut', 'I am fine', 'मैं ठीक हूँ', 'હું મજામાં છું'),
    Word('Ich heiße …', 'My name is …', 'मेरा नाम … है', 'મારું નામ … છે'),
  ]),
  Unit('numbers', Icons.pin_outlined, [
    Word('eins', 'one', 'एक', 'એક'),
    Word('zwei', 'two', 'दो', 'બે'),
    Word('drei', 'three', 'तीन', 'ત્રણ'),
    Word('vier', 'four', 'चार', 'ચાર'),
    Word('fünf', 'five', 'पाँच', 'પાંચ'),
    Word('sechs', 'six', 'छह', 'છ'),
    Word('sieben', 'seven', 'सात', 'સાત'),
    Word('acht', 'eight', 'आठ', 'આઠ'),
    Word('neun', 'nine', 'नौ', 'નવ'),
    Word('zehn', 'ten', 'दस', 'દસ'),
    Word('zwanzig', 'twenty', 'बीस', 'વીસ'),
    Word('hundert', 'hundred', 'सौ', 'સો'),
  ]),
  Unit('family', Icons.family_restroom_outlined, [
    Word('die Mutter', 'mother', 'माँ', 'માતા'),
    Word('der Vater', 'father', 'पिता', 'પિતા'),
    Word('der Bruder', 'brother', 'भाई', 'ભાઈ'),
    Word('die Schwester', 'sister', 'बहन', 'બહેન'),
    Word('der Sohn', 'son', 'बेटा', 'દીકરો'),
    Word('die Tochter', 'daughter', 'बेटी', 'દીકરી'),
    Word('die Eltern', 'parents', 'माता-पिता', 'માતા-પિતા'),
    Word('der Großvater', 'grandfather', 'दादा / नाना', 'દાદા / નાના'),
    Word('die Großmutter', 'grandmother', 'दादी / नानी', 'દાદી / નાની'),
    Word('der Mann', 'man / husband', 'आदमी / पति', 'પુરુષ / પતિ'),
    Word('die Frau', 'woman / wife', 'औरत / पत्नी', 'સ્ત્રી / પત્ની'),
    Word('das Kind', 'child', 'बच्चा', 'બાળક'),
  ]),
  Unit('food', Icons.restaurant_outlined, [
    Word('das Wasser', 'water', 'पानी', 'પાણી'),
    Word('das Brot', 'bread', 'ब्रेड / रोटी', 'બ્રેડ / રોટલી'),
    Word('der Reis', 'rice', 'चावल', 'ભાત'),
    Word('die Milch', 'milk', 'दूध', 'દૂધ'),
    Word('der Tee', 'tea', 'चाय', 'ચા'),
    Word('der Kaffee', 'coffee', 'कॉफ़ी', 'કૉફી'),
    Word('das Gemüse', 'vegetables', 'सब्ज़ी', 'શાકભાજી'),
    Word('das Obst', 'fruit', 'फल', 'ફળ'),
    Word('der Apfel', 'apple', 'सेब', 'સફરજન'),
    Word('das Ei', 'egg', 'अंडा', 'ઈંડું'),
    Word('der Zucker', 'sugar', 'चीनी', 'ખાંડ'),
    Word('das Salz', 'salt', 'नमक', 'મીઠું'),
    Word('Ich bin Vegetarier', 'I am vegetarian', 'मैं शाकाहारी हूँ', 'હું શાકાહારી છું'),
  ]),
  Unit('verbs', Icons.directions_run_outlined, [
    Word('sein', 'to be', 'होना', 'હોવું'),
    Word('haben', 'to have', 'पास होना', 'પાસે હોવું'),
    Word('gehen', 'to go', 'जाना', 'જવું'),
    Word('kommen', 'to come', 'आना', 'આવવું'),
    Word('essen', 'to eat', 'खाना', 'ખાવું'),
    Word('trinken', 'to drink', 'पीना', 'પીવું'),
    Word('sprechen', 'to speak', 'बोलना', 'બોલવું'),
    Word('lernen', 'to learn', 'सीखना', 'શીખવું'),
    Word('arbeiten', 'to work', 'काम करना', 'કામ કરવું'),
    Word('wohnen', 'to live (reside)', 'रहना', 'રહેવું'),
    Word('schlafen', 'to sleep', 'सोना', 'સૂવું'),
    Word('kaufen', 'to buy', 'खरीदना', 'ખરીદવું'),
  ]),
  Unit('travel', Icons.train_outlined, [
    Word('der Bahnhof', 'railway station', 'रेलवे स्टेशन', 'રેલવે સ્ટેશન'),
    Word('der Zug', 'train', 'रेलगाड़ी', 'ટ્રેન'),
    Word('der Flughafen', 'airport', 'हवाई अड्डा', 'એરપોર્ટ'),
    Word('das Flugzeug', 'aeroplane', 'हवाई जहाज़', 'વિમાન'),
    Word('das Hotel', 'hotel', 'होटल', 'હોટેલ'),
    Word('die Straße', 'street', 'सड़क', 'રસ્તો'),
    Word('die Fahrkarte', 'ticket', 'टिकट', 'ટિકિટ'),
    Word('links', 'left', 'बाएँ', 'ડાબે'),
    Word('rechts', 'right', 'दाएँ', 'જમણે'),
    Word('geradeaus', 'straight ahead', 'सीधे', 'સીધા'),
    Word('Wo ist …?', 'Where is …?', '… कहाँ है?', '… ક્યાં છે?'),
    Word('Wie viel kostet das?', 'How much does this cost?', 'यह कितने का है?', 'આ કેટલાનું છે?'),
  ]),
  Unit('time', Icons.calendar_month_outlined, [
    Word('Montag', 'Monday', 'सोमवार', 'સોમવાર'),
    Word('Dienstag', 'Tuesday', 'मंगलवार', 'મંગળવાર'),
    Word('Mittwoch', 'Wednesday', 'बुधवार', 'બુધવાર'),
    Word('Donnerstag', 'Thursday', 'गुरुवार', 'ગુરુવાર'),
    Word('Freitag', 'Friday', 'शुक्रवार', 'શુક્રવાર'),
    Word('Samstag', 'Saturday', 'शनिवार', 'શનિવાર'),
    Word('Sonntag', 'Sunday', 'रविवार', 'રવિવાર'),
    Word('heute', 'today', 'आज', 'આજે'),
    Word('morgen', 'tomorrow', 'कल (आने वाला)', 'કાલે (આવતી)'),
    Word('gestern', 'yesterday', 'कल (बीता हुआ)', 'ગઈકાલે'),
    Word('die Woche', 'week', 'हफ़्ता', 'અઠવાડિયું'),
    Word('der Monat', 'month', 'महीना', 'મહિનો'),
  ]),
  Unit('abroad', Icons.school_outlined, [
    Word('die Universität', 'university', 'विश्वविद्यालय', 'યુનિવર્સિટી'),
    Word('der Student', 'student (male)', 'छात्र', 'વિદ્યાર્થી'),
    Word('die Arbeit', 'work / job', 'काम / नौकरी', 'કામ / નોકરી'),
    Word('das Büro', 'office', 'दफ़्तर', 'ઑફિસ'),
    Word('der Lebenslauf', 'CV / résumé', 'बायोडाटा', 'બાયોડેટા'),
    Word('die Bewerbung', 'job application', 'नौकरी का आवेदन', 'નોકરીની અરજી'),
    Word('das Visum', 'visa', 'वीज़ा', 'વિઝા'),
    Word('der Reisepass', 'passport', 'पासपोर्ट', 'પાસપોર્ટ'),
    Word('die Wohnung', 'flat / apartment', 'फ़्लैट', 'ફ્લેટ'),
    Word('die Miete', 'rent', 'किराया', 'ભાડું'),
    Word('die Versicherung', 'insurance', 'बीमा', 'વીમો'),
    Word('der Termin', 'appointment', 'अपॉइंटमेंट', 'એપોઇન્ટમેન્ટ'),
    Word('Ich verstehe nicht', 'I don’t understand', 'मुझे समझ नहीं आया', 'મને સમજાયું નહીં'),
    Word('Sprechen Sie Englisch?', 'Do you speak English?', 'क्या आप अंग्रेज़ी बोलते हैं?', 'શું તમે અંગ્રેજી બોલો છો?'),
  ]),
];
