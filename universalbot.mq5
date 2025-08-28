//+------------------------------------------------------------------+
//|                                                 universalbot.mq5 |
//|                                  Copyright 2025, MetaQuotes Ltd. |
//|                                             https://www.mql5.com |
//+------------------------------------------------------------------+
#property copyright "Copyright 2025, MetaQuotes Ltd."
#property link      "https://www.mql5.com"
#property version   "1.00"
#include<Trade/Trade.mqh>
#resource "\\Files\\nikoon.wav"
//+------------------------------------------------------------------+
//| Expert initialization function                                   |
//+------------------------------------------------------------------+
input int stoploss=200;
input int TakeProfit=600;
input double lotsize=0.01;
int handleuniversal;
int totalbars;
double signalup[],signaldown[];
CTrade trade;
int OnInit()
  {
   string indicatorname=ChartIndicatorName(0,0,0);
   
   Print("indicator name: ",indicatorname);
   handleuniversal=ChartIndicatorGet(0,0,indicatorname);
   if(handleuniversal==INVALID_HANDLE)
     {
      Print("it has failed to get the indicator");
     }else{
     Print("indicator loaded successfully");
      }
   totalbars=iBars(_Symbol,PERIOD_CURRENT);
   ArraySetAsSeries(signaldown,true);
   ArraySetAsSeries(signalup,true);
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
       Print("print every bar");
       CopyBuffer(handleuniversal,4,1,1,signalup);
       CopyBuffer(handleuniversal,5,1,1,signaldown);
       Print("signalup: ",signalup[0]," signaldown: ",signaldown[0]);
       if(signalup[0]>0)
         {
          Print("buy now");
          Alert("bot is live");
          double entry=SymbolInfoDouble(_Symbol,SYMBOL_ASK);
          double sl=stoploss==0?0:entry-stoploss*_Point;
          double tp=TakeProfit==0?0:entry+TakeProfit*_Point;
          tp=NormalizeDouble(tp,_Digits);
          sl=NormalizeDouble(sl,_Digits);
          trade.Buy(lotsize,_Symbol,entry,sl,tp,"universal buy");
          PlaySound("::Files\\nikoon.wav");
          
         }
       if(signaldown[0]>0)
         {
           Print("sell now");
           Alert("bot is live");
           double entry=SymbolInfoDouble(_Symbol,SYMBOL_BID);
          double tp=TakeProfit==0?0:entry-TakeProfit*_Point;
          tp=NormalizeDouble(tp,_Digits);
          double sl=stoploss==0?0:entry+stoploss*_Point;
          sl=NormalizeDouble(sl,_Digits);
          trade.Sell(lotsize,_Symbol,entry,sl,tp,"universal sell");
          PlaySound("::Files\\nikoon.wav");
         }  
     }
   
  }
//+------------------------------------------------------------------+
