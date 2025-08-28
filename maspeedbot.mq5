//+------------------------------------------------------------------+
//|                                                   maspeedbot.mq5 |
//|                                  Copyright 2025, MetaQuotes Ltd. |
//|                                             https://www.mql5.com |
//+------------------------------------------------------------------+
#property copyright "Copyright 2025, MetaQuotes Ltd."
#property link      "https://www.mql5.com"
#property version   "1.00"
#include <Trade/Trade.mqh>
//+------------------------------------------------------------------+
//| Expert initialization function                                   |
//+------------------------------------------------------------------+
input int stoploss=200;
input int takeprofit=600;
int handlemaspeed;
int totalbars;
double signalup[],signaldown[],buffer1[];
CTrade trade;
int OnInit()
  {
   string indicatorName=ChartIndicatorName(0,0,0);
   Print("INDICATOR NAME: ",indicatorName);
   handlemaspeed=ChartIndicatorGet(0,0,indicatorName);
   if(handlemaspeed==INVALID_HANDLE)
     {
      Print("failed to load the indicator");
     }else
        {
         Print("SUCCESS to load the indicator");
        }
    totalbars=iBars(_Symbol,PERIOD_CURRENT);
    ArraySetAsSeries(signalup,true);
    ArraySetAsSeries(signaldown,true);
    ArraySetAsSeries(buffer1,true);
   return(INIT_SUCCEEDED);
   
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
   int bars=iBars(_Symbol,PERIOD_CURRENT);
   if(totalbars!=bars)
     {
      totalbars=bars;
      CopyBuffer(handlemaspeed,0,1,3,buffer1);
   
      CopyBuffer(handlemaspeed,4,1,1,signalup);
      CopyBuffer(handlemaspeed,5,1,1,signaldown);
      
      Print("signalup: ",signalup[0]," signaldown: ",signaldown[0]);
      Print("buffer1: ",buffer1[0]);
      if(buffer1[2]>buffer1[1] && buffer1[1]<buffer1[0])
        {
         Print(" buy now");
          double entry=SymbolInfoDouble(_Symbol,SYMBOL_ASK);
          double sl=stoploss==0?0:entry-stoploss*_Point;
          double tp=takeprofit==0?0:entry+takeprofit*_Point;
          sl=NormalizeDouble(sl,_Digits);
          tp=NormalizeDouble(tp,_Digits);
          trade.Buy(0.01,_Symbol,entry,sl,tp,"normal maspeed buy");
        }
      if(buffer1[2]<buffer1[1] && buffer1[1]>buffer1[0])
        {
         Print(" sell now");
         double entry=SymbolInfoDouble(_Symbol,SYMBOL_BID);
          double sl=stoploss==0?0:entry+stoploss*_Point;
          double tp=takeprofit==0?0:entry-takeprofit*_Point;
          sl=NormalizeDouble(sl,_Digits);
          tp=NormalizeDouble(tp,_Digits);
          trade.Sell(0.01,_Symbol,entry,sl,tp,"normal maspeed sell");
        }  
      if(signalup[0]>0)
        {
         Print("SPEED buy now");
          double entry=SymbolInfoDouble(_Symbol,SYMBOL_ASK);
          double sl=stoploss==0?0:entry-stoploss*_Point;
          double tp=takeprofit==0?0:entry+takeprofit*_Point;
          sl=NormalizeDouble(sl,_Digits);
          tp=NormalizeDouble(tp,_Digits);
          //trade.Buy(0.01,_Symbol,entry,sl,tp,"maspeed buy");
        }
       if(signaldown[0]>0)
         {
          Print("speed sell now");
          double entry=SymbolInfoDouble(_Symbol,SYMBOL_BID);
          double sl=stoploss==0?0:entry+stoploss*_Point;
          double tp=takeprofit==0?0:entry-takeprofit*_Point;
          sl=NormalizeDouble(sl,_Digits);
          tp=NormalizeDouble(tp,_Digits);
          //trade.Sell(0.01,_Symbol,entry,sl,tp,"maspeed sell");
         } 
     }
     
     
   
  }
//+------------------------------------------------------------------+
