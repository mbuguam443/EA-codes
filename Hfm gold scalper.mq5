//+------------------------------------------------------------------+
//|                                           SimpleProfitClose.mq5  |
//|               Opens many trades, closes only when in profit      |
//+------------------------------------------------------------------+
#property strict

#include <Trade\Trade.mqh>
CTrade trade;

input double LotSize = 0.01;
input int MinTrades = 6;
input int MaxTrades = 15;

int OnInit()
{
   return(INIT_SUCCEEDED);
}

void OnTick()
{
   // Determine candle direction from previous candle
   double openPrice = iOpen(_Symbol, PERIOD_M1, 1);
   double closePrice = iClose(_Symbol, PERIOD_M1, 1);

   bool isBearish = closePrice < openPrice;
   bool isBullish = closePrice > openPrice;

   // Determine max trades based on equity
   int maxTrades = getMaxTradesByEquity(AccountInfoDouble(ACCOUNT_EQUITY));

   // Count current trades for this symbol
   int currentTrades = 0;
   for(int i=0; i<PositionsTotal(); i++)
   {
      ulong ticket = PositionGetTicket(i);
      if(PositionSelectByTicket(ticket))
      {
         if(PositionGetString(POSITION_SYMBOL) == _Symbol)
            currentTrades++;
      }
   }

   // Open trades continuously (not once per candle)
   if(currentTrades < maxTrades)
   {
      if(isBearish)
         trade.Buy(LotSize, _Symbol);
      else if(isBullish)
         trade.Sell(LotSize, _Symbol);
   }

   // Close profitable trades only
   closeProfitableTrades();
}

// Determine max trades based on equity
int getMaxTradesByEquity(double equity)
{
   if(equity < 500) return MinTrades;
   if(equity < 2000) return 8;
   if(equity < 5000) return 10;
   if(equity < 10000) return 12;
   return MaxTrades;
}

// Close trades that are in profit
void closeProfitableTrades()
{
   for(int i=PositionsTotal()-1; i>=0; i--)
   {
      ulong ticket = PositionGetTicket(i);
      if(!PositionSelectByTicket(ticket)) continue;

      if(PositionGetString(POSITION_SYMBOL) != _Symbol) continue;

      double profit = PositionGetDouble(POSITION_PROFIT);

      if(profit > 0)
      {
         trade.PositionClose(ticket);
      }
   }
}

