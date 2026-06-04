//+------------------------------------------------------------------+
//|                                              HFTTickScalper.mq5 |
//|                                                   HFT Tick Scalper |
//+------------------------------------------------------------------+
#property copyright "HFT Tick Scalper"
#property link      ""
#property version   "1.00"
#include <Trade/Trade.mqh>
#include <Trade/PositionInfo.mqh>
//+------------------------------------------------------------------+
//| Inputs                                                           |
//+------------------------------------------------------------------+
input group "====Tick MA===="
input int      InpFastTicks  = 5;          // Fast MA tick count
input int      InpSlowTicks  = 20;         // Slow MA tick count
input bool     InpUseAskBid  = false;      // Use Ask price (false=Bid)

input group "====Trading===="
input double   InpLotSize    = 0.01;       // Lot size
input int      InpStopLoss   = 10;         // Stop Loss (points)
input int      InpTakeProfit = 10;         // Take Profit (points)
input bool     InpCloseBySignal = true;    // Close on opposite signal

input group "====Filters===="
input int      InpSpreadLimit   = 30;      // Max spread (points, 0=off)
input int      InpMinGap        = 3;       // Min MA gap (points) to confirm crossover

input group "====Settings===="
static input long InpMagicNumber = 5776;   // Magic number

//+------------------------------------------------------------------+
//| Global variables                                                 |
//+------------------------------------------------------------------+
double tickBuffer[];
int    tickCount;
double fastMA;
double slowMA;
double prevFastMA;
double prevSlowMA;
MqlTick lastTick;
CTrade  trade;
CPositionInfo position;

//+------------------------------------------------------------------+
//| Expert initialization function                                   |
//+------------------------------------------------------------------+
int OnInit()
{
   trade.SetExpertMagicNumber(InpMagicNumber);
   ArrayResize(tickBuffer, 1000);
   tickCount = 0;
   prevFastMA = 0;
   prevSlowMA = 0;
   return INIT_SUCCEEDED;
}
//+------------------------------------------------------------------+
//| Expert deinitialization function                                 |
//+------------------------------------------------------------------+
void OnDeinit(const int reason)
{
}
//+------------------------------------------------------------------+
//| Expert tick function                                             |
//+------------------------------------------------------------------+
void OnTick()
{
   MqlTick currentTick;
   if(!SymbolInfoTick(_Symbol, currentTick))
      return;

   if(currentTick.bid == lastTick.bid && currentTick.ask == lastTick.ask)
      return;
   lastTick = currentTick;

   if(InpSpreadLimit > 0)
   {
      double spread = (currentTick.ask - currentTick.bid) / _Point;
      if(spread > InpSpreadLimit)
         return;
   }

   double tickPrice = InpUseAskBid ? currentTick.ask : currentTick.bid;

   if(tickCount >= ArraySize(tickBuffer))
      ArrayResize(tickBuffer, ArraySize(tickBuffer) + 1000);
   tickBuffer[tickCount++] = tickPrice;

   if(tickCount < InpSlowTicks)
      return;

   prevFastMA = fastMA;
   prevSlowMA = slowMA;
   fastMA = CalcSMA(tickCount - InpFastTicks, InpFastTicks);
   slowMA = CalcSMA(tickCount - InpSlowTicks, InpSlowTicks);

   if(prevFastMA == 0 || prevSlowMA == 0)
      return;

   int cntBuy = 0, cntSell = 0;
   CountPositions(cntBuy, cntSell);

   double gap = InpMinGap * _Point;

   if(prevFastMA <= prevSlowMA && fastMA > slowMA + gap)
   {
      if(InpCloseBySignal)
         ClosePositions(2);
      if(cntBuy == 0 && HasFreeMargin())
         OpenOrder(ORDER_TYPE_BUY, currentTick.ask, currentTick.ask, currentTick.bid);
   }
   else if(prevFastMA >= prevSlowMA && fastMA < slowMA - gap)
   {
      if(InpCloseBySignal)
         ClosePositions(1);
      if(cntSell == 0 && HasFreeMargin())
         OpenOrder(ORDER_TYPE_SELL, currentTick.bid, currentTick.ask, currentTick.bid);
   }
}
//+------------------------------------------------------------------+
//| Open market order (no stops — broker rejects them for XAUUSD.m) |
//+------------------------------------------------------------------+
void OpenOrder(ENUM_ORDER_TYPE type, double price, double ask, double bid)
{
   trade.SetExpertMagicNumber(InpMagicNumber);
   if(type == ORDER_TYPE_BUY)
      trade.Buy(InpLotSize, _Symbol, price, 0, 0, "HFT Buy");
   else
      trade.Sell(InpLotSize, _Symbol, price, 0, 0, "HFT Sell");
}
//+------------------------------------------------------------------+
//| Calculate SMA of 'count' ticks starting at 'start'              |
//+------------------------------------------------------------------+
double CalcSMA(int start, int count)
{
   double sum = 0;
   for(int i = 0; i < count; i++)
      sum += tickBuffer[start + i];
   return sum / count;
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
//| Check free margin                                                |
//+------------------------------------------------------------------+
bool HasFreeMargin()
{
   if(!AccountInfoDouble(ACCOUNT_MARGIN_FREE))
      return true;
   double margin = 0;
   if(!OrderCalcMargin(ORDER_TYPE_BUY, _Symbol, InpLotSize, lastTick.ask, margin))
      return false;
   return AccountInfoDouble(ACCOUNT_MARGIN_FREE) >= margin;
}
//+------------------------------------------------------------------+
