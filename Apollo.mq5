//+------------------------------------------------------------------+
//|                                                       Apollo.mq5 |
//|                                  Copyright 2025, MetaQuotes Ltd. |
//|                                             https://www.mql5.com |
//+------------------------------------------------------------------+
#property copyright "Copyright 2025, MetaQuotes Ltd."
#property link      "https://www.mql5.com"
#property version   "1.00"

#include <Trade/Trade.mqh>
CTrade trade;

//+------------------------------------------------------------------+
//| Expert initialization function                                   |
//+------------------------------------------------------------------+
int OnInit()
  {
//---
   
//---
   return(INIT_SUCCEEDED);
  }
//+------------------------------------------------------------------+
//| Expert deinitialization function                                 |
//+------------------------------------------------------------------+
void OnDeinit(const int reason)
  {
//---
   
  }
//+------------------------------------------------------------------+
//| Expert tick function                                             |
//+------------------------------------------------------------------+
void OnTick()
  {
//---
   double close =iClose(_Symbol,PERIOD_CURRENT,0);
   double open  =iOpen(_Symbol,PERIOD_CURRENT,0);
   
   if(close > open)
     {
       for(int i=PositionsTotal()-1;i>=0;i--)
          {
            ulong ticket=PositionGetTicket(i);
            //trade.PositionClose(ticket);
          }
       if(PositionsTotal()<2)
         {
          double entry=SymbolInfoDouble(_Symbol,SYMBOL_BID);
          double tp=entry+600*_Point;
          double sl=entry-200*_Point;
          trade.Buy(0.01,_Symbol,entry,sl,0,"Buy HFT");
          
         }
       
     }
   
    if(open > close)
     {
        for(int i=PositionsTotal()-1;i>=0;i--)
          {
            ulong ticket=PositionGetTicket(i);
            //trade.PositionClose(ticket);
          }
       if(PositionsTotal()<2)
         {
          double entry=SymbolInfoDouble(_Symbol,SYMBOL_BID);
          double tp=entry-600*_Point;
          double sl=entry+200*_Point;
          trade.Sell(0.01,_Symbol,entry,sl,0,"Sell HFT");
         }
       
     }
   
  }
//+------------------------------------------------------------------+
