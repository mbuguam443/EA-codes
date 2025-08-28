//+------------------------------------------------------------------+
//|                                             movingaveragebot.mq5 |
//|                                  Copyright 2025, MetaQuotes Ltd. |
//|                                             https://www.mql5.com |
//+------------------------------------------------------------------+
#property copyright "Copyright 2025, MetaQuotes Ltd."
#property link      "https://www.mql5.com"
#property version   "1.00"
#include <Trade/Trade.mqh>
#resource "\\Files\\nikoon.wav"

//+------------------------------------------------------------------+
//| Expert initialization function                                   |
//+------------------------------------------------------------------+
input int stoploss=200;
input int takeprofit=600;
int handlemovingaverage;
double buybuffer[],sellbuffer[];
CTrade trade;
int totalbars;
int OnInit()
  {

   string indicatorName=ChartIndicatorName(0,0,0);
   Print("indicatorname: ",indicatorName);
   handlemovingaverage=ChartIndicatorGet(0,0,indicatorName);
   if(handlemovingaverage==INVALID_HANDLE)
     {
      Print("failed to get the indicator");
     }else{
     Print("indicator loaded successfully");
     }
    ArraySetAsSeries(buybuffer,true);
    ArraySetAsSeries(sellbuffer,true);
    
   totalbars=iBars(_Symbol,PERIOD_CURRENT);
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
     int bars=iBars(_Symbol,PERIOD_CURRENT);
   if(totalbars!=bars)
     {
      totalbars=bars;
      CopyBuffer(handlemovingaverage,0,1,1,buybuffer);
      CopyBuffer(handlemovingaverage,1,1,1,sellbuffer);
      
      if(buybuffer[0]!= EMPTY_VALUE)
        {
         Print("buybuffer: ",buybuffer[0]," sellbuffer: ",sellbuffer[0]);
          double entry=SymbolInfoDouble(_Symbol,SYMBOL_ASK);
          double sl=stoploss==0?0:entry-stoploss*_Point;
          double tp=takeprofit==0?0:entry+takeprofit*_Point;
          sl=NormalizeDouble(sl,_Digits);
          tp=NormalizeDouble(tp,_Digits);
          trade.Buy(0.01,_Symbol,entry,sl,tp,"movingaverage buy");
          PlaySound("::Files\\nikoon.wav");
        }
        if(sellbuffer[0]!= EMPTY_VALUE)
        {
         Print("buybuffer: ",buybuffer[0]," sellbuffer: ",sellbuffer[0]);
          double entry=SymbolInfoDouble(_Symbol,SYMBOL_BID);
          double sl=stoploss==0?0:entry+stoploss*_Point;
          double tp=takeprofit==0?0:entry-takeprofit*_Point;
          sl=NormalizeDouble(sl,_Digits);
          tp=NormalizeDouble(tp,_Digits);
          trade.Sell(0.01,_Symbol,entry,sl,tp,"movingaverage sell");
          PlaySound("::Files\\nikoon.wav");
        }
    }
  }
//+------------------------------------------------------------------+
