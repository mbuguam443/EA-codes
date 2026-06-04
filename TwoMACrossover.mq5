//+------------------------------------------------------------------+
//|                                              TwoMACrossover.mq5 |
//|                                                       Two MA Crossover EA |
//|                                                                  |
//+------------------------------------------------------------------+
#property copyright "Two MA Crossover EA"
#property link      ""
#property version   "1.00"
#include <Trade/Trade.mqh>
#include <Trade/PositionInfo.mqh>
//+------------------------------------------------------------------+
//| Inputs                                                           |
//+------------------------------------------------------------------+
input group "====Moving Averages===="
input int            InpFastMA         = 10;          // Fast MA period
input int            InpSlowMA         = 30;          // Slow MA period
input ENUM_MA_METHOD InpMAMethod       = MODE_EMA;    // MA method
input ENUM_APPLIED_PRICE InpAppliedPrice = PRICE_CLOSE; // Applied price

input group "====Trading===="
input double         InpLotSize        = 0.01;        // Lot size
input int            InpStopLoss       = 0;           // Stop Loss (points, 0=off)
input int            InpTakeProfit     = 0;           // Take Profit (points, 0=off)
input bool           InpCloseBySignal  = true;        // Close on opposite signal

input group "====Settings===="
static input long   InpMagicNumber    = 5775;        // Magic number

//+------------------------------------------------------------------+
//| Global variables                                                 |
//+------------------------------------------------------------------+
int          handleFastMA;
int          handleSlowMA;
double       bufferFastMA[];
double       bufferSlowMA[];
datetime     lastBarTime;
CTrade       trade;
CPositionInfo position;

//+------------------------------------------------------------------+
//| Expert initialization function                                   |
//+------------------------------------------------------------------+
int OnInit()
{
   if(InpFastMA >= InpSlowMA)
   {
      Alert("Fast MA period must be less than Slow MA period");
      return INIT_PARAMETERS_INCORRECT;
   }

   trade.SetExpertMagicNumber(InpMagicNumber);

   handleFastMA = iMA(_Symbol, PERIOD_CURRENT, InpFastMA, 0, InpMAMethod, InpAppliedPrice);
   handleSlowMA = iMA(_Symbol, PERIOD_CURRENT, InpSlowMA, 0, InpMAMethod, InpAppliedPrice);

   if(handleFastMA == INVALID_HANDLE || handleSlowMA == INVALID_HANDLE)
   {
      Alert("Failed to create MA indicators");
      return INIT_FAILED;
   }

   ArraySetAsSeries(bufferFastMA, true);
   ArraySetAsSeries(bufferSlowMA, true);

   ChartIndicatorAdd(NULL, 0, handleFastMA);
   ChartIndicatorAdd(NULL, 0, handleSlowMA);

   lastBarTime = iTime(_Symbol, PERIOD_CURRENT, 0);
   return INIT_SUCCEEDED;
}
//+------------------------------------------------------------------+
//| Expert deinitialization function                                 |
//+------------------------------------------------------------------+
void OnDeinit(const int reason)
{
   if(handleFastMA != INVALID_HANDLE) IndicatorRelease(handleFastMA);
   if(handleSlowMA != INVALID_HANDLE) IndicatorRelease(handleSlowMA);
}
//+------------------------------------------------------------------+
//| Expert tick function                                             |
//+------------------------------------------------------------------+
void OnTick()
{
   datetime currentBarTime = iTime(_Symbol, PERIOD_CURRENT, 0);
   if(currentBarTime == lastBarTime)
      return;
   lastBarTime = currentBarTime;

   if(CopyBuffer(handleFastMA, 0, 0, 2, bufferFastMA) < 2)
      return;
   if(CopyBuffer(handleSlowMA, 0, 0, 2, bufferSlowMA) < 2)
      return;

   double fastPrev = bufferFastMA[1];
   double fastCurr = bufferFastMA[0];
   double slowPrev = bufferSlowMA[1];
   double slowCurr = bufferSlowMA[0];

   MqlTick tick;
   if(!SymbolInfoTick(_Symbol, tick))
      return;

   int cntBuy = 0, cntSell = 0;
   CountPositions(cntBuy, cntSell);

   // Buy signal: fast MA crosses above slow MA
   if(fastPrev <= slowPrev && fastCurr > slowCurr)
   {
      if(InpCloseBySignal)
         ClosePositions(2);
      if(cntBuy == 0)
      {
         double sl = InpStopLoss == 0 ? 0 : tick.ask - InpStopLoss * _Point;
         double tp = InpTakeProfit == 0 ? 0 : tick.ask + InpTakeProfit * _Point;
         trade.Buy(InpLotSize, _Symbol, tick.ask, sl, tp, "MA Crossover Buy");
      }
   }
   // Sell signal: fast MA crosses below slow MA
   else if(fastPrev >= slowPrev && fastCurr < slowCurr)
   {
      if(InpCloseBySignal)
         ClosePositions(1);
      if(cntSell == 0)
      {
         double sl = InpStopLoss == 0 ? 0 : tick.bid + InpStopLoss * _Point;
         double tp = InpTakeProfit == 0 ? 0 : tick.bid - InpTakeProfit * _Point;
         trade.Sell(InpLotSize, _Symbol, tick.bid, sl, tp, "MA Crossover Sell");
      }
   }
}
//+------------------------------------------------------------------+
//| Count positions with magic number                                |
//+------------------------------------------------------------------+
void CountPositions(int &cntBuy, int &cntSell)
{
   cntBuy = 0;
   cntSell = 0;
   for(int i = PositionsTotal() - 1; i >= 0; i--)
   {
      ulong ticket = PositionGetTicket(i);
      if(ticket <= 0) continue;
      if(!PositionSelectByTicket(ticket)) continue;
      if(PositionGetInteger(POSITION_MAGIC) != InpMagicNumber) continue;
       if(PositionGetString(POSITION_SYMBOL) != _Symbol) continue;
      if((ENUM_POSITION_TYPE)PositionGetInteger(POSITION_TYPE) == POSITION_TYPE_BUY)
         cntBuy++;
      else
         cntSell++;
   }
}
//+------------------------------------------------------------------+
//| Close positions                                                  |
//| all_buy_sell=1 -> close buys only                                |
//| all_buy_sell=2 -> close sells only                               |
//+------------------------------------------------------------------+
void ClosePositions(int all_buy_sell)
{
   for(int i = PositionsTotal() - 1; i >= 0; i--)
   {
      ulong ticket = PositionGetTicket(i);
      if(ticket <= 0) continue;
      if(!PositionSelectByTicket(ticket)) continue;
      if(PositionGetInteger(POSITION_MAGIC) != InpMagicNumber) continue;
       if(PositionGetString(POSITION_SYMBOL) != _Symbol) continue;
      ENUM_POSITION_TYPE type = (ENUM_POSITION_TYPE)PositionGetInteger(POSITION_TYPE);
      if(all_buy_sell == 1 && type == POSITION_TYPE_SELL) continue;
      if(all_buy_sell == 2 && type == POSITION_TYPE_BUY) continue;
      trade.PositionClose(ticket);
   }
}
//+------------------------------------------------------------------+
