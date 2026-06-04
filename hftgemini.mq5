//+------------------------------------------------------------------+
//|                  Gold HFT Style Scalper                          |
//|                     Educational Version                          |
//+------------------------------------------------------------------+
#property strict

#include <Trade/Trade.mqh>
CTrade trade;

input double LotSize = 0.01;
input int StopLoss = 150;       // points
input int TakeProfit = 250;     // points
input int MaxSpread = 50;
input int FastEMA = 5;
input int SlowEMA = 20;
input int RSI_Period = 7;
input double BuyRSI = 55;
input double SellRSI = 45;
input int MaxPositions = 1;

int fastHandle;
int slowHandle;
int rsiHandle;

//+------------------------------------------------------------------+
int OnInit()
{
   fastHandle = iMA(_Symbol, PERIOD_M1, FastEMA, 0, MODE_EMA, PRICE_CLOSE);
   slowHandle = iMA(_Symbol, PERIOD_M1, SlowEMA, 0, MODE_EMA, PRICE_CLOSE);
   rsiHandle = iRSI(_Symbol, PERIOD_M1, RSI_Period, PRICE_CLOSE);

   return(INIT_SUCCEEDED);
}

//+------------------------------------------------------------------+
void OnTick()
{
   if(_Symbol != "XAUUSD")
      return;

   if(PositionsTotal() >= MaxPositions)
      return;

   double spread = (SymbolInfoDouble(_Symbol, SYMBOL_ASK) -
                    SymbolInfoDouble(_Symbol, SYMBOL_BID)) / _Point;

   if(spread > MaxSpread)
      return;

   double fastEMA[];
   double slowEMA[];
   double rsi[];

   CopyBuffer(fastHandle, 0, 0, 3, fastEMA);
   CopyBuffer(slowHandle, 0, 0, 3, slowEMA);
   CopyBuffer(rsiHandle, 0, 0, 3, rsi);

   double ask = SymbolInfoDouble(_Symbol, SYMBOL_ASK);
   double bid = SymbolInfoDouble(_Symbol, SYMBOL_BID);

   // BUY CONDITION
   if(fastEMA[0] > slowEMA[0] && rsi[0] > BuyRSI)
   {
      double sl = ask - StopLoss * _Point;
      double tp = ask + TakeProfit * _Point;

      trade.Buy(LotSize, _Symbol, ask, sl, tp, "Gold Scalper Buy");
   }

   // SELL CONDITION
   if(fastEMA[0] < slowEMA[0] && rsi[0] < SellRSI)
   {
      double sl = bid + StopLoss * _Point;
      double tp = bid - TakeProfit * _Point;

      trade.Sell(LotSize, _Symbol, bid, sl, tp, "Gold Scalper Sell");
   }
}
//+------------------------------------------------------------------+