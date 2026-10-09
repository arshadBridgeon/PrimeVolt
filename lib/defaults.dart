import 'models.dart';

// Every new quotation starts from this item list, notes and terms (taken from
// the company's standard solar quotation). Users then edit per quotation.

List<QuotationItem> defaultItems() => [
  QuotationItem(
    name: 'PV MODULE/SOLAR PANEL',
    description: 'WAAREE(TOPCON, Bifacial module, 610 w)',
    quantity: 5,
  ),
  QuotationItem(
    name: 'DISTRIBUTION BOXES(ACDB&DCDB)',
    description: 'HAVELLS/ABB\nSPD:Havells\nMCB:Havells\nFuse:Havells',
    quantity: 2,
  ),
  QuotationItem(
    name: 'ENERGY METER(SOLAR GENERATION METER)',
    description: 'L&T/HPL/GENUS(Single phase)',
  ),
  QuotationItem(
    name: 'CABLES(DC &AC)',
    description: 'DC cable & AC cable : 4mm(Polycab/finolex/Hpl)',
  ),
  QuotationItem(
    name: 'EARTHING',
    description:
        '14*1.2m 250microns Earth Rod(3 Nos).\nEarth compound:3Nos\n'
        'HD chamber:3nos\nCOPPER (10SWG)',
  ),
  QuotationItem(
    name: 'LIGHTNING ARRESTER',
    description: '16*1000mm multi spike\n50mm sq. mm Al. Down conductor',
  ),
  QuotationItem(
    name: 'STRUCTURE',
    description:
        'GP with Epoxy primer coated) flat roof\n'
        '📌if it is a terraced or sloped roof cost, for walkway, ladder, '
        'handrail etc.. will be charged extra',
  ),
  QuotationItem(name: 'METER BOX', description: 'single phase'),
  QuotationItem(name: '2 POLE ISOLATOR', description: 'Havells'),
  QuotationItem(
    name: 'ISI ELECTRIC CONDUITS (20LENGTH )',
    description: 'and pipe fittings',
  ),
  QuotationItem(name: 'EARTH BENCH', description: '4pole', quantity: 2),
  QuotationItem(
    name: 'WIRING MATERIALS',
    description: 'screw, tap, fisher.....',
  ),
  QuotationItem(name: 'CABLE TRAY', description: 'Square pipe'),
  QuotationItem(name: 'STRUCTURE END CAP'),
  QuotationItem(name: 'PAPER WORK', description: 'loan &Subsidy, kseb'),
  QuotationItem(name: 'FEASIBILITY CHARGE'),
  QuotationItem(name: 'MICRO INVERTER 3KW(DEYE/T SUN/FESTO)'),
  QuotationItem(name: 'STRUCTURE PAINT(PRIMER....)'),
];

const defaultNotes =
    'SOLAR PANEL:12 year product warranty against manufacturing defect. '
    '30 years performance warranty.📌\n'
    'INVERTER : 10 years manufacturer offer. 📌SERVICE :5years';

const defaultTerms =
    '📍PAYMENT TERMS.\n'
    'Upon the confirmation order : 50% of the project cost\n'
    'Upon the Delivery of materials : 30% of the project\n'
    'Upon the Completion of installation, T & C : 20% of the project\n'
    '\n'
    '📍OTHER CHARGES PAYABLE BY CLIENT.\n'
    'KSEB Deposit amount(80% Refundable)';

const defaultValidityDays = 15;
