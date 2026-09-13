//+------------------------------------------------------------------+
//|                                              AiTradingView.mq5   |
//|  v1.63: time-based profit close when hold exceeds limit          |
//+------------------------------------------------------------------+
#property copyright "AiTradingView"
#property link      ""
#property version   "1.63"
#property description "ปิดกำไรตามเวลาเมื่อถือเกินและยังกำไร"

#include <Trade/Trade.mqh>

enum ENUM_TRADE_MODE
{
   MODE_TREND = 0, // เทรนด์ (H1/H4)
   MODE_SCALP = 1  // สเกลป์ (M1/M5)
};

enum ENUM_SIGNAL
{
   SIGNAL_WAIT = 0,
   SIGNAL_BUY  = 1,
   SIGNAL_SELL = 2
};

enum ENUM_HTF_BIAS
{
   HTF_SIDE = 0,
   HTF_BULL = 1,
   HTF_BEAR = 2
};

enum ENUM_MTF_TF
{
   MTF_M5  = 0, // M5
   MTF_M15 = 1  // M15
};

//--- ทั่วไป
input group "=== ทั่วไป ==="
input ENUM_TRADE_MODE InpTradeMode       = MODE_SCALP; // โหมดเทรด
input bool            InpAutoTrade       = false;      // เปิดออเดอร์อัตโนมัติ
input ulong           InpMagic           = 20260912;   // หมายเลข Magic
input int             InpMaxSpreadPoints = 50;         // สเปรดสูงสุด (points)
input bool            InpAlertOnSignal   = true;       // แจ้งเตือนเมื่อมีสัญญาณใหม่
input bool            InpShowIndicators  = true;       // ติดอินดิเคเตอร์บนชาร์ต
input bool            InpManageManualOrders = true;    // ใส่ SL/TP ให้ออเดอร์มือ
input int             InpMaxAccountEaPositions = 2;    // ไม้สูงสุดของ EA ทั้งบัญชี (ทุกคู่)
input bool            InpJournalCsv            = true; // บันทึกไม้ปิดลง AITV_journal.csv

//--- MTF
input group "=== ยืนยันไทม์เฟรมสูง (เข้า M1) ==="
input bool         InpUseMtfFilter  = true;   // ต้องสอดคล้องทิศไทม์เฟรมสูง
input ENUM_MTF_TF  InpMtfTimeframe  = MTF_M5; // ไทม์เฟรมยืนยัน

//--- ความเสี่ยง / lot
input group "=== ความเสี่ยงและ Lot ==="
input double InpLot            = 0.01;  // Lot คงที่
input bool   InpUseRiskPercent = false; // คำนวณ lot จาก % ความเสี่ยง
input double InpRiskPercent    = 1.0;   // ความเสี่ยง % ของยอดเงิน

//--- ความเสี่ยงรายวัน
input group "=== ความเสี่ยงรายวัน ==="
input bool   InpUseDailyLossLimit   = true; // หยุดออโต้เมื่อขาดทุนรายวันเกิน
input double InpMaxDailyLossPercent = 3.0;  // ขาดทุนรายวันสูงสุด % ของยอดต้นวัน

//--- ความเสี่ยงรายสัปดาห์/เดือน
input group "=== ความเสี่ยงรายสัปดาห์/เดือน ==="
input bool   InpUseWeeklyLossLimit    = true;  // หยุดออโต้เมื่อ DD สัปดาห์เกิน
input double InpMaxWeeklyLossPercent  = 8.0;   // DD สัปดาห์สูงสุด % ของยอดต้นสัปดาห์
input bool   InpUseMonthlyLossLimit   = true;  // หยุดออโต้เมื่อ DD เดือนเกิน
input double InpMaxMonthlyLossPercent = 15.0;  // DD เดือนสูงสุด % ของยอดต้นเดือน

//--- วินัยกำไร/ขาดทุน
input group "=== วินัยกำไร/ขาดทุน (USD) ==="
input bool   InpUseDisciplineAlert   = true;  // เปิดแจ้งเตือนวินัย
input double InpDisciplineProfitUsd  = 10.0;  // เป้ากำไรต่อวันแล้วแจ้งเตือน (USD)
input double InpDisciplineLossUsd    = 10.0;  // เพดานขาดทุนต่อวันแล้วแจ้งเตือน (USD)
input bool   InpDisciplineStopAuto   = true;  // ถึงเกณฑ์แล้วหยุดเปิดออโต้ในวันนั้น

//--- ปิดกำไรตามเวลา
input group "=== ปิดกำไรตามเวลา ==="
input bool   InpUseTimeProfitClose  = true;  // เปิดปิดกำไรเมื่อถือนานเกินกำหนด
input int    InpTimeProfitMinutes   = 60;    // นาทีสูงสุดที่ถือถ้ายังกำไรแต่ไม่ถึง TP
input double InpTimeProfitMinUsd    = 0.50;  // กำไรลอยต่ำสุดถึงจะปิด (USD)
input bool   InpTimeProfitAlert     = true;  // Alert เมื่อปิดด้วยกฎนี้

//--- ออเดอร์ / BE
input group "=== ออเดอร์และ Breakeven ==="
input int    InpOrderRetries           = 2;    // ลองใหม่เมื่อ requote/timeout (ไม่ Sleep)
input int    InpOrderRetryMs           = 300;  // หน่วงระหว่าง retry (มิลลิวินาที)
input bool   InpUseBreakeven           = true; // เลื่อน SL ไปเบรกอีเวน
input double InpBreakevenTriggerR      = 1.0;  // เริ่มเมื่อกำไร >= R เท่าระยะ SL แรก
input int    InpBreakevenBufferPoints  = 20;   // บัฟเฟอร์ SL หลังจุดเข้า (points)

//--- ช่วงเวลาเทรด
input group "=== ช่วงเวลาเทรด ==="
input bool InpUseSessionFilter  = true; // เทรดเฉพาะในช่วงชั่วโมงที่ตั้ง
input int  InpSessionStartHour  = 12;   // ชั่วโมงเริ่ม (เวลาเซิร์ฟเวอร์)
input int  InpSessionEndHour    = 21;   // ชั่วโมงจบ (รวมชั่วโมงนี้)

//--- คูลดาวน์สัญญาณ
input group "=== คูลดาวน์สัญญาณ ==="
input int InpSignalCooldownBars = 5; // แท่งที่รอหลังสัญญาณ/เข้าไม้ ก่อนออโต้ใหม่

//--- SL / TP
input group "=== SL / TP ==="
input double InpSlAtrMult        = 1.0; // ตัวคูณ ATR สำหรับพื้น SL
input double InpRewardRatio      = 1.5; // TP = ระยะ SL คูณค่านี้
input double InpSwingSlBufferAtr = 0.1; // บัฟเฟอร์เกินสวิงสำหรับ SL
input int    InpAtrPeriod        = 14;  // คาบ ATR

//--- สวิง
input group "=== สวิง High / Low ==="
input bool InpShowSwingPoints = true;  // วาดกล่องสวิง + จุด pivot
input bool InpUseSwingFilter  = true;  // กรองเข้าไม้ด้วยสวิง
input int  InpSwingStrength   = 3;     // แท่งซ้าย/ขวาสำหรับ pivot
input int  InpSwingLookback   = 60;    // จำนวนแท่งที่สแกน

//--- ข่าว
input group "=== กันข่าว ==="
input bool InpUseNewsFilter         = true; // บล็อกออโต้ช่วงข่าว
input int  InpNewsMinutesBefore     = 30;   // นาทีก่อนข่าว
input int  InpNewsMinutesAfter      = 30;   // นาทีหลังข่าว
input bool InpNewsHighOnly          = true; // เฉพาะข่าวผลกระทบสูง
input bool InpNewsAlert             = true; // แจ้งเตือนเมื่อเข้าช่วงข่าว
input bool InpCryptoMajorNewsOnly   = true; // คริปโต: เฉพาะข่าว USD สำคัญ (NFP/CPI/FOMC...)

//--- อินดิเทรนด์
input group "=== โหมดเทรนด์ ==="
input int InpEmaFastTrend = 50;  // EMA เร็ว
input int InpEmaSlowTrend = 200; // EMA ช้า
input int InpRsiPeriod    = 14;  // คาบ RSI
input int InpRsiBuyMax    = 70;  // RSI สูงสุดสำหรับ Buy
input int InpRsiSellMin   = 30;  // RSI ต่ำสุดสำหรับ Sell
input int InpMacdFast     = 12;  // MACD เร็ว
input int InpMacdSlow     = 26;  // MACD ช้า
input int InpMacdSignal   = 9;   // MACD สัญญาณ

//--- อินดิสเกลป์
input group "=== โหมดสเกลป์ ==="
input int    InpEmaFastScalp = 9;     // EMA เร็ว
input int    InpEmaSlowScalp = 21;    // EMA ช้า
input int    InpStochK       = 5;     // Stochastic %K
input int    InpStochD       = 3;     // Stochastic %D
input int    InpStochSlowing = 3;     // Stochastic slowing
input double InpStochOversold   = 20.0; // โซนขายมากเกินไป
input double InpStochOverbought = 80.0; // โซนซื้อมากเกินไป

CTrade         g_trade;
int            g_atrHandle   = INVALID_HANDLE;
int            g_emaFastH    = INVALID_HANDLE;
int            g_emaSlowH    = INVALID_HANDLE;
int            g_rsiHandle   = INVALID_HANDLE;
int            g_macdHandle  = INVALID_HANDLE;
int            g_stochHandle = INVALID_HANDLE;
int            g_mtfEmaFastH = INVALID_HANDLE;
int            g_mtfEmaSlowH = INVALID_HANDLE;
datetime       g_lastBarTime = 0;
ENUM_SIGNAL    g_lastSignal  = SIGNAL_WAIT;
ENUM_SIGNAL    g_lastAlertSignal = SIGNAL_WAIT;
string         g_panelPrefix = "AITV_";
string         g_swingPrefix = "AITV_SW_";

string g_indNames[];
int    g_indWindows[];
int    g_indCount = 0;

double g_lastSwingHigh = 0.0;
double g_lastSwingLow  = 0.0;
bool   g_hasSwingHigh  = false;
bool   g_hasSwingLow   = false;
double g_drawnSwingHigh = 0.0;
double g_drawnSwingLow  = 0.0;
bool   g_swingDrawn     = false;

ulong  g_managedTickets[];
int    g_managedCount = 0;
bool   g_newsAlerted  = false;
string g_lastNewsTitle = "";
datetime g_lastNewsTime = 0;
double g_cachedAtr = 0.0;

double   g_dayStartBalance = 0.0;
long     g_dayKey = 0;
double   g_weekStartBalance = 0.0;
long     g_weekKey = 0;
double   g_monthStartBalance = 0.0;
long     g_monthKey = 0;
int      g_cooldownBarsLeft = 0;

// Async order retry (no Sleep)
// g_retryAttempt = completed attempts so far (0 before first fire)
bool     g_retryPending  = false;
bool     g_retryIsBuy    = true;
double   g_retryLot      = 0.0;
int      g_retryAttempt  = 0;
ulong    g_retryNextTick = 0;

string   g_lastBlockReason = "";
ulong    g_journalLastDeal = 0;

bool     g_disciplineProfitAlerted = false;
bool     g_disciplineLossAlerted   = false;
long     g_disciplineDayKey        = 0;
string   g_disciplineStatus        = "OFF";
double   g_disciplineDayNet        = 0.0;

//+------------------------------------------------------------------+
string GvPrefix()
{
   return "AITV_" + (string)AccountInfoInteger(ACCOUNT_LOGIN) + "_";
}

//+------------------------------------------------------------------+
string GvJournalLastDealName() { return GvPrefix() + "JournalLastDeal"; }

//+------------------------------------------------------------------+
string GvDayStampName()   { return GvPrefix() + "DayKey"; }
string GvDayBalName()     { return GvPrefix() + "DayBal"; }
string GvWeekStampName()  { return GvPrefix() + "WeekKey"; }
string GvWeekBalName()    { return GvPrefix() + "WeekBal"; }
string GvMonthStampName() { return GvPrefix() + "MonthKey"; }
string GvMonthBalName()   { return GvPrefix() + "MonthBal"; }

//+------------------------------------------------------------------+
void GvSetPair(const string keyName, const string balName, const long key, const double bal)
{
   GlobalVariableSet(keyName, (double)key);
   GlobalVariableSet(balName, bal);
   GlobalVariablesFlush();
}

//+------------------------------------------------------------------+
bool GvLoadPair(const string keyName, const string balName, const long expectKey,
                long &outKey, double &outBal)
{
   if(!GlobalVariableCheck(keyName) || !GlobalVariableCheck(balName))
      return false;
   long saved = (long)GlobalVariableGet(keyName);
   double bal = GlobalVariableGet(balName);
   if(saved != expectKey || bal <= 0.0)
      return false;
   outKey = saved;
   outBal = bal;
   return true;
}

//+------------------------------------------------------------------+
ENUM_TIMEFRAMES MtfPeriod()
{
   return (InpMtfTimeframe == MTF_M15) ? PERIOD_M15 : PERIOD_M5;
}

//+------------------------------------------------------------------+
string MtfName()
{
   return (InpMtfTimeframe == MTF_M15) ? "M15" : "M5";
}

//+------------------------------------------------------------------+
datetime DayStartServer(const datetime t)
{
   MqlDateTime dt;
   TimeToStruct(t, dt);
   dt.hour = 0;
   dt.min  = 0;
   dt.sec  = 0;
   return StructToTime(dt);
}

//+------------------------------------------------------------------+
datetime WeekStartServer(const datetime t)
{
   datetime day0 = DayStartServer(t);
   MqlDateTime dt;
   TimeToStruct(t, dt);
   int daysFromMonday = (dt.day_of_week == 0) ? 6 : (dt.day_of_week - 1);
   return day0 - (datetime)daysFromMonday * 86400;
}

//+------------------------------------------------------------------+
long CalendarDayKey(const datetime t)
{
   MqlDateTime dt;
   TimeToStruct(t, dt);
   return (long)dt.year * 10000L + (long)dt.mon * 100L + (long)dt.day;
}

//+------------------------------------------------------------------+
long CalendarWeekKey(const datetime t)
{
   return CalendarDayKey(WeekStartServer(t));
}

//+------------------------------------------------------------------+
long CalendarMonthKey(const datetime t)
{
   MqlDateTime dt;
   TimeToStruct(t, dt);
   return (long)dt.year * 100L + (long)dt.mon;
}

//+------------------------------------------------------------------+
double CurrentBalanceOrEquity()
{
   double bal = AccountInfoDouble(ACCOUNT_BALANCE);
   if(bal <= 0.0)
      bal = AccountInfoDouble(ACCOUNT_EQUITY);
   return bal;
}

//+------------------------------------------------------------------+
void EnsureDayState()
{
   long dayKey = CalendarDayKey(TimeTradeServer());
   if(GvLoadPair(GvDayStampName(), GvDayBalName(), dayKey, g_dayKey, g_dayStartBalance))
      return;
   g_dayKey = dayKey;
   g_dayStartBalance = CurrentBalanceOrEquity();
   GvSetPair(GvDayStampName(), GvDayBalName(), g_dayKey, g_dayStartBalance);
}

//+------------------------------------------------------------------+
void EnsureWeekState()
{
   long weekKey = CalendarWeekKey(TimeTradeServer());
   if(GvLoadPair(GvWeekStampName(), GvWeekBalName(), weekKey, g_weekKey, g_weekStartBalance))
      return;
   g_weekKey = weekKey;
   g_weekStartBalance = CurrentBalanceOrEquity();
   GvSetPair(GvWeekStampName(), GvWeekBalName(), g_weekKey, g_weekStartBalance);
}

//+------------------------------------------------------------------+
void EnsureMonthState()
{
   long monthKey = CalendarMonthKey(TimeTradeServer());
   if(GvLoadPair(GvMonthStampName(), GvMonthBalName(), monthKey, g_monthKey, g_monthStartBalance))
      return;
   g_monthKey = monthKey;
   g_monthStartBalance = CurrentBalanceOrEquity();
   GvSetPair(GvMonthStampName(), GvMonthBalName(), g_monthKey, g_monthStartBalance);
}

//+------------------------------------------------------------------+
void EnsureAllPeriodStates()
{
   EnsureDayState();
   EnsureWeekState();
   EnsureMonthState();
}

//+------------------------------------------------------------------+
double GetSymbolFloatingPnL()
{
   double pnl = 0.0;
   for(int i = PositionsTotal() - 1; i >= 0; i--)
   {
      ulong ticket = PositionGetTicket(i);
      if(ticket == 0 || !PositionSelectByTicket(ticket)) continue;
      if(PositionGetString(POSITION_SYMBOL) != _Symbol) continue;
      if((ulong)PositionGetInteger(POSITION_MAGIC) != InpMagic) continue;
      pnl += PositionGetDouble(POSITION_PROFIT);
      pnl += PositionGetDouble(POSITION_SWAP);
   }
   return pnl;
}

//+------------------------------------------------------------------+
double GetDailyClosedPnL()
{
   EnsureDayState();
   datetime from = DayStartServer(TimeTradeServer());
   datetime to   = TimeTradeServer() + 1;
   if(!HistorySelect(from, to))
      return 0.0;

   double pnl = 0.0;
   int total = HistoryDealsTotal();
   for(int i = 0; i < total; i++)
   {
      ulong ticket = HistoryDealGetTicket(i);
      if(ticket == 0) continue;
      if(HistoryDealGetString(ticket, DEAL_SYMBOL) != _Symbol) continue;
      long entry = HistoryDealGetInteger(ticket, DEAL_ENTRY);
      if(entry != DEAL_ENTRY_OUT && entry != DEAL_ENTRY_OUT_BY && entry != DEAL_ENTRY_INOUT)
         continue;
      if((ulong)HistoryDealGetInteger(ticket, DEAL_MAGIC) != InpMagic)
         continue;
      pnl += HistoryDealGetDouble(ticket, DEAL_PROFIT);
      pnl += HistoryDealGetDouble(ticket, DEAL_SWAP);
      pnl += HistoryDealGetDouble(ticket, DEAL_COMMISSION);
   }
   return pnl;
}

//+------------------------------------------------------------------+
bool IsDailyLossStopped(double &closedPnL, double &equityRisk)
{
   closedPnL = GetDailyClosedPnL();
   EnsureDayState();
   double equity = AccountInfoDouble(ACCOUNT_EQUITY);
   equityRisk = g_dayStartBalance - equity;
   if(!InpUseDailyLossLimit)
      return false;
   double limit = g_dayStartBalance * InpMaxDailyLossPercent / 100.0;
   if(limit <= 0.0)
      return false;
   double combined = closedPnL + GetSymbolFloatingPnL();
   if(combined <= -limit)
      return true;
   if(equityRisk >= limit)
      return true;
   return false;
}

//+------------------------------------------------------------------+
bool IsWeeklyLossStopped(double &weekEquityRisk)
{
   EnsureWeekState();
   weekEquityRisk = g_weekStartBalance - AccountInfoDouble(ACCOUNT_EQUITY);
   if(!InpUseWeeklyLossLimit)
      return false;
   double limit = g_weekStartBalance * InpMaxWeeklyLossPercent / 100.0;
   return (limit > 0.0 && weekEquityRisk >= limit);
}

//+------------------------------------------------------------------+
bool IsMonthlyLossStopped(double &monthEquityRisk)
{
   EnsureMonthState();
   monthEquityRisk = g_monthStartBalance - AccountInfoDouble(ACCOUNT_EQUITY);
   if(!InpUseMonthlyLossLimit)
      return false;
   double limit = g_monthStartBalance * InpMaxMonthlyLossPercent / 100.0;
   return (limit > 0.0 && monthEquityRisk >= limit);
}

//+------------------------------------------------------------------+
double GetDisciplineDayNet()
{
   return GetDailyClosedPnL() + GetSymbolFloatingPnL();
}

//+------------------------------------------------------------------+
void ResetDisciplineFlagsIfNewDay()
{
   EnsureDayState();
   if(g_disciplineDayKey != g_dayKey)
   {
      g_disciplineDayKey = g_dayKey;
      g_disciplineProfitAlerted = false;
      g_disciplineLossAlerted = false;
   }
}

//+------------------------------------------------------------------+
// Returns true if auto entries should stop for discipline today
bool CheckDisciplineLimits(string &status)
{
   status = "OFF";
   g_disciplineStatus = "OFF";
   g_disciplineDayNet = 0.0;
   if(!InpUseDisciplineAlert)
      return false;

   ResetDisciplineFlagsIfNewDay();
   double dayNet = GetDisciplineDayNet();
   g_disciplineDayNet = dayNet;

   double profitLimit = MathMax(0.0, InpDisciplineProfitUsd);
   double lossLimit   = MathMax(0.0, InpDisciplineLossUsd);

   bool profitHit = (profitLimit > 0.0 && dayNet >= profitLimit);
   bool lossHit   = (lossLimit > 0.0 && dayNet <= -lossLimit);

   if(profitHit && !g_disciplineProfitAlerted)
   {
      g_disciplineProfitAlerted = true;
      Alert("AiTradingView วินัย: กำไรวันนี้ถึง +",
            DoubleToString(dayNet, 2), " USD (เป้า ",
            DoubleToString(profitLimit, 2), ") — พักมือ อย่าโลภ");
      Print("Discipline profit hit: dayNet=", DoubleToString(dayNet, 2));
   }
   if(lossHit && !g_disciplineLossAlerted)
   {
      g_disciplineLossAlerted = true;
      Alert("AiTradingView วินัย: ขาดทุนวันนี้ถึง ",
            DoubleToString(dayNet, 2), " USD (เพดาน -",
            DoubleToString(lossLimit, 2), ") — หยุดขาดทุนต่อ");
      Print("Discipline loss hit: dayNet=", DoubleToString(dayNet, 2));
   }

   if(g_disciplineProfitAlerted)
   {
      status = "+HIT";
      g_disciplineStatus = "+HIT";
   }
   else if(g_disciplineLossAlerted)
   {
      status = "-HIT";
      g_disciplineStatus = "-HIT";
   }
   else
   {
      status = "OK";
      g_disciplineStatus = "OK";
   }

   if(!InpDisciplineStopAuto)
      return false;
   return (g_disciplineProfitAlerted || g_disciplineLossAlerted);
}

//+------------------------------------------------------------------+
bool IsDisciplineAutoBlocked()
{
   if(!InpUseDisciplineAlert || !InpDisciplineStopAuto)
      return false;
   return (g_disciplineProfitAlerted || g_disciplineLossAlerted);
}

//+------------------------------------------------------------------+
bool IsInSession()
{
   if(!InpUseSessionFilter)
      return true;
   MqlDateTime dt;
   TimeToStruct(TimeTradeServer(), dt);
   int h = dt.hour;
   int startH = MathMax(0, MathMin(23, InpSessionStartHour));
   int endH   = MathMax(0, MathMin(23, InpSessionEndHour));
   if(startH <= endH)
      return (h >= startH && h <= endH);
   // overnight window
   return (h >= startH || h <= endH);
}

//+------------------------------------------------------------------+
bool IsMajorUsdNewsName(const string name)
{
   string n = name;
   StringToUpper(n);
   if(StringFind(n, "NFP") >= 0) return true;
   if(StringFind(n, "NONFARM") >= 0) return true;
   if(StringFind(n, "NON-FARM") >= 0) return true;
   if(StringFind(n, "CPI") >= 0) return true;
   if(StringFind(n, "FOMC") >= 0) return true;
   if(StringFind(n, "INTEREST RATE") >= 0) return true;
   if(StringFind(n, "FED ") >= 0 || StringFind(n, "FEDERAL") >= 0) return true;
   if(StringFind(n, "POWELL") >= 0) return true;
   if(StringFind(n, "PAYROLL") >= 0) return true;
   return false;
}

//+------------------------------------------------------------------+
int OnInit()
{
   g_trade.SetExpertMagicNumber(InpMagic);
   g_trade.SetDeviationInPoints(20);
   g_trade.SetTypeFillingBySymbol(_Symbol);
   g_trade.SetAsyncMode(false);

   ArrayResize(g_indNames, 0);
   ArrayResize(g_indWindows, 0);
   ArrayResize(g_managedTickets, 0);
   g_indCount = 0;
   g_managedCount = 0;
   g_cooldownBarsLeft = 0;
   g_retryPending = false;
   g_retryAttempt = 0;
   g_lastBlockReason = "";
   g_journalLastDeal = 0;
   if(GlobalVariableCheck(GvJournalLastDealName()))
      g_journalLastDeal = (ulong)GlobalVariableGet(GvJournalLastDealName());
   EnsureAllPeriodStates();
   if(InpJournalCsv)
      JournalEnsureHeader();

   if(InpTradeMode == MODE_SCALP && _Period != PERIOD_M1 && _Period != PERIOD_M5)
      Print("Tip: Scalp mode works best on M1 (entry) with M5/M15 confirm. Current TF=", EnumToString(_Period));

   g_atrHandle = iATR(_Symbol, PERIOD_CURRENT, InpAtrPeriod);
   if(g_atrHandle == INVALID_HANDLE)
   {
      Print("Failed to create ATR handle");
      return INIT_FAILED;
   }

   if(InpTradeMode == MODE_TREND)
   {
      g_emaFastH   = iMA(_Symbol, PERIOD_CURRENT, InpEmaFastTrend, 0, MODE_EMA, PRICE_CLOSE);
      g_emaSlowH   = iMA(_Symbol, PERIOD_CURRENT, InpEmaSlowTrend, 0, MODE_EMA, PRICE_CLOSE);
      g_rsiHandle  = iRSI(_Symbol, PERIOD_CURRENT, InpRsiPeriod, PRICE_CLOSE);
      g_macdHandle = iMACD(_Symbol, PERIOD_CURRENT, InpMacdFast, InpMacdSlow, InpMacdSignal, PRICE_CLOSE);
      if(g_emaFastH == INVALID_HANDLE || g_emaSlowH == INVALID_HANDLE ||
         g_rsiHandle == INVALID_HANDLE || g_macdHandle == INVALID_HANDLE)
      {
         Print("Failed to create Trend indicator handles");
         return INIT_FAILED;
      }
   }
   else
   {
      g_emaFastH    = iMA(_Symbol, PERIOD_CURRENT, InpEmaFastScalp, 0, MODE_EMA, PRICE_CLOSE);
      g_emaSlowH    = iMA(_Symbol, PERIOD_CURRENT, InpEmaSlowScalp, 0, MODE_EMA, PRICE_CLOSE);
      g_stochHandle = iStochastic(_Symbol, PERIOD_CURRENT, InpStochK, InpStochD, InpStochSlowing, MODE_SMA, STO_LOWHIGH);
      if(g_emaFastH == INVALID_HANDLE || g_emaSlowH == INVALID_HANDLE || g_stochHandle == INVALID_HANDLE)
      {
         Print("Failed to create Scalp indicator handles");
         return INIT_FAILED;
      }
   }

   if(InpUseMtfFilter)
   {
      ENUM_TIMEFRAMES htf = MtfPeriod();
      int fastPeriod = (InpTradeMode == MODE_TREND) ? InpEmaFastTrend : InpEmaFastScalp;
      int slowPeriod = (InpTradeMode == MODE_TREND) ? InpEmaSlowTrend : InpEmaSlowScalp;
      g_mtfEmaFastH = iMA(_Symbol, htf, fastPeriod, 0, MODE_EMA, PRICE_CLOSE);
      g_mtfEmaSlowH = iMA(_Symbol, htf, slowPeriod, 0, MODE_EMA, PRICE_CLOSE);
      if(g_mtfEmaFastH == INVALID_HANDLE || g_mtfEmaSlowH == INVALID_HANDLE)
      {
         Print("Failed to create MTF EMA handles");
         return INIT_FAILED;
      }
   }

   if(InpShowIndicators)
      AttachIndicators();

   Comment("");
   UpdatePanelEx(SIGNAL_WAIT, "INIT", HTF_SIDE, false, "", true, true,
                 0.0, 0.0, 0.0, 0.0, false, 0.0, 0.0, 0.0, 0.0, 0.0);
   return INIT_SUCCEEDED;
}

//+------------------------------------------------------------------+
void OnDeinit(const int reason)
{
   DetachIndicators();
   DeleteSwingObjects();
   DeletePanel();

   if(g_atrHandle   != INVALID_HANDLE) IndicatorRelease(g_atrHandle);
   if(g_emaFastH    != INVALID_HANDLE) IndicatorRelease(g_emaFastH);
   if(g_emaSlowH    != INVALID_HANDLE) IndicatorRelease(g_emaSlowH);
   if(g_rsiHandle   != INVALID_HANDLE) IndicatorRelease(g_rsiHandle);
   if(g_macdHandle  != INVALID_HANDLE) IndicatorRelease(g_macdHandle);
   if(g_stochHandle != INVALID_HANDLE) IndicatorRelease(g_stochHandle);
   if(g_mtfEmaFastH != INVALID_HANDLE) IndicatorRelease(g_mtfEmaFastH);
   if(g_mtfEmaSlowH != INVALID_HANDLE) IndicatorRelease(g_mtfEmaSlowH);
   Comment("");
}

//+------------------------------------------------------------------+
void OnTick()
{
   if(InpManageManualOrders)
   {
      string permWhy = "";
      if(TradePermissionOk(permWhy))
      {
         double atrTick = g_cachedAtr;
         if(atrTick <= 0.0)
            GetBufferValue(g_atrHandle, 0, 1, atrTick);
         if(atrTick > 0.0)
            ManageOpenPositionsSlTp(atrTick);
      }
   }
   if(InpUseBreakeven)
   {
      string permWhy = "";
      if(TradePermissionOk(permWhy))
         ManageBreakeven();
   }
   if(InpUseTimeProfitClose)
   {
      string permWhy = "";
      if(TradePermissionOk(permWhy))
         ManageTimeProfitClose();
   }

   // Non-blocking order retries (recalc SL/TP from live prices)
   ProcessPendingRetry();
   RefreshAlgoBlockPanel();

   if(!IsNewBar())
      return;

   if(g_cooldownBarsLeft > 0)
      g_cooldownBarsLeft--;

   double atr = 0.0;
   if(!GetBufferValue(g_atrHandle, 0, 1, atr) || atr <= 0.0)
      return;
   g_cachedAtr = atr;

   ScanAndDrawSwings();

   ENUM_HTF_BIAS htfBias = HTF_SIDE;
   if(InpUseMtfFilter)
      htfBias = GetHtfBias();

   ENUM_SIGNAL rawSignal = SIGNAL_WAIT;
   string trendText = "WAIT";
   if(InpTradeMode == MODE_TREND)
      rawSignal = GetTrendSignal(trendText);
   else
      rawSignal = GetScalpSignal(trendText);

   ENUM_SIGNAL signal = rawSignal;
   if(InpUseSwingFilter && signal != SIGNAL_WAIT)
   {
      if(!PassSwingFilter(signal, atr))
         signal = SIGNAL_WAIT;
   }
   if(InpUseMtfFilter && signal != SIGNAL_WAIT)
   {
      if(signal == SIGNAL_BUY && htfBias != HTF_BULL)
         signal = SIGNAL_WAIT;
      if(signal == SIGNAL_SELL && htfBias != HTF_BEAR)
         signal = SIGNAL_WAIT;
   }

   string newsTitle = "";
   datetime newsTime = 0;
   bool inNews = false;
   if(InpUseNewsFilter)
      inNews = IsNewsDangerWindow(newsTitle, newsTime);

   bool inSession = IsInSession();
   bool marketOpen = IsMarketTradeable();
   double closedPnL = 0.0, equityRisk = 0.0, weekRisk = 0.0, monthRisk = 0.0;
   bool dailyStop = IsDailyLossStopped(closedPnL, equityRisk);
   bool weekStop = IsWeeklyLossStopped(weekRisk);
   bool monthStop = IsMonthlyLossStopped(monthRisk);
   bool riskStop = (dailyStop || weekStop || monthStop);

   string discStatus = "";
   bool disciplineStop = CheckDisciplineLimits(discStatus);

   string permReason = "";
   bool tradePermOk = TradePermissionOk(permReason);

   if(inNews)
   {
      if(InpNewsAlert && (!g_newsAlerted || newsTitle != g_lastNewsTitle))
      {
         Alert("AiTradingView NEWS window: ", newsTitle);
         g_newsAlerted = true;
         g_lastNewsTitle = newsTitle;
         g_lastNewsTime = newsTime;
      }
      signal = SIGNAL_WAIT;
   }
   else
      g_newsAlerted = false;

   if(!inSession)
      signal = SIGNAL_WAIT;
   if(!marketOpen)
      signal = SIGNAL_WAIT;

   double ask = SymbolInfoDouble(_Symbol, SYMBOL_ASK);
   double bid = SymbolInfoDouble(_Symbol, SYMBOL_BID);
   double slBuy = 0.0, tpBuy = 0.0, slSell = 0.0, tpSell = 0.0;
   bool okBuy  = CalcSmartSlTp(true,  ask, atr, slBuy,  tpBuy);
   bool okSell = CalcSmartSlTp(false, bid, atr, slSell, tpSell);

   double showSl = 0.0, showTp = 0.0;
   if(rawSignal == SIGNAL_BUY && okBuy) { showSl = slBuy; showTp = tpBuy; }
   else if(rawSignal == SIGNAL_SELL && okSell) { showSl = slSell; showTp = tpSell; }

   // Pre-set block reason for panel before attempting auto entry
   if(!InpAutoTrade)
      SetBlockReason("AutoTrade input OFF");
   else if(!tradePermOk)
      SetBlockReason(permReason);
   else if(disciplineStop)
      SetBlockReason(g_disciplineStatus == "+HIT" ? "discipline profit hit" : "discipline loss hit");
   else if(inNews)
      SetBlockReason(StringLen(newsTitle) > 0 ? ("news: " + newsTitle) : "news window");
   else if(!inSession)
      SetBlockReason("outside session");
   else if(!marketOpen)
      SetBlockReason("market closed");
   else if(riskStop)
      SetBlockReason("period risk stop");
   else if(g_cooldownBarsLeft > 0)
      SetBlockReason("cooldown " + IntegerToString(g_cooldownBarsLeft) + " bars");
   else if(g_retryPending)
      SetBlockReason("retry pending");
   else if(!SpreadOk())
      SetBlockReason("spread too high");
   else if(HasOpenPositionManaged())
      SetBlockReason("symbol already has EA position");
   else if(!AccountExposureOk())
      SetBlockReason("account EA position limit");
   else if(signal != SIGNAL_BUY && signal != SIGNAL_SELL)
      SetBlockReason("no actionable signal");
   else
      SetBlockReason("ready");

   UpdatePanelEx(signal, trendText, htfBias, inNews, newsTitle, inSession, marketOpen,
                 closedPnL, equityRisk, weekRisk, monthRisk, riskStop,
                 atr, showSl, showTp, g_lastSwingHigh, g_lastSwingLow);

   // Alert/arrow with debounce: only when actionable signal changes and not spamming same direction in cooldown
   if(signal == SIGNAL_BUY || signal == SIGNAL_SELL)
   {
      if(signal != g_lastAlertSignal)
      {
         DrawSignalArrow(signal);
         if(InpAlertOnSignal)
            Alert("AiTradingView ", SignalToText(signal), " ", _Symbol, " +", MtfName());
         g_lastAlertSignal = signal;
      }
      g_lastSignal = signal;
   }
   else
   {
      g_lastSignal = SIGNAL_WAIT;
   }

   if(!InpAutoTrade || !tradePermOk || disciplineStop || inNews || !inSession || riskStop || !marketOpen)
      return;

   if(g_cooldownBarsLeft > 0)
      return;

   if(g_retryPending)
      return;

   if(!SpreadOk())
   {
      Print("Skip order: spread too high");
      return;
   }
   if(HasOpenPositionManaged())
      return;
   if(!AccountExposureOk())
   {
      Print("Skip order: account EA position limit reached");
      return;
   }

   if(signal != SIGNAL_BUY && signal != SIGNAL_SELL)
      return;

   double lot = CalculateLot(atr, (signal == SIGNAL_BUY) ? MathAbs(ask - slBuy) : MathAbs(slSell - bid));
   lot = FitLotToMargin(lot, (signal == SIGNAL_BUY) ? ORDER_TYPE_BUY : ORDER_TYPE_SELL);
   if(lot <= 0.0)
   {
      SetBlockReason("lot/margin invalid");
      Print("Skip order: lot/margin invalid");
      return;
   }

   bool opened = false;
   if(signal == SIGNAL_BUY && okBuy)
      opened = SendOrderOnce(true, lot, slBuy, tpBuy, true);
   else if(signal == SIGNAL_SELL && okSell)
      opened = SendOrderOnce(false, lot, slSell, tpSell, true);
   else
   {
      SetBlockReason("SL/TP calc failed");
      return;
   }

   if(opened)
   {
      SetBlockReason("order opened");
      g_cooldownBarsLeft = MathMax(1, InpSignalCooldownBars);
   }
}

//+------------------------------------------------------------------+
bool IsNewBar()
{
   datetime t = iTime(_Symbol, PERIOD_CURRENT, 0);
   if(t == 0)
      return false;
   if(t == g_lastBarTime)
      return false;
   g_lastBarTime = t;
   return true;
}

//+------------------------------------------------------------------+
bool SpreadOk()
{
   return ((long)SymbolInfoInteger(_Symbol, SYMBOL_SPREAD) <= InpMaxSpreadPoints);
}

//+------------------------------------------------------------------+
bool GetBufferValue(const int handle, const int buffer, const int shift, double &outValue)
{
   double arr[];
   ArraySetAsSeries(arr, true);
   if(CopyBuffer(handle, buffer, shift, 1, arr) != 1)
      return false;
   outValue = arr[0];
   return true;
}

//+------------------------------------------------------------------+
ENUM_HTF_BIAS GetHtfBias()
{
   double emaF, emaS;
   if(!GetBufferValue(g_mtfEmaFastH, 0, 1, emaF) || !GetBufferValue(g_mtfEmaSlowH, 0, 1, emaS))
      return HTF_SIDE;
   double close1 = iClose(_Symbol, MtfPeriod(), 1);
   if(close1 > emaF && close1 > emaS && emaF > emaS) return HTF_BULL;
   if(close1 < emaF && close1 < emaS && emaF < emaS) return HTF_BEAR;
   return HTF_SIDE;
}

//+------------------------------------------------------------------+
string HtfToText(const ENUM_HTF_BIAS b)
{
   if(b == HTF_BULL) return "BULL";
   if(b == HTF_BEAR) return "BEAR";
   return "SIDE";
}

//+------------------------------------------------------------------+
void RememberIndicator(const int subwindow, const string name)
{
   int n = ArraySize(g_indNames);
   ArrayResize(g_indNames, n + 1);
   ArrayResize(g_indWindows, n + 1);
   g_indNames[n] = name;
   g_indWindows[n] = subwindow;
   g_indCount = n + 1;
}

//+------------------------------------------------------------------+
bool AddIndicatorToChart(const int handle, const int preferredWindow)
{
   if(handle == INVALID_HANDLE) return false;
   int window = preferredWindow;
   if(preferredWindow < 0)
      window = (int)ChartGetInteger(0, CHART_WINDOWS_TOTAL);
   if(!ChartIndicatorAdd(0, window, handle)) return false;
   int total = ChartIndicatorsTotal(0, window);
   if(total <= 0) return false;
   RememberIndicator(window, ChartIndicatorName(0, window, total - 1));
   return true;
}

//+------------------------------------------------------------------+
void AttachIndicators()
{
   AddIndicatorToChart(g_emaFastH, 0);
   AddIndicatorToChart(g_emaSlowH, 0);
   if(InpTradeMode == MODE_TREND)
   {
      AddIndicatorToChart(g_rsiHandle, -1);
      AddIndicatorToChart(g_macdHandle, -1);
   }
   else
      AddIndicatorToChart(g_stochHandle, -1);
   AddIndicatorToChart(g_atrHandle, -1);
   ChartRedraw(0);
}

//+------------------------------------------------------------------+
void DetachIndicators()
{
   for(int i = g_indCount - 1; i >= 0; i--)
      ChartIndicatorDelete(0, g_indWindows[i], g_indNames[i]);
   ArrayResize(g_indNames, 0);
   ArrayResize(g_indWindows, 0);
   g_indCount = 0;
}

//+------------------------------------------------------------------+
bool IsSwingHigh(const int shift, const int strength)
{
   double h = iHigh(_Symbol, PERIOD_CURRENT, shift);
   for(int k = 1; k <= strength; k++)
   {
      if(iHigh(_Symbol, PERIOD_CURRENT, shift + k) >= h) return false;
      if(iHigh(_Symbol, PERIOD_CURRENT, shift - k) > h)  return false;
   }
   return true;
}

//+------------------------------------------------------------------+
bool IsSwingLow(const int shift, const int strength)
{
   double l = iLow(_Symbol, PERIOD_CURRENT, shift);
   for(int k = 1; k <= strength; k++)
   {
      if(iLow(_Symbol, PERIOD_CURRENT, shift + k) <= l) return false;
      if(iLow(_Symbol, PERIOD_CURRENT, shift - k) < l)  return false;
   }
   return true;
}

//+------------------------------------------------------------------+
void DeleteSwingObjects()
{
   ObjectsDeleteAll(0, g_swingPrefix);
   g_swingDrawn = false;
}

//+------------------------------------------------------------------+
void EnsureSwingPivot(const string name, const datetime t, const double price, const color clr)
{
   if(ObjectFind(0, name) >= 0)
      return;
   if(!ObjectCreate(0, name, OBJ_ARROW, 0, t, price))
      return;
   ObjectSetInteger(0, name, OBJPROP_ARROWCODE, 159);
   ObjectSetInteger(0, name, OBJPROP_COLOR, clr);
   ObjectSetInteger(0, name, OBJPROP_WIDTH, 2);
   ObjectSetInteger(0, name, OBJPROP_SELECTABLE, false);
}

//+------------------------------------------------------------------+
void UpdateSwingBox(const datetime t1, const datetime t0, const double hi, const double lo)
{
   string box = g_swingPrefix + "BOX";
   if(ObjectFind(0, box) < 0)
   {
      if(!ObjectCreate(0, box, OBJ_RECTANGLE, 0, t1, hi, t0, lo))
         return;
      ObjectSetInteger(0, box, OBJPROP_COLOR, C'40,90,160');
      ObjectSetInteger(0, box, OBJPROP_STYLE, STYLE_SOLID);
      ObjectSetInteger(0, box, OBJPROP_WIDTH, 1);
      ObjectSetInteger(0, box, OBJPROP_FILL, true);
      ObjectSetInteger(0, box, OBJPROP_BACK, true);
      ObjectSetInteger(0, box, OBJPROP_SELECTABLE, false);
   }
   else
   {
      ObjectMove(0, box, 0, t1, hi);
      ObjectMove(0, box, 1, t0, lo);
   }
}

//+------------------------------------------------------------------+
void ScanAndDrawSwings()
{
   g_hasSwingHigh = false;
   g_hasSwingLow  = false;
   double newHigh = 0.0;
   double newLow  = 0.0;

   int strength = MathMax(1, InpSwingStrength);
   int lookback = MathMax(strength * 2 + 5, InpSwingLookback);
   int bars = Bars(_Symbol, PERIOD_CURRENT);
   if(bars < strength * 2 + 5)
      return;

   int maxShift = MathMin(lookback, bars - strength - 1);
   for(int shift = strength; shift <= maxShift; shift++)
   {
      if(IsSwingHigh(shift, strength))
      {
         double price = iHigh(_Symbol, PERIOD_CURRENT, shift);
         datetime t = iTime(_Symbol, PERIOD_CURRENT, shift);
         if(!g_hasSwingHigh)
         {
            newHigh = price;
            g_hasSwingHigh = true;
         }
         if(InpShowSwingPoints)
            EnsureSwingPivot(g_swingPrefix + "H_" + IntegerToString((int)t), t, price, clrOrangeRed);
      }
      if(IsSwingLow(shift, strength))
      {
         double price = iLow(_Symbol, PERIOD_CURRENT, shift);
         datetime t = iTime(_Symbol, PERIOD_CURRENT, shift);
         if(!g_hasSwingLow)
         {
            newLow = price;
            g_hasSwingLow = true;
         }
         if(InpShowSwingPoints)
            EnsureSwingPivot(g_swingPrefix + "L_" + IntegerToString((int)t), t, price, clrDodgerBlue);
      }
   }

   g_lastSwingHigh = newHigh;
   g_lastSwingLow  = newLow;

   if(!InpShowSwingPoints || !g_hasSwingHigh || !g_hasSwingLow)
      return;

   datetime t0 = iTime(_Symbol, PERIOD_CURRENT, 0);
   datetime t1 = iTime(_Symbol, PERIOD_CURRENT, MathMin(lookback, bars - 1));
   bool levelsChanged = (!g_swingDrawn ||
                         MathAbs(g_drawnSwingHigh - g_lastSwingHigh) > (_Point * 0.1) ||
                         MathAbs(g_drawnSwingLow - g_lastSwingLow) > (_Point * 0.1));
   if(levelsChanged || ObjectFind(0, g_swingPrefix + "BOX") < 0)
   {
      UpdateSwingBox(t1, t0, g_lastSwingHigh, g_lastSwingLow);
      g_drawnSwingHigh = g_lastSwingHigh;
      g_drawnSwingLow  = g_lastSwingLow;
      g_swingDrawn = true;
   }
   else
   {
      // stretch box to current bar without full redraw
      UpdateSwingBox(t1, t0, g_lastSwingHigh, g_lastSwingLow);
   }
}

//+------------------------------------------------------------------+
bool PassSwingFilter(const ENUM_SIGNAL signal, const double atr)
{
   double close1 = iClose(_Symbol, PERIOD_CURRENT, 1);
   double nearDist = atr * 0.3;
   if(signal == SIGNAL_BUY)
   {
      bool nearLow = g_hasSwingLow && (MathAbs(close1 - g_lastSwingLow) <= nearDist);
      bool breakHigh = g_hasSwingHigh && (close1 > g_lastSwingHigh);
      return (nearLow || breakHigh);
   }
   if(signal == SIGNAL_SELL)
   {
      bool nearHigh = g_hasSwingHigh && (MathAbs(close1 - g_lastSwingHigh) <= nearDist);
      bool breakLow = g_hasSwingLow && (close1 < g_lastSwingLow);
      return (nearHigh || breakLow);
   }
   return false;
}

//+------------------------------------------------------------------+
void GetSymbolCurrencies(string &baseCur, string &quoteCur)
{
   string sym = _Symbol;
   StringReplace(sym, "m", "");
   StringReplace(sym, ".", "");
   StringReplace(sym, "#", "");
   if(StringFind(sym, "XAU") == 0 || StringFind(sym, "GOLD") == 0)
   {
      baseCur = "XAU"; quoteCur = "USD"; return;
   }
   if(StringFind(sym, "BTC") == 0)
   {
      baseCur = "BTC"; quoteCur = "USD"; return;
   }
   if(StringFind(sym, "ETH") == 0)
   {
      baseCur = "ETH"; quoteCur = "USD"; return;
   }
   string base = SymbolInfoString(_Symbol, SYMBOL_CURRENCY_BASE);
   string quote = SymbolInfoString(_Symbol, SYMBOL_CURRENCY_PROFIT);
   if(StringLen(base) > 0 && StringLen(quote) > 0)
   {
      baseCur = base; quoteCur = quote; return;
   }
   if(StringLen(sym) >= 6)
   {
      baseCur = StringSubstr(sym, 0, 3);
      quoteCur = StringSubstr(sym, 3, 3);
   }
   else
   {
      baseCur = "USD";
      quoteCur = "USD";
   }
}

//+------------------------------------------------------------------+
bool CurrencyMatchesNews(const string newsCurrency, const string baseCur, const string quoteCur,
                         const string eventName)
{
   if(StringLen(newsCurrency) == 0)
      return false;

   bool crypto = (baseCur == "BTC" || baseCur == "ETH");
   if(crypto && newsCurrency == "USD" && InpCryptoMajorNewsOnly)
      return IsMajorUsdNewsName(eventName);

   if(newsCurrency == baseCur || newsCurrency == quoteCur)
      return true;

   // Gold still sensitive to most high-impact USD
   if(newsCurrency == "USD" && baseCur == "XAU")
      return true;

   return false;
}

//+------------------------------------------------------------------+
bool IsNewsDangerWindow(string &newsTitle, datetime &newsTime)
{
   newsTitle = "";
   newsTime = 0;

   datetime now = TimeTradeServer();
   datetime from = now - (datetime)InpNewsMinutesAfter * 60;
   datetime to   = now + (datetime)InpNewsMinutesBefore * 60;

   string baseCur, quoteCur;
   GetSymbolCurrencies(baseCur, quoteCur);

   MqlCalendarValue values[];
   int total = CalendarValueHistory(values, from, to, NULL, NULL);
   if(total <= 0)
      return false;

   for(int i = 0; i < total; i++)
   {
      MqlCalendarEvent event;
      if(!CalendarEventById(values[i].event_id, event))
         continue;

      if(InpNewsHighOnly)
      {
         if(event.importance != CALENDAR_IMPORTANCE_HIGH)
            continue;
      }
      else if(event.importance != CALENDAR_IMPORTANCE_HIGH &&
              event.importance != CALENDAR_IMPORTANCE_MODERATE)
         continue;

      MqlCalendarCountry country;
      if(!CalendarCountryById(event.country_id, country))
         continue;

      if(!CurrencyMatchesNews(country.currency, baseCur, quoteCur, event.name))
         continue;

      datetime evTime = values[i].time;
      datetime winStart = evTime - (datetime)InpNewsMinutesBefore * 60;
      datetime winEnd   = evTime + (datetime)InpNewsMinutesAfter * 60;
      if(now >= winStart && now <= winEnd)
      {
         newsTitle = event.name;
         newsTime = evTime;
         return true;
      }
   }
   return false;
}

//+------------------------------------------------------------------+
ENUM_SIGNAL GetTrendSignal(string &trendText)
{
   double emaF1, emaS1, rsi1, rsi2, macdMain1, macdSig1, macdMain2, macdSig2;
   double close1 = iClose(_Symbol, PERIOD_CURRENT, 1);
   if(!GetBufferValue(g_emaFastH, 0, 1, emaF1)) return SIGNAL_WAIT;
   if(!GetBufferValue(g_emaSlowH, 0, 1, emaS1)) return SIGNAL_WAIT;
   if(!GetBufferValue(g_rsiHandle, 0, 1, rsi1) || !GetBufferValue(g_rsiHandle, 0, 2, rsi2)) return SIGNAL_WAIT;
   if(!GetBufferValue(g_macdHandle, 0, 1, macdMain1) || !GetBufferValue(g_macdHandle, 1, 1, macdSig1)) return SIGNAL_WAIT;
   if(!GetBufferValue(g_macdHandle, 0, 2, macdMain2) || !GetBufferValue(g_macdHandle, 1, 2, macdSig2)) return SIGNAL_WAIT;

   bool bullTrend = (close1 > emaF1 && close1 > emaS1 && emaF1 > emaS1);
   bool bearTrend = (close1 < emaF1 && close1 < emaS1 && emaF1 < emaS1);
   trendText = bullTrend ? "BULL" : (bearTrend ? "BEAR" : "SIDE");
   bool macdBull = (macdMain1 > macdSig1) && (macdMain2 <= macdSig2 || macdMain1 > macdMain2);
   bool macdBear = (macdMain1 < macdSig1) && (macdMain2 >= macdSig2 || macdMain1 < macdMain2);
   bool rsiBuyOk  = (rsi1 < InpRsiBuyMax) && (rsi1 > 40.0) && (rsi1 >= rsi2);
   bool rsiSellOk = (rsi1 > InpRsiSellMin) && (rsi1 < 60.0) && (rsi1 <= rsi2);
   if(bullTrend && rsiBuyOk && macdBull) return SIGNAL_BUY;
   if(bearTrend && rsiSellOk && macdBear) return SIGNAL_SELL;
   return SIGNAL_WAIT;
}

//+------------------------------------------------------------------+
ENUM_SIGNAL GetScalpSignal(string &trendText)
{
   double emaF1, emaF2, emaS1, emaS2, k1, d1, k2, d2;
   double close1 = iClose(_Symbol, PERIOD_CURRENT, 1);
   if(!GetBufferValue(g_emaFastH, 0, 1, emaF1) || !GetBufferValue(g_emaFastH, 0, 2, emaF2)) return SIGNAL_WAIT;
   if(!GetBufferValue(g_emaSlowH, 0, 1, emaS1) || !GetBufferValue(g_emaSlowH, 0, 2, emaS2)) return SIGNAL_WAIT;
   if(!GetBufferValue(g_stochHandle, 0, 1, k1) || !GetBufferValue(g_stochHandle, 1, 1, d1)) return SIGNAL_WAIT;
   if(!GetBufferValue(g_stochHandle, 0, 2, k2) || !GetBufferValue(g_stochHandle, 1, 2, d2)) return SIGNAL_WAIT;

   bool bull = (emaF1 > emaS1 && close1 > emaF1);
   bool bear = (emaF1 < emaS1 && close1 < emaF1);
   trendText = bull ? "BULL" : (bear ? "BEAR" : "SIDE");
   bool emaCrossUp   = (emaF2 <= emaS2 && emaF1 > emaS1);
   bool emaCrossDown = (emaF2 >= emaS2 && emaF1 < emaS1);
   bool stochBuy  = (k2 <= d2 && k1 > d1) && (k1 < InpStochOverbought) && (k2 <= InpStochOversold + 15.0);
   bool stochSell = (k2 >= d2 && k1 < d1) && (k1 > InpStochOversold) && (k2 >= InpStochOverbought - 15.0);
   if(bull && (emaCrossUp || stochBuy) && k1 < InpStochOverbought) return SIGNAL_BUY;
   if(bear && (emaCrossDown || stochSell) && k1 > InpStochOversold) return SIGNAL_SELL;
   return SIGNAL_WAIT;
}

//+------------------------------------------------------------------+
double MinStopDistance()
{
   long stopsLevel = SymbolInfoInteger(_Symbol, SYMBOL_TRADE_STOPS_LEVEL);
   long freezeLevel = SymbolInfoInteger(_Symbol, SYMBOL_TRADE_FREEZE_LEVEL);
   double point = SymbolInfoDouble(_Symbol, SYMBOL_POINT);
   double dist = (double)MathMax(stopsLevel, freezeLevel) * point;
   if(dist <= 0.0) dist = point * 10.0;
   return dist;
}

//+------------------------------------------------------------------+
bool CalcSmartSlTp(const bool isBuy, const double price, const double atr,
                   double &sl, double &tp)
{
   int digits = (int)SymbolInfoInteger(_Symbol, SYMBOL_DIGITS);
   double buffer = atr * InpSwingSlBufferAtr;
   double atrSl  = atr * InpSlAtrMult;
   double minDist = MinStopDistance();

   if(isBuy)
   {
      double atrBased = price - atrSl;
      double swingBased = atrBased;
      if(g_hasSwingLow && g_lastSwingLow < price)
         swingBased = g_lastSwingLow - buffer;
      sl = MathMin(atrBased, swingBased);
      if(price - sl < minDist) sl = price - minDist;
      double slDist = price - sl;
      if(slDist <= 0.0) return false;
      tp = price + slDist * InpRewardRatio;
      if(g_hasSwingHigh && g_lastSwingHigh > price && (g_lastSwingHigh - price) >= slDist)
         tp = g_lastSwingHigh;
      if(tp - price < minDist) tp = price + minDist;
   }
   else
   {
      double atrBased = price + atrSl;
      double swingBased = atrBased;
      if(g_hasSwingHigh && g_lastSwingHigh > price)
         swingBased = g_lastSwingHigh + buffer;
      sl = MathMax(atrBased, swingBased);
      if(sl - price < minDist) sl = price + minDist;
      double slDist = sl - price;
      if(slDist <= 0.0) return false;
      tp = price - slDist * InpRewardRatio;
      if(g_hasSwingLow && g_lastSwingLow < price && (price - g_lastSwingLow) >= slDist)
         tp = g_lastSwingLow;
      if(price - tp < minDist) tp = price - minDist;
   }
   sl = NormalizeDouble(sl, digits);
   tp = NormalizeDouble(tp, digits);
   if(isBuy) return (sl < price && tp > price);
   return (sl > price && tp < price);
}

//+------------------------------------------------------------------+
bool WasManaged(const ulong ticket)
{
   for(int i = 0; i < g_managedCount; i++)
      if(g_managedTickets[i] == ticket) return true;
   return false;
}

//+------------------------------------------------------------------+
void MarkManaged(const ulong ticket)
{
   if(WasManaged(ticket)) return;
   ArrayResize(g_managedTickets, g_managedCount + 1);
   g_managedTickets[g_managedCount++] = ticket;
}

//+------------------------------------------------------------------+
void ManageOpenPositionsSlTp(const double atr)
{
   for(int i = PositionsTotal() - 1; i >= 0; i--)
   {
      ulong ticket = PositionGetTicket(i);
      if(ticket == 0 || !PositionSelectByTicket(ticket)) continue;
      if(PositionGetString(POSITION_SYMBOL) != _Symbol) continue;
      ulong magic = (ulong)PositionGetInteger(POSITION_MAGIC);
      if(magic != InpMagic && magic != 0) continue;

      double curSl = PositionGetDouble(POSITION_SL);
      double curTp = PositionGetDouble(POSITION_TP);
      if(curSl > 0.0 && curTp > 0.0)
      {
         MarkManaged(ticket);
         continue;
      }
      if(WasManaged(ticket)) continue;

      long type = PositionGetInteger(POSITION_TYPE);
      double ask = SymbolInfoDouble(_Symbol, SYMBOL_ASK);
      double bid = SymbolInfoDouble(_Symbol, SYMBOL_BID);
      double sl = 0.0, tp = 0.0;
      bool ok = (type == POSITION_TYPE_BUY)
                ? CalcSmartSlTp(true, ask, atr, sl, tp)
                : CalcSmartSlTp(false, bid, atr, sl, tp);
      if(!ok)
      {
         Print("Manual SL/TP calc failed for #", ticket);
         MarkManaged(ticket);
         continue;
      }
      if(curSl > 0.0) sl = curSl;
      if(curTp > 0.0) tp = curTp;
      if(!g_trade.PositionModify(ticket, sl, tp))
         Print("PositionModify failed #", ticket, " ", g_trade.ResultRetcodeDescription());
      else
      {
         Print("Set SL/TP on #", ticket, " SL=", sl, " TP=", tp);
         MarkManaged(ticket);
      }
   }
}

//+------------------------------------------------------------------+
//+------------------------------------------------------------------+
int VolumeDigits(const double step)
{
   if(step <= 0.0)
      return 2;
   int digits = 0;
   double s = step;
   while(digits < 8 && MathAbs(s - MathRound(s)) > 1e-8)
   {
      s *= 10.0;
      digits++;
   }
   return digits;
}

//+------------------------------------------------------------------+
double NormVolume(const double lot)
{
   double step = SymbolInfoDouble(_Symbol, SYMBOL_VOLUME_STEP);
   if(step <= 0.0) step = 0.01;
   return NormalizeDouble(lot, VolumeDigits(step));
}

//+------------------------------------------------------------------+
bool IsMarketTradeable()
{
   long mode = SymbolInfoInteger(_Symbol, SYMBOL_TRADE_MODE);
   return (mode == SYMBOL_TRADE_MODE_FULL);
}

//+------------------------------------------------------------------+
bool TradePermissionOk(string &reason)
{
   if(!TerminalInfoInteger(TERMINAL_TRADE_ALLOWED))
   {
      reason = "Algo Trading OFF (terminal)";
      return false;
   }
   if(!AccountInfoInteger(ACCOUNT_TRADE_ALLOWED))
   {
      reason = "Account trade not allowed";
      return false;
   }
   if(!MQLInfoInteger(MQL_TRADE_ALLOWED))
   {
      reason = "EA trade not allowed";
      return false;
   }
   reason = "";
   return true;
}

//+------------------------------------------------------------------+
string AlgoStatusText()
{
   if(!TerminalInfoInteger(TERMINAL_TRADE_ALLOWED))
      return "Algo: OFF (terminal)";
   if(!AccountInfoInteger(ACCOUNT_TRADE_ALLOWED))
      return "Algo: Account trade OFF";
   if(!MQLInfoInteger(MQL_TRADE_ALLOWED))
      return "Algo: EA trade OFF";
   return "Algo: ON";
}

//+------------------------------------------------------------------+
void SetBlockReason(const string reason)
{
   if(g_lastBlockReason == reason)
      return;
   g_lastBlockReason = reason;
   if(StringLen(reason) > 0 && reason != "ready" && reason != "order opened")
      Print("Block: ", reason);
}

//+------------------------------------------------------------------+
void EnsurePanelLabel(const string name, const int y)
{
   if(ObjectFind(0, name) < 0)
   {
      ObjectCreate(0, name, OBJ_LABEL, 0, 0, 0);
      ObjectSetInteger(0, name, OBJPROP_CORNER, CORNER_LEFT_UPPER);
      ObjectSetInteger(0, name, OBJPROP_XDISTANCE, 10);
      ObjectSetInteger(0, name, OBJPROP_SELECTABLE, false);
      ObjectSetString(0, name, OBJPROP_FONT, "Consolas");
      ObjectSetInteger(0, name, OBJPROP_FONTSIZE, 9);
   }
   ObjectSetInteger(0, name, OBJPROP_YDISTANCE, y);
}

//+------------------------------------------------------------------+
void RefreshAlgoBlockPanel()
{
   // Live lines (updated every tick) — after main panel 0..17
   string algoName = g_panelPrefix + "L18";
   string blockName = g_panelPrefix + "L19";
   EnsurePanelLabel(algoName, 14 + 18 * 13);
   EnsurePanelLabel(blockName, 14 + 19 * 13);

   string algo = AlgoStatusText();
   string block = "Block: " + (StringLen(g_lastBlockReason) > 0 ? g_lastBlockReason : "-");

   color algoColor = (algo == "Algo: ON") ? clrLime : clrTomato;
   ObjectSetInteger(0, algoName, OBJPROP_COLOR, algoColor);
   ObjectSetString(0, algoName, OBJPROP_TEXT, algo);

   color blockColor = clrSilver;
   if(g_lastBlockReason == "ready" || g_lastBlockReason == "order opened")
      blockColor = clrLime;
   else if(StringLen(g_lastBlockReason) > 0)
      blockColor = clrOrange;
   ObjectSetInteger(0, blockName, OBJPROP_COLOR, blockColor);
   ObjectSetString(0, blockName, OBJPROP_TEXT, block);
}

//+------------------------------------------------------------------+
string JournalFileName()
{
   return "AITV_journal.csv";
}

//+------------------------------------------------------------------+
bool JournalEnsureHeader()
{
   if(FileIsExist(JournalFileName(), FILE_COMMON))
      return true;
   int h = FileOpen(JournalFileName(), FILE_WRITE | FILE_CSV | FILE_ANSI | FILE_COMMON, ',');
   if(h == INVALID_HANDLE)
   {
      Print("Journal: cannot create ", JournalFileName(), " err=", GetLastError());
      return false;
   }
   FileWrite(h, "time", "symbol", "side", "volume", "price", "sl", "tp",
             "pnl", "swap", "commission", "comment", "magic", "deal");
   FileClose(h);
   return true;
}

//+------------------------------------------------------------------+
void JournalRememberDeal(const ulong deal)
{
   if(deal <= g_journalLastDeal)
      return;
   g_journalLastDeal = deal;
   GlobalVariableSet(GvJournalLastDealName(), (double)deal);
   GlobalVariablesFlush();
}

//+------------------------------------------------------------------+
void JournalAppendClosedDeal(const ulong deal)
{
   if(!InpJournalCsv || deal == 0)
      return;
   if(deal <= g_journalLastDeal)
      return;

   if(!HistorySelect(TimeCurrent() - 86400 * 14, TimeCurrent() + 60))
      return;

   long magic = HistoryDealGetInteger(deal, DEAL_MAGIC);
   if((ulong)magic != InpMagic)
      return;

   long entry = HistoryDealGetInteger(deal, DEAL_ENTRY);
   if(entry != DEAL_ENTRY_OUT && entry != DEAL_ENTRY_OUT_BY && entry != DEAL_ENTRY_INOUT)
      return;

   long dtype = HistoryDealGetInteger(deal, DEAL_TYPE);
   if(dtype != DEAL_TYPE_BUY && dtype != DEAL_TYPE_SELL)
      return;

   if(!JournalEnsureHeader())
      return;

   datetime t = (datetime)HistoryDealGetInteger(deal, DEAL_TIME);
   string sym = HistoryDealGetString(deal, DEAL_SYMBOL);
   string side = (dtype == DEAL_TYPE_BUY) ? "BUY" : "SELL";
   double vol = HistoryDealGetDouble(deal, DEAL_VOLUME);
   double price = HistoryDealGetDouble(deal, DEAL_PRICE);
   double pnl = HistoryDealGetDouble(deal, DEAL_PROFIT);
   double swap = HistoryDealGetDouble(deal, DEAL_SWAP);
   double commission = HistoryDealGetDouble(deal, DEAL_COMMISSION);
   string comment = HistoryDealGetString(deal, DEAL_COMMENT);
   StringReplace(comment, ",", ";");
   double sl = HistoryDealGetDouble(deal, DEAL_SL);
   double tp = HistoryDealGetDouble(deal, DEAL_TP);
   int digits = (int)SymbolInfoInteger(sym, SYMBOL_DIGITS);
   if(digits <= 0)
      digits = _Digits;

   int h = FileOpen(JournalFileName(), FILE_READ | FILE_WRITE | FILE_CSV | FILE_ANSI | FILE_COMMON, ',');
   if(h == INVALID_HANDLE)
   {
      Print("Journal: cannot open ", JournalFileName(), " err=", GetLastError());
      return;
   }
   FileSeek(h, 0, SEEK_END);
   FileWrite(h,
             TimeToString(t, TIME_DATE | TIME_SECONDS),
             sym,
             side,
             DoubleToString(vol, 2),
             DoubleToString(price, digits),
             DoubleToString(sl, digits),
             DoubleToString(tp, digits),
             DoubleToString(pnl, 2),
             DoubleToString(swap, 2),
             DoubleToString(commission, 2),
             comment,
             IntegerToString(magic),
             IntegerToString((long)deal));
   FileClose(h);
   JournalRememberDeal(deal);
   Print("Journal: appended deal #", deal, " ", sym, " pnl=", DoubleToString(pnl, 2));
}

//+------------------------------------------------------------------+
void OnTradeTransaction(const MqlTradeTransaction &trans,
                        const MqlTradeRequest &request,
                        const MqlTradeResult &result)
{
   if(trans.type != TRADE_TRANSACTION_DEAL_ADD)
      return;
   if(trans.deal == 0)
      return;
   JournalAppendClosedDeal(trans.deal);
}

//+------------------------------------------------------------------+
bool IsRetriableRetcode(const uint retcode)
{
   return (retcode == TRADE_RETCODE_REQUOTE ||
           retcode == TRADE_RETCODE_PRICE_OFF ||
           retcode == TRADE_RETCODE_TIMEOUT ||
           retcode == TRADE_RETCODE_CONNECTION ||
           retcode == TRADE_RETCODE_PRICE_CHANGED ||
           retcode == TRADE_RETCODE_TOO_MANY_REQUESTS);
}

//+------------------------------------------------------------------+
void ManageBreakeven()
{
   if(!InpUseBreakeven)
      return;
   double point = SymbolInfoDouble(_Symbol, SYMBOL_POINT);
   if(point <= 0.0) return;
   double buffer = InpBreakevenBufferPoints * point;
   int digits = (int)SymbolInfoInteger(_Symbol, SYMBOL_DIGITS);

   for(int i = PositionsTotal() - 1; i >= 0; i--)
   {
      ulong ticket = PositionGetTicket(i);
      if(ticket == 0 || !PositionSelectByTicket(ticket)) continue;
      if(PositionGetString(POSITION_SYMBOL) != _Symbol) continue;
      if((ulong)PositionGetInteger(POSITION_MAGIC) != InpMagic) continue;

      double openPrice = PositionGetDouble(POSITION_PRICE_OPEN);
      double sl = PositionGetDouble(POSITION_SL);
      double tp = PositionGetDouble(POSITION_TP);
      long type = PositionGetInteger(POSITION_TYPE);
      if(sl <= 0.0) continue;

      double slDist = MathAbs(openPrice - sl);
      if(slDist <= 0.0) continue;

      double bid = SymbolInfoDouble(_Symbol, SYMBOL_BID);
      double ask = SymbolInfoDouble(_Symbol, SYMBOL_ASK);

      if(type == POSITION_TYPE_BUY)
      {
         double profitDist = bid - openPrice;
         if(profitDist < InpBreakevenTriggerR * slDist)
            continue;
         double newSl = NormalizeDouble(openPrice + buffer, digits);
         if(newSl <= sl || newSl >= bid)
            continue;
         if(!g_trade.PositionModify(ticket, newSl, tp))
            Print("Breakeven modify failed #", ticket, " ", g_trade.ResultRetcodeDescription());
         else
            Print("Breakeven set #", ticket, " SL=", newSl);
      }
      else if(type == POSITION_TYPE_SELL)
      {
         double profitDist = openPrice - ask;
         if(profitDist < InpBreakevenTriggerR * slDist)
            continue;
         double newSl = NormalizeDouble(openPrice - buffer, digits);
         if(newSl >= sl || newSl <= ask)
            continue;
         if(!g_trade.PositionModify(ticket, newSl, tp))
            Print("Breakeven modify failed #", ticket, " ", g_trade.ResultRetcodeDescription());
         else
            Print("Breakeven set #", ticket, " SL=", newSl);
      }
   }
}

//+------------------------------------------------------------------+
void ManageTimeProfitClose()
{
   if(!InpUseTimeProfitClose)
      return;

   int maxMinutes = MathMax(1, InpTimeProfitMinutes);
   double minProfit = MathMax(0.0, InpTimeProfitMinUsd);
   datetime now = TimeCurrent();

   for(int i = PositionsTotal() - 1; i >= 0; i--)
   {
      ulong ticket = PositionGetTicket(i);
      if(ticket == 0 || !PositionSelectByTicket(ticket)) continue;
      if(PositionGetString(POSITION_SYMBOL) != _Symbol) continue;
      if((ulong)PositionGetInteger(POSITION_MAGIC) != InpMagic) continue;

      datetime openTime = (datetime)PositionGetInteger(POSITION_TIME);
      if(openTime <= 0) continue;
      int ageSec = (int)(now - openTime);
      if(ageSec < maxMinutes * 60)
         continue;

      double floating = PositionGetDouble(POSITION_PROFIT) + PositionGetDouble(POSITION_SWAP);
      if(floating < minProfit)
         continue;

      double vol = PositionGetDouble(POSITION_VOLUME);
      if(!g_trade.PositionClose(ticket))
      {
         Print("TimeProfit close failed #", ticket, " ", g_trade.ResultRetcodeDescription());
         continue;
      }

      string msg = "TimeProfit close #" + IntegerToString((long)ticket) +
                   " age=" + IntegerToString(ageSec / 60) + "m" +
                   " pnl=" + DoubleToString(floating, 2) +
                   " lot=" + DoubleToString(vol, 2);
      Print(msg);
      if(InpTimeProfitAlert)
         Alert("AiTradingView ", msg);
   }
}

//+------------------------------------------------------------------+
double FitLotToMargin(double lot, const ENUM_ORDER_TYPE orderType)
{
   double minLot  = SymbolInfoDouble(_Symbol, SYMBOL_VOLUME_MIN);
   double stepLot = SymbolInfoDouble(_Symbol, SYMBOL_VOLUME_STEP);
   if(stepLot <= 0.0) stepLot = minLot;
   lot = NormVolume(lot);
   if(lot < minLot) return 0.0;

   double freeMargin = AccountInfoDouble(ACCOUNT_MARGIN_FREE);
   double price = (orderType == ORDER_TYPE_BUY)
                  ? SymbolInfoDouble(_Symbol, SYMBOL_ASK)
                  : SymbolInfoDouble(_Symbol, SYMBOL_BID);

   for(int guard = 0; guard < 80; guard++)
   {
      double margin = 0.0;
      if(!OrderCalcMargin(orderType, _Symbol, lot, price, margin))
      {
         lot = NormVolume(lot - stepLot);
         if(lot < minLot) return 0.0;
         continue;
      }
      if(margin <= freeMargin * 0.95)
         return NormVolume(lot);
      lot = NormVolume(lot - stepLot);
      if(lot < minLot)
         return 0.0;
   }
   return 0.0;
}

//+------------------------------------------------------------------+
double CalculateLot(const double atr, const double slDistance)
{
   double lot = InpLot;
   double minLot  = SymbolInfoDouble(_Symbol, SYMBOL_VOLUME_MIN);
   double maxLot  = SymbolInfoDouble(_Symbol, SYMBOL_VOLUME_MAX);
   double stepLot = SymbolInfoDouble(_Symbol, SYMBOL_VOLUME_STEP);
   double slDist = (slDistance > 0.0) ? slDistance : atr * InpSlAtrMult;

   if(InpUseRiskPercent)
   {
      double balance = AccountInfoDouble(ACCOUNT_BALANCE);
      double riskMoney = balance * InpRiskPercent / 100.0;
      double tickSize  = SymbolInfoDouble(_Symbol, SYMBOL_TRADE_TICK_SIZE);
      double tickValue = SymbolInfoDouble(_Symbol, SYMBOL_TRADE_TICK_VALUE);
      if(tickSize > 0.0 && tickValue > 0.0 && slDist > 0.0)
      {
         double lossPerLot = (slDist / tickSize) * tickValue;
         if(lossPerLot > 0.0)
            lot = riskMoney / lossPerLot;
      }
   }
   if(stepLot > 0.0)
      lot = MathFloor(lot / stepLot) * stepLot;
   lot = MathMax(minLot, MathMin(maxLot, lot));
   return NormVolume(lot);
}

//+------------------------------------------------------------------+
bool HasOpenPositionManaged()
{
   for(int i = PositionsTotal() - 1; i >= 0; i--)
   {
      ulong ticket = PositionGetTicket(i);
      if(ticket == 0 || !PositionSelectByTicket(ticket)) continue;
      if(PositionGetString(POSITION_SYMBOL) != _Symbol) continue;
      if((ulong)PositionGetInteger(POSITION_MAGIC) == InpMagic)
         return true;
   }
   return false;
}

//+------------------------------------------------------------------+
int CountAccountEaPositions()
{
   int count = 0;
   for(int i = PositionsTotal() - 1; i >= 0; i--)
   {
      ulong ticket = PositionGetTicket(i);
      if(ticket == 0 || !PositionSelectByTicket(ticket)) continue;
      if((ulong)PositionGetInteger(POSITION_MAGIC) == InpMagic)
         count++;
   }
   return count;
}

//+------------------------------------------------------------------+
bool AccountExposureOk()
{
   int maxPos = MathMax(1, InpMaxAccountEaPositions);
   return (CountAccountEaPositions() < maxPos);
}

//+------------------------------------------------------------------+
bool RetryDirectionStillValid(const bool isBuy)
{
   if(!InpUseMtfFilter || g_mtfEmaFastH == INVALID_HANDLE || g_mtfEmaSlowH == INVALID_HANDLE)
      return true;
   ENUM_HTF_BIAS bias = GetHtfBias();
   if(isBuy && bias == HTF_BEAR)
      return false;
   if(!isBuy && bias == HTF_BULL)
      return false;
   return true;
}

//+------------------------------------------------------------------+
bool RetryGuardsPass(string &reason)
{
   reason = "";
   if(!InpAutoTrade)
   {
      reason = "AutoTrade off";
      return false;
   }
   if(!TradePermissionOk(reason))
      return false;
   if(!IsMarketTradeable())
   {
      reason = "market not tradeable";
      return false;
   }
   if(!IsInSession())
   {
      reason = "outside session";
      return false;
   }
   if(!SpreadOk())
   {
      reason = "spread too high";
      return false;
   }
   if(HasOpenPositionManaged())
   {
      reason = "symbol already has EA position";
      return false;
   }
   if(!AccountExposureOk())
   {
      reason = "account EA position limit";
      return false;
   }

   string newsTitle = "";
   datetime newsTime = 0;
   if(InpUseNewsFilter && IsNewsDangerWindow(newsTitle, newsTime))
   {
      reason = "news window: " + newsTitle;
      return false;
   }

   double closedPnL = 0.0, equityRisk = 0.0, weekRisk = 0.0, monthRisk = 0.0;
   if(IsDailyLossStopped(closedPnL, equityRisk) ||
      IsWeeklyLossStopped(weekRisk) ||
      IsMonthlyLossStopped(monthRisk))
   {
      reason = "period risk stop";
      return false;
   }

   // Refresh discipline without relying on last bar only
   string discSt = "";
   if(CheckDisciplineLimits(discSt) || IsDisciplineAutoBlocked())
   {
      reason = "discipline limit hit";
      return false;
   }

   if(!RetryDirectionStillValid(g_retryIsBuy))
   {
      reason = "HTF direction flipped against retry side";
      return false;
   }
   return true;
}

//+------------------------------------------------------------------+
void ClearRetry()
{
   g_retryPending = false;
   g_retryAttempt = 0;
   g_retryLot = 0.0;
   g_retryNextTick = 0;
}

//+------------------------------------------------------------------+
void ScheduleRetry(const bool isBuy, const double lot, const int attemptsCompleted)
{
   int maxAttempts = MathMax(1, InpOrderRetries + 1);
   if(attemptsCompleted >= maxAttempts)
   {
      ClearRetry();
      return;
   }
   g_retryPending = true;
   g_retryIsBuy = isBuy;
   g_retryLot = lot;
   g_retryAttempt = attemptsCompleted; // completed so far; next fire is attemptsCompleted+1
   g_retryNextTick = GetTickCount() + (ulong)MathMax(50, InpOrderRetryMs);
}

//+------------------------------------------------------------------+
bool SendOrderOnce(const bool isBuy, const double lot, const double sl, const double tp,
                   const bool allowScheduleRetry)
{
   if(sl <= 0.0 || tp <= 0.0)
   {
      SetBlockReason("invalid SL/TP");
      Print(isBuy ? "Buy" : "Sell", " skipped: invalid SL/TP");
      return false;
   }

   string permWhy = "";
   if(!TradePermissionOk(permWhy))
   {
      SetBlockReason(permWhy);
      Print(isBuy ? "Buy" : "Sell", " skipped: ", permWhy);
      ClearRetry(); // permission off — do not retry
      return false;
   }

   int maxN = MathMax(1, InpOrderRetries + 1);
   int thisAttempt = g_retryAttempt + 1;
   string kind = (g_retryAttempt == 0) ? "initial" : "retry";

   bool ok = isBuy
             ? g_trade.Buy(lot, _Symbol, 0.0, sl, tp, "AiTradingView BUY")
             : g_trade.Sell(lot, _Symbol, 0.0, sl, tp, "AiTradingView SELL");
   if(ok)
   {
      Print(isBuy ? "Buy" : "Sell", " opened lot=", lot, " SL=", sl, " TP=", tp,
            " attempt ", thisAttempt, "/", maxN, " (", kind, ")");
      ClearRetry();
      return true;
   }

   uint rc = g_trade.ResultRetcode();
   SetBlockReason("order fail: " + g_trade.ResultRetcodeDescription());
   Print(isBuy ? "Buy" : "Sell", " failed attempt ", thisAttempt, "/", maxN, " (", kind, "): ",
         g_trade.ResultRetcodeDescription());
   if(allowScheduleRetry && IsRetriableRetcode(rc))
      ScheduleRetry(isBuy, lot, thisAttempt);
   else
      ClearRetry();
   return false;
}

//+------------------------------------------------------------------+
void ProcessPendingRetry()
{
   if(!g_retryPending)
      return;
   if(GetTickCount() < g_retryNextTick)
      return;

   string why = "";
   if(!RetryGuardsPass(why))
   {
      SetBlockReason("retry cancelled: " + why);
      Print("Retry cancelled: ", why);
      ClearRetry();
      return;
   }

   double atr = g_cachedAtr;
   if(atr <= 0.0 && !GetBufferValue(g_atrHandle, 0, 1, atr))
   {
      ScheduleRetry(g_retryIsBuy, g_retryLot, g_retryAttempt + 1);
      return;
   }

   double ask = SymbolInfoDouble(_Symbol, SYMBOL_ASK);
   double bid = SymbolInfoDouble(_Symbol, SYMBOL_BID);
   double sl = 0.0, tp = 0.0;
   bool okLevels = g_retryIsBuy ? CalcSmartSlTp(true, ask, atr, sl, tp)
                                : CalcSmartSlTp(false, bid, atr, sl, tp);
   if(!okLevels)
   {
      Print("Retry skipped: could not rebuild SL/TP from live price");
      ScheduleRetry(g_retryIsBuy, g_retryLot, g_retryAttempt + 1);
      return;
   }

   double lot = FitLotToMargin(g_retryLot, g_retryIsBuy ? ORDER_TYPE_BUY : ORDER_TYPE_SELL);
   if(lot <= 0.0)
   {
      SetBlockReason("retry aborted: margin/lot invalid");
      Print("Retry aborted: margin/lot invalid");
      ClearRetry();
      return;
   }

   if(SendOrderOnce(g_retryIsBuy, lot, sl, tp, true))
   {
      SetBlockReason("order opened");
      g_cooldownBarsLeft = MathMax(1, InpSignalCooldownBars);
   }
}

//+------------------------------------------------------------------+
string SignalToText(const ENUM_SIGNAL s)
{
   if(s == SIGNAL_BUY) return "BUY";
   if(s == SIGNAL_SELL) return "SELL";
   return "WAIT";
}

//+------------------------------------------------------------------+
void DrawSignalArrow(const ENUM_SIGNAL signal)
{
   string name = g_panelPrefix + "ARROW_" + IntegerToString((int)iTime(_Symbol, PERIOD_CURRENT, 1));
   double price = (signal == SIGNAL_BUY) ? iLow(_Symbol, PERIOD_CURRENT, 1) : iHigh(_Symbol, PERIOD_CURRENT, 1);
   datetime t = iTime(_Symbol, PERIOD_CURRENT, 1);
   ObjectDelete(0, name);
   if(!ObjectCreate(0, name, OBJ_ARROW, 0, t, price)) return;
   ObjectSetInteger(0, name, OBJPROP_ARROWCODE, (signal == SIGNAL_BUY) ? 233 : 234);
   ObjectSetInteger(0, name, OBJPROP_COLOR, (signal == SIGNAL_BUY) ? clrLime : clrTomato);
   ObjectSetInteger(0, name, OBJPROP_WIDTH, 2);
   ObjectSetInteger(0, name, OBJPROP_SELECTABLE, false);
}

//+------------------------------------------------------------------+
void UpdatePanelEx(const ENUM_SIGNAL signal, const string trendText,
                   const ENUM_HTF_BIAS htfBias, const bool inNews, const string newsTitle,
                   const bool inSession, const bool marketOpen,
                   const double closedPnL, const double equityRisk,
                   const double weekRisk, const double monthRisk, const bool riskStop,
                   const double atr, const double sl, const double tp,
                   const double swingH, const double swingL)
{
   string modeName = (InpTradeMode == MODE_TREND) ? "TREND" : "SCALP";
   string lines[];
   ArrayResize(lines, 18);
   lines[0]  = "AiTradingView EA v1.63";
   lines[1]  = "Mode: " + modeName + " | " + EnumToString(_Period);
   lines[2]  = "Trend: " + trendText;
   lines[3]  = "HTF: " + HtfToText(htfBias) + " (" + MtfName() + ")";
   lines[4]  = "Signal: " + SignalToText(signal);
   lines[5]  = "AutoTrade: " + (InpAutoTrade ? "ON" : "OFF");
   lines[6]  = "Manual SL/TP: " + (InpManageManualOrders ? "ON" : "OFF");
   lines[7]  = "Session: " + (inSession ? "ON" : "OFF") + " | Market: " + (marketOpen ? "OPEN" : "CLOSED");
   lines[8]  = inNews ? ("News: " + (StringLen(newsTitle) > 0 ? newsTitle : "ACTIVE")) : "News: CLEAR";
   lines[9]  = "DayPnL: " + DoubleToString(closedPnL, 2) +
               " / eqDD " + DoubleToString(equityRisk, 2);
   lines[10] = "Wk/Mo DD: " + DoubleToString(weekRisk, 2) + " / " + DoubleToString(monthRisk, 2) +
               (riskStop ? " | STOP" : "");
   lines[11] = "Cooldown: " + IntegerToString(g_cooldownBarsLeft) +
               (g_retryPending ? " | RETRY" : "") +
               " | AccPos " + IntegerToString(CountAccountEaPositions()) + "/" +
               IntegerToString(MathMax(1, InpMaxAccountEaPositions));
   lines[12] = "ATR: " + DoubleToString(atr, _Digits);
   lines[13] = "Swing H: " + (g_hasSwingHigh ? DoubleToString(swingH, _Digits) : "-");
   lines[14] = "Swing L: " + (g_hasSwingLow ? DoubleToString(swingL, _Digits) : "-");
   lines[15] = (sl > 0.0 && tp > 0.0)
               ? ("SL: " + DoubleToString(sl, _Digits) + "  TP: " + DoubleToString(tp, _Digits))
               : "SL/TP: - / -";
   lines[16] = "วินัย: " + g_disciplineStatus +
               " | net " + DoubleToString(g_disciplineDayNet, 2) + " USD";
   lines[17] = "BE: " + (InpUseBreakeven ? "ON" : "OFF") +
               " | TimeClose: " + (InpUseTimeProfitClose
                                   ? (IntegerToString(MathMax(1, InpTimeProfitMinutes)) + "m")
                                   : "OFF") +
               " | Journal: " + (InpJournalCsv ? "ON" : "OFF");

   int y = 14;
   for(int i = 0; i < ArraySize(lines); i++)
   {
      string name = g_panelPrefix + "L" + IntegerToString(i);
      EnsurePanelLabel(name, y + i * 13);
      color c = clrWhite;
      if(i == 4)
      {
         if(signal == SIGNAL_BUY) c = clrLime;
         else if(signal == SIGNAL_SELL) c = clrTomato;
         else c = clrSilver;
      }
      if(i == 7 && (!inSession || !marketOpen)) c = clrOrange;
      if(i == 8 && inNews) c = clrOrange;
      if(i == 10 && riskStop) c = clrTomato;
      if(i == 16)
      {
         if(g_disciplineStatus == "+HIT") c = clrLime;
         else if(g_disciplineStatus == "-HIT") c = clrTomato;
         else if(g_disciplineStatus == "OK") c = clrSilver;
      }
      ObjectSetInteger(0, name, OBJPROP_COLOR, c);
      ObjectSetString(0, name, OBJPROP_TEXT, lines[i]);
   }
   RefreshAlgoBlockPanel();
   ChartRedraw(0);
}

//+------------------------------------------------------------------+
void DeletePanel()
{
   ObjectsDeleteAll(0, g_panelPrefix);
}

//+------------------------------------------------------------------+
