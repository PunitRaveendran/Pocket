/// All user-facing copy. Keep it plain, specific, and a little dry.
class Copy {
  const Copy._();

  static const appName = 'Pocket';

  static const onboardingTitle1 = 'How much lands each month?';
  static const onboardingBody1 =
      'Hostel fees and rent stay out of this. This is the money you actually spend.';
  static const onboardingTitle2 = 'When does your month start?';
  static const onboardingBody2 =
      'Usually the day pocket money arrives. The daily number is this month split evenly.';
  static const onboardingTitle3 = 'Days and nights out stay apart.';
  static const onboardingBody3 =
      'Food, snacks, study and the rest come out of today. A trip or a night out is extra, on its own tab.';
  static const getStarted = 'Open the ledger';
  static const next = 'Next';
  static const back = 'Back';

  static const today = 'Today';
  static const splits = 'Splits';
  static const outings = 'Outings';
  static const insights = 'Insights';
  static const settings = 'Settings';

  static const leftToday = 'left today';
  static const overToday = 'over today';
  static const evenToday = 'today is even';
  static const allowanceOf = 'of';
  static const nothingYet = 'Nothing recorded yet.';
  static const addASpend = 'Add a spend';
  static const addSpend = 'Add spend';
  static const save = 'Save';
  static const remove = 'Remove';
  static const cancel = 'Cancel';

  static const food = 'Food';
  static const snacks = 'Snacks';
  static const study = 'Study';
  static const misc = 'Misc';
  static const all = 'All';
  static const addCategory = 'Add category';
  static const categoryName = 'Name';

  static const merchantHint = 'Where, if it matters';
  static const noteHint = 'Note';

  static const outingsLead =
      'Trips and nights out sit here. They do not change today’s number.';
  static const extraThisMonth = 'extra this month';
  static const noOutings = 'No extra spends yet.';
  static const addOuting = 'Add an outing';
  static const outingTitleHint = 'Night out, trip, concert…';
  static const outingTitle = 'What was it?';

  static const monthlyStipend = 'Monthly stipend';
  static const cycleStart = 'Month starts on';
  static const hideAmounts = 'Hide amounts';
  static const hideAmountsHint = 'Masks figures on Today and Outings.';
  static const categories = 'Categories';
  static const deleteAll = 'Delete all data';
  static const deleteAllBody =
      'This wipes the ledger on this phone. There is no cloud copy.';
  static const deleteConfirm = 'Wipe everything';

  static const privacyLine =
      'Everything stays on this phone. There is no account and no server.';

  static String morning(String amount) => "Today’s allowance is $amount.";

  static String usedOf(String spent, String allowance) =>
      '$spent of $allowance used';

  static String overBy(String amount) => '$amount over';

  static String leftOf(String left, String allowance) =>
      '$left of $allowance left';

  static String categoryTook(String name, String amount) =>
      '$name took $amount of it.';

  static String ordinaryVsExtra(String ordinary, String extra, String stipend) =>
      '$ordinary on ordinary days, $extra extra. Stipend is $stipend.';

  static String daysInCycle(int n) => '$n days in this cycle';
}
